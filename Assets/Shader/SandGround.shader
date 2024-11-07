Shader "Scene/SandGround"
{
    Properties
    {
        [Header(Texture)]
        _MainTex("Main Texture", 2D) = "gray" {}
        [NoScaleOffset] _NormalMap("Normal Map", 2D) = "bump" {}
        _FlashTex("Flash Mask", 2D) = "black" {}
        [NoScaleOffset] _RutRTTex("Trail Render Texture", 2D) = "bump" {}
        _PaintRect("Trail Area", vector) = (0.0, 0.0, 1.0, 1.0)

        [Space(20)]
        [Header(Color)]
        [HDR] _BrightCol("Bright Color", color) = (1.0, 1.0, 1.0, 1.0)
        _DarkCol("Dark Color", color) = (0.1, 0.1, 0.1, 1.0)
        [HDR] _SpecularCol("Specular Color", color) = (1.0, 1.0, 1.0, 1.0)
        _AmbCol("Ambient Color", color) = (1.0, 1.0, 1.0, 1.0)

        [Space(20)]
        [Header(Material)]
        _NormalInt("Normal Intensity", range(0, 10)) = 1.0
        _Rough("Roughness", range(0.001, 1)) = 0.5
        _FresnelPow("Fresnel Power", range(1, 10)) = 5.0
        _F0("Base Reflectivity", Range(0, 1)) = 0.05

        [Space(20)]
        [Header(Flash)]
        _FlashInt("Flash Intensity", float) = 10
        _FlashOffset("Flash Offset", float) = -0.1
        _FlashRange_Min("Flash Min Attenuation Radius", float) = 5.0
        _FlashRange_Max("Flash Max Attenuation Radius", float) = 10.0

        [Space(20)]
        [Header(Tessellation)]
        _TessStep("Max Tessellation Segments", range(1, 64)) = 1
        _TessPow("Tessellation Curve", range(1, 10)) = 2.0

        [Space(20)]
        [Header(Trail)]
        _RutHeight("Trail Height", float) = 0.5
        _RutNormalInt("Trail Normal Intensity", float) = 1.0

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
            #pragma hull hs
            #pragma domain ds
            #pragma fragment frag

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            
			CBUFFER_START(UnityPerMaterial)
                sampler2D _MainTex; float4 _MainTex_ST;
                sampler2D _NormalMap;
                sampler2D _FlashTex; float4 _FlashTex_ST;
                sampler2D _RutRTTex;
                float4 _PaintRect;
            
                float3 _BrightCol;
                float3 _DarkCol;
                float3 _SpecularCol;
                float3 _AmbCol;
         
                float _NormalInt;
                float _Rough;
                float _FresnelPow;
                float _F0;

                float _FlashInt;
                float _FlashOffset;
                float _FlashRange_Min;
                float _FlashRange_Max;

                uint _TessStep;
                float _TessPow;

                float _RutHeight;
                float _RutNormalInt;
            CBUFFER_END
      
            float Remap(float min, float max, float input)
            {
                float k = 1.0 / (max - min);
                float b = -min * k;
                return saturate(k * input + b);
            }

     
            bool IsTriRectCross2D(float2 triVert[3], float4 rect)
            {
                for (uint idx = 0; idx < 3; idx++)
                {
                    if (triVert[idx].x >= rect.x && triVert[idx].x <= rect.z && triVert[idx].y >= rect.y && triVert[idx].y <= rect.w)
                    {
                        return true;
                    }
                }
                return false;
            }

            float3 GetPosAnyPlaneCrossDir(float3 posPlane, float3 posRay, float3 nDirPlane, float3 nDirRay)
            {
                float3 deltaPos = posPlane - posRay;
                float temp = dot(nDirPlane, deltaPos) / dot(nDirPlane, nDirRay);
                return temp * nDirRay + posRay;
            }

            struct a2v
            {
                float4 posOS	: POSITION;
                float3 nDirOS : NORMAL;
                float4 tDirOS : TANGENT;
                float2 uv0  : TEXCOORD0;
            };
            struct v2t
            {
                float3 posWS	: TEXCOORD0;
                float3 nDirWS : TEXCOORD1;
                float3 tDirWS : TEXCOORD2;
                float3 bDirWS    : TEXCOORD3;
                float2 uv0  : TEXCOORD4;
                float2 uv_Rut : TEXCOORD5;
            };
            v2t vert(a2v i)
            {
                v2t o;
                o.posWS = TransformObjectToWorld(i.posOS.xyz);
                o.nDirWS = TransformObjectToWorldNormal(i.nDirOS);
                o.tDirWS = TransformObjectToWorldDir(i.tDirOS.xyz);
                o.bDirWS = cross(o.nDirWS, o.tDirWS) * i.tDirOS.w;
                o.uv0 = i.uv0;
                o.uv_Rut = float2(Remap(_PaintRect.x, _PaintRect.z, o.posWS.x), Remap(_PaintRect.y, _PaintRect.w, o.posWS.z));

                return o;
            }

			//对三角面或其他形式图元进行细分的配置
            struct TessParam
            {
                float EdgeTess[3]	: SV_TessFactor;
                float InsideTess	    : SV_InsideTessFactor;
            };
            TessParam ConstantHS(InputPatch<v2t, 3> i, uint id : SV_PrimitiveID)
            {
                TessParam o;
                
                 float2 triVert[3] = { i[0].posWS.xz, i[1].posWS.xz, i[2].posWS.xz };
                 if (IsTriRectCross2D(triVert, _PaintRect))
                 {
                     float2 edgeUV_Rut[3] = { 
                         0.5 * (i[1].uv_Rut + i[2].uv_Rut),
                         0.5 * (i[2].uv_Rut + i[0].uv_Rut),
                         0.5 * (i[0].uv_Rut + i[1].uv_Rut)
                     };
                     float2 centerUV_Rut = (i[0].uv_Rut + i[1].uv_Rut + i[2].uv_Rut) / 3.0;
                     
                     for (uint idx = 0; idx < 3; idx++)
                     {
                         float lerpT = 2.0 * length(edgeUV_Rut[idx] - float2(0.5, 0.5));
                         lerpT = pow(saturate(lerpT), _TessPow);
                         o.EdgeTess[idx] = lerp(_TessStep, 1.0, lerpT);
                     }
                     float lerpT = 2.0 * length(centerUV_Rut - float2(0.5, 0.5));
                     lerpT = pow(saturate(lerpT), _TessPow);
                     o.InsideTess = lerp(_TessStep, 1.0, lerpT);
                 }
                 else
                 {
                     o.EdgeTess[0] = 1;
                     o.EdgeTess[1] = 1;
                     o.EdgeTess[2] = 1;
                     o.InsideTess = 1;
                 }

                return o;
            }
            
            struct TessOut
			{
				float3 posWS	: TEXCOORD0;
                float3 nDirWS : TEXCOORD1;
                float3 tDirWS : TEXCOORD2;
                float3 bDirWS    : TEXCOORD3;
                float2 uv0  : TEXCOORD4;
                float2 uv_Rut : TEXCOORD5;
			};
            [domain("tri")]
            [partitioning("integer")]
            [outputtopology("triangle_cw")]
            [outputcontrolpoints(3)]
            [patchconstantfunc("ConstantHS")]
            [maxtessfactor(64.0)]
            TessOut hs(InputPatch<v2t, 3> i, uint idx : SV_OutputControlPointID)
            {
				TessOut o;
				o.posWS = i[idx].posWS;
                o.nDirWS = i[idx].nDirWS;
                o.tDirWS = i[idx].tDirWS;
                o.bDirWS = i[idx].bDirWS;
                o.uv0 = i[idx].uv0;
                o.uv_Rut = i[idx].uv_Rut;
                return o;
            }
            
            static float minError = 1.5 / 255;
            struct t2f
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
            };
            [domain("tri")]
            t2f ds(TessParam tessParam, float3 bary : SV_DomainLocation, const OutputPatch<TessOut, 3> i)
            {
                t2f o;   
                
                o.posWS = i[0].posWS * bary.x + i[1].posWS * bary.y + i[2].posWS * bary.z;
                o.nDirWS = i[0].nDirWS * bary.x + i[1].nDirWS * bary.y + i[2].nDirWS * bary.z;
                o.tDirWS = i[0].tDirWS * bary.x + i[1].tDirWS * bary.y + i[2].tDirWS * bary.z;
                o.bDirWS = i[0].bDirWS * bary.x + i[1].bDirWS * bary.y + i[2].bDirWS * bary.z;
                float2 uv0 = i[0].uv0 * bary.x + i[1].uv0 * bary.y + i[2].uv0 * bary.z;
                o.uv_Rut = i[0].uv_Rut * bary.x + i[1].uv_Rut * bary.y + i[2].uv_Rut * bary.z;

                float height = tex2Dlod(_RutRTTex, float4(o.uv_Rut, 0, 0)).a;
                height = abs(height - 0.5) < minError ? 0.5 : height;//误差截断，防止在平坦区域产生变形
                o.posWS += _RutHeight * (2.0 * height - 1.0) * o.nDirWS;

                o.posCS = TransformWorldToHClip(o.posWS);

                o.vDirWS = GetCameraPositionWS() - o.posWS;

                o.uv_Main = TRANSFORM_TEX(uv0, _MainTex);
                o.uv_Flash.xy = TRANSFORM_TEX(uv0, _FlashTex);
                
                float3x3 TBN = float3x3(normalize(o.tDirWS), normalize(o.bDirWS), normalize(o.nDirWS));
                float3 vDirTS = TransformWorldToTangent(o.vDirWS, TBN);
                o.uv_Flash.zw = GetPosAnyPlaneCrossDir(float3(0, 0, _FlashOffset), float3(o.uv_Flash.xy, 0), float3(0,0,1), vDirTS).xy;

                return o;
            }

	
            float4 frag(t2f i) : SV_Target
            {
                //轨迹图采样
                float4 var_RutTex = tex2D(_RutRTTex, i.uv_Rut);
                var_RutTex.xyw = abs(var_RutTex.xyw - 0.5) < minError ? 0.5 : var_RutTex.xyw;//误差截断，防止在平坦区域应用法线贴图

                //地形法线
                float3 nDirTS = UnpackNormal(tex2D(_NormalMap, i.uv_Main));
                nDirTS.xy *= _NormalInt;

                //轨迹法线
                float3 nDirTS_Rut = (2.0 * var_RutTex.xyz - 1.0);
                nDirTS_Rut.xy *= _RutHeight * _RutNormalInt;

                //法线混合
                nDirTS = float3(nDirTS.xy / nDirTS.z + nDirTS_Rut.xy / nDirTS_Rut.z, 1.0);
                float3x3 TBN = float3x3(normalize(i.tDirWS), normalize(i.bDirWS), normalize(i.nDirWS));

                //向量
                Light light = GetMainLight(TransformWorldToShadowCoord(i.posWS));
                float3 nDirWS = normalize(mul(nDirTS, TBN));
                float3 lDirWS = light.direction;
                float3 vDirWS = normalize(i.vDirWS);
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