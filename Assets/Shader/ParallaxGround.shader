Shader "Scene/ParallaxGround"
{
    Properties
    {
        [Header(Texture)]
        _MainTex ("主贴图", 2D) = "gray" {}
        [NoScaleOffset]_NormalMap ("法线图", 2D) = "bump" {}
        _FlashTex ("闪烁遮罩", 2D) = "black" {}
        [NoScaleOffset]_RutRTTex ("轨迹渲染纹理", 2D) = "bump" {}
        _PaintRect("轨迹范围", vector) = (0.0, 0.0, 1.0, 1.0)

        [Space(20)]
        [Header(Color)]
        [HDR]_BrightCol ("亮部色", color) = (1.0, 1.0, 1.0, 1.0)
        _DarkCol ("暗部色", color) = (0.1, 0.1, 0.1, 1.0)
        [HDR]_SpecularCol ("高光色", color) = (1.0, 1.0, 1.0, 1.0)
        _AmbCol ("环境色", color) = (1.0, 1.0, 1.0, 1.0)

        [Space(20)]
        [Header(Material)]
        _NormalInt ("法线强度", range(0, 10)) = 1.0
        _Rough ("粗糙度", range(0.001, 1)) = 0.5
        _FresnelPow ("菲涅尔次幂", range(1, 10)) = 5.0
        _F0 ("基础反射率", Range(0, 1)) = 0.05

        [Space(20)]
        [Header(Flash)]
        _FlashInt ("闪烁强度", float) = 10
        _FlashOffset ("闪烁偏移", float) = -0.1
        _FlashRange_Min ("闪烁最小衰减半径", float) = 5.0
        _FlashRange_Max ("闪烁最大衰减半径", float) = 10.0

        [Space(20)]
        [Header(Parallax)]
        _HeightOffset ("高度偏移", range(-0.1, 0.1)) = 0.0
        _HeightScale ("高度缩放", range(-0.1, 0.1)) = 0.05
        _MarchStep ("扫描层数", range(1, 255)) = 20

        [Space(20)]
        [Header(Rut)]
        _RutNormalInt ("轨迹法线强度", float) = 1.0
    }
    SubShader
    {
        Tags 
        {
            "RenderPipeline" = "UniversalPipeline" 
            "RenderType" = "Opaque"
            "Queue" = "Geometry"
        }

        Pass 
        {
            Cull back
            ZWrite on

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            
			CBUFFER_START(UnityPerMaterial)
                //贴图
                sampler2D _MainTex; float4 _MainTex_ST;
                sampler2D _NormalMap;
                sampler2D _FlashTex; float4 _FlashTex_ST;
                sampler2D _RutRTTex;
                float4 _PaintRect;
                
                //颜色
                float3 _BrightCol;
                float3 _DarkCol;
                float3 _SpecularCol;
                float3 _AmbCol;
            
                //质感
                float _NormalInt;
                float _Rough;
                float _FresnelPow;
                float _F0;

                //闪烁
                float _FlashInt;
                float _FlashOffset;
                float _FlashRange_Min;
                float _FlashRange_Max;

                //视差参数
                float _HeightOffset;
                float _HeightScale;
                uint _MarchStep;

                //痕迹
                float _RutNormalInt;
            CBUFFER_END
            
            //重映射01
            float Remap(float min, float max, float input)
            {
                float k = 1.0 / (max - min);
                float b = -min * k;
                return saturate(k * input + b);
            }

            //计算切空间下，射线与高度场的首个交点
            float3 GetRayMarchingCrossPoint(float3 scale, float3 offset, uint marchStep, sampler2D heightMap, float3 rayPosTS, float3 rayDirTS)
            {
                float3 deltaDir = (rayDirTS / abs(rayDirTS.z)) * (abs(scale.z) / marchStep);//单次步进的变化向量。加绝对值保证输入方向不变
                float3 currentPos = rayPosTS;//当前步进的坐标
                float sampleH = currentPos.z - 1;//当前步进的采样高度

                for (uint idx = 0; idx < marchStep; idx++)
                {
                    if (sampleH < currentPos.z)//采样高度小于射线上的高度，说明射线还没有进入高度场内部)
                    {
                        currentPos += deltaDir;
                        sampleH = scale.z * (2.0*tex2Dlod(heightMap, float4(scale.xy * currentPos.xy + offset.xy, 0.0, 0.0)).w - 1.0) + offset.z;
                    }
                    else
                    {
                        break;
                    }
                }
                return currentPos;
            }

            //计算任意平面交点
            float3 GetPosAnyPlaneCrossDir(float3 posPlane, float3 posRay, float3 nDirPlane, float3 nDirRay)
            {
                float3 deltaPos = posPlane - posRay;
                float temp = dot(nDirPlane, deltaPos) / dot(nDirPlane, nDirRay);
                return temp * nDirRay + posRay;
            }

			//顶点shader
            struct a2v
            {
                float4 posOS	: POSITION;
                float3 nDirOS : NORMAL;
                float4 tDirOS : TANGENT;
                float2 uv0  : TEXCOORD0;
            };

            static float minError = 1.5 / 255;
            struct v2f
            {
                float4 posCS	       : SV_POSITION;
                float3 posWS            : TEXCOORD7;
                float3 nDirWS       : TEXCOORD0;
                float3 tDirWS       : TEXCOORD1;
                float3 bDirWS       : TEXCOORD2;
                float3 vDirWS       : TEXCOORD3;
                float2 uv_Main     : TEXCOORD4;
                float4 uv_Flash    : TEXCOORD5;
                float2 uv_Rut       : TEXCOORD6;
                float2 uv0          : TEXCOORD8;
            };

            v2f vert(a2v i)
            {
                v2f o;

                //坐标
                o.posCS = TransformObjectToHClip(i.posOS.xyz);
                o.posWS = TransformObjectToWorld(i.posOS.xyz);

                //向量
                o.nDirWS = TransformObjectToWorldNormal(i.nDirOS);
                o.tDirWS = TransformObjectToWorldDir(i.tDirOS.xyz);
                o.bDirWS = cross(o.nDirWS, o.tDirWS) * i.tDirOS.w;
                o.vDirWS = GetCameraPositionWS() - o.posWS;

                //UV
                o.uv_Main = TRANSFORM_TEX(i.uv0, _MainTex);
                o.uv_Flash.xy = TRANSFORM_TEX(i.uv0, _FlashTex);
                o.uv_Rut = float2(Remap(_PaintRect.x, _PaintRect.z, o.posWS.x), Remap(_PaintRect.y, _PaintRect.w, o.posWS.z));
                o.uv0 = i.uv0;

                //闪烁内层UV偏移
                float3x3 TBN = float3x3(normalize(o.tDirWS), normalize(o.bDirWS), normalize(o.nDirWS));
                float3 vDirTS = TransformWorldToTangent(o.vDirWS, TBN);
                o.uv_Flash.zw = GetPosAnyPlaneCrossDir(float3(0, 0, _FlashOffset), float3(o.uv_Flash.xy, 0), float3(0,0,1), vDirTS).xy;

                return o;
            }

			//像素shader
            float4 frag(v2f i) : SV_Target
            {
                //视差UV偏移
                float3 vDirWS = normalize(i.vDirWS);
                float3 tDirWS_Rut = float3(1.0, -i.nDirWS.x / i.nDirWS.y, 0.0);
                float3 bDirWS_Rut = float3(0.0, -i.nDirWS.z / i.nDirWS.y, 1.0);
                float3x3 TBN_Rut = float3x3(normalize(tDirWS_Rut), normalize(bDirWS_Rut), normalize(i.nDirWS));
                float3 vDirTS_Rut = normalize(TransformWorldToTangent(vDirWS, TBN_Rut));
                float3 scaleParams = float3(1.0, 1.0, _HeightScale);
                float3 offsetParams = float3(0.0, 0.0, _HeightOffset);
                float3 crossPosTS = GetRayMarchingCrossPoint(scaleParams, offsetParams, _MarchStep, _RutRTTex, float3(i.uv_Rut, 0), -vDirTS_Rut);

                //轨迹图采样
                float4 var_RutTex = tex2D(_RutRTTex, crossPosTS.xy);
                var_RutTex.xyw = abs(var_RutTex.xyw - 0.5) < minError ? 0.5 : var_RutTex.xyw;//误差截断，防止在平坦区域应用法线贴图

                //地形法线
                float3 nDirTS = UnpackNormal(tex2D(_NormalMap, i.uv_Main));
                nDirTS.xy *= _NormalInt;

                //轨迹法线
                float3 nDirTS_Rut = (2.0 * var_RutTex.xyz - 1.0);
                nDirTS_Rut.xy *= _RutNormalInt;

                //法线混合
                nDirTS = float3(nDirTS.xy / nDirTS.z + nDirTS_Rut.xy / nDirTS_Rut.z, 1.0);

                //向量
                float3x3 TBN = float3x3(normalize(i.tDirWS), normalize(i.bDirWS), normalize(i.nDirWS));
                Light light = GetMainLight(TransformWorldToShadowCoord(i.posWS));
                float3 nDirWS = normalize(mul(nDirTS, TBN));
                float3 lDirWS = light.direction;
                float3 hDirWS = normalize(lDirWS + vDirWS);
                
                //光照
                float lambert = saturate(dot(nDirWS, lDirWS));
                float blinn = lambert * pow(saturate(dot(nDirWS, hDirWS)), 1.0 / (_Rough*_Rough));
                float3 baseCol = tex2D(_MainTex, i.uv_Main).rgb;
                float3 diffuseCol = baseCol * lerp(_DarkCol, _BrightCol, lambert);
                float3 specularCol = _SpecularCol * blinn;

                //环境光
                float nv = saturate(dot(nDirWS, vDirWS));
                float fresnel = _F0 + (1.0-_F0) * pow(1.0 - nv, _FresnelPow);
                float3 ambCol = fresnel * _AmbCol * baseCol;

                //闪烁
                float flashMask = Remap(_FlashRange_Max, _FlashRange_Min, length(i.vDirWS));
                float mask0 = tex2D(_FlashTex, i.uv_Flash.xy).r;
                float mask1 = tex2D(_FlashTex, i.uv_Flash.zw).r;
                float flashCol = _FlashInt * flashMask * mask0 * mask1;

                //混合
                float3 finalCol = (diffuseCol + specularCol + flashCol) * light.shadowAttenuation + ambCol;
                return float4(finalCol, 1.0);
            }            
            ENDHLSL
        }
    }
}