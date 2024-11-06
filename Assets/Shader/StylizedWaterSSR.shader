/*
    关于MVP&深度图 文章参考
     -空间变换
     -两篇文章
     https://zhuanlan.zhihu.com/p/373489211
     https://zhuanlan.zhihu.com/p/389971233
*/

Shader "TAPro/StylizedWaterSSR"
{
    Properties
    {
        [Space(15)]
        [Header(Color)]
        [HDR]_ShallowColor("Shallow Color",Color) = (0.2,1,0.2,1)
        [HDR]_DeepColor("Deep Color",Color) = (0.2,0.2,1,1)
        
        _ShallowDistance("Shallow Distance",Float) = 3
        _DeepDistance("Deep Distance",Float) = 15
        _Density("Density",Range(0,1)) =1
        _DiffuseIntensity("Diffuse Intensity",Float) = 1
        
        [Space(15)]
        [Header(Normal)]
        _NoiseMap("Noise",2D) = "black"{}
        _NormalMap("Normal",2D) = "bump"{}
        _NormalMapScale("NormalMapScale",Range(0,2)) = 1
        _DetailNormalMap("Detail Normal",2D) = "bump"{}
        _DetailNormalMapScale("Detail Normal Map Scale",Range(0,2)) = 1
        _TBNVec("TBN Vec(拉伸高光)",Vector) = (1,1,1,1)
        
        [Space(15)]
        [Header(Specular)]
        [HDR]_SpecularColor("Specular Color",Color)=(1,1,1,1)
        _SpecularRange("Specular Range",Range(0,1)) = 0.5
        _SpecularIntensity("Specular Intensity",Range(0,5)) = 1
        _SepcularNormalMapIntensity("Sepcular Normal Map Intensity",Range(0,1)) =1
        _DiffuseNormalMapIntensity("Diffuse Normal Map Intensity",Range(0,1)) =1
        
        [Space(15)]
        [Header(Caustic)]
        [Toggle(USE_PROCEDURAL_CAUSTIC)] _UseProceduralCaustic("Use Procedural Caustic",Float) =1
        _CausticMap("Caustic Map",2D) ="black"{}
        _CausticFade("Caustic Fade",Range(0,1)) = 0.5
        _CausticUVScale("Procedural Caustic UVScale",Float) = 1
        _CausticIntensity("Caustic Intensity",Range(0,2)) = 1
        
        [Space(15)]
        [Header(SSR)]
        _SSRMaxSampleCount ("SSR Max Sample Count", Range(0, 64)) =64
        _SSRSampleStep ("SSR Sample Step", Range(4, 32)) = 4
        _SSRIntensity ("SSR Intensity", Range(0, 2)) = 1
        _SSRNormalDistortion("SSR Normal Distortion",Range(0,1)) = 0.15
        _SSPRDistortion("Distortion",Float) = 1
        _SSPRFresnelVec("SSPR Vex: pow scale bias",Vector) = (1,1,0,0)
        [KeywordEnum(SSR,PR,None)] _RefType("Reflection Type",Float) =0
        
        [Space(15)]
        [Header(CubeMap)]
        _CubeMap("Cube Map",Cube) = "Black"{}
        
        [Space(15)]
        [Header(SSS)]
        [HDR]_SSSColor("SSS Color",Color) = (0.2,0.2,0.2,1)
        _SSSDistance("_SSSDistance",Range(0,1)) = 0.5
        _SSSExp("_SSSExp",Range(0,1)) = 1
        _SSSIntensity("_SSSIntensity",Range(0,10)) = 1
     
//        _PerPixelCompareBias("Compare Bias",Range(0,1)) =0
//        _PerPixelDepthBias("Depth Bias",Range(0,1)) =0.1
        
        [Space(15)]
        [Header(Cloud)]
        [Toggle(USE_CLOUD_MAP)] _EnableCloudMap("Enable Cloud Map",Float) =0
        _CloudMap ("Cloud Map", 2D) = "Black" {}
        _CloudIntensity("Cloud Intensity",Range(0,1)) = 0.5
        _CloudMoveSpeed("Cloud Move Speed",Float) = 0.1
        _CloudColor("Cloud Color",Color) =(1,1,1,1)
        _WindDirection("Wind Direction",Vector)=(1,0,0,0)
        
        [Space(15)]
        [Header(Shadow)]
        [Toggle(USE_SHADOW)] _UseShadow("Receive Shadow",Float) =0
        _ShadowIntensity("Shadowm Intensity",Range(0,1)) = 0.8
        
        [Space(15)]
        [Header(Foam)]
        [Toggle(USE_FOAM)] _EnableFoam("Enable Foam",Float) =0
        [HDR]_FoamColor("Foam Color",Color)=(1,1,1,1)
        [Toggle] _EnableDynamicFoam("Enable Dynamic Foam",Float) = 1
        _FoamWidth("Foam Width",Range(0,1)) = 0.95
        _FoamSpeed("Foam Speed",Float) = 1
        _FoamFadeDistance("Foam Fade Distance",Range(0,1)) = 0.95
        _FoamNoiseMap ("Foam Noise(xy:uvScale zw:pow scale)", 2D) = "white" {}
        _FoamNoisePowScaleVec("Foam Noise Pow Scale",Vector) = (1,1,1,1)
    }
    SubShader
    {
        Tags { "Queue" = "Transparent"  "RenderPipeline" = "UniversalPipeline" "ShaderModel" = "4.5" }

        Pass
        {
            Name "StylizedWaterSSR"
            
            //cg
            //hlsl
            
            HLSLPROGRAM
            #pragma target 4.5

            #pragma vertex vert
            #pragma fragment frag

            // Universal Render Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT

            #pragma shader_feature _ USE_SHADOW
            #pragma shader_feature _ USE_FOAM
            #pragma shader_feature _ USE_CLOUD_MAP
            #pragma shader_feature _ USE_PROCEDURAL_CAUSTIC
            
            #pragma shader_feature  _REFTYPE_SSR _REFTYPE_PR _REFTYPE_NONE
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
            #include "TALighting.cginc"
            #include "Noise.cginc"
                        
            // #include "WaterSSR.cginc"

            // #define USE_SHADOW

            float4 _ShallowColor,_DeepColor;

            TEXTURE2D(_NoiseMap);SAMPLER(sampler_NoiseMap);
            TEXTURE2D(_NormalMap);SAMPLER(sampler_NormalMap);
            TEXTURE2D(_DetailNormalMap);SAMPLER(sampler_DetailNormalMap);
            TEXTURE2D(_CausticMap);SAMPLER(sampler_CausticMap);
            TEXTURECUBE(_CubeMap);SAMPLER(sampler_CubeMap);
            TEXTURE2D(_CloudMap);SAMPLER(sampler_CloudMap);

            
            TEXTURE2D(_CameraOpaqueTexture);SAMPLER(sampler_CameraOpaqueTexture);
            TEXTURE2D(_CameraDepthTexture);SAMPLER(sampler_CameraDepthTexture);
            
            TEXTURE2D(ssprRT);SAMPLER(sampler_ssprRT);
            TEXTURE2D(ssprBlurRT);SAMPLER(sampler_ssprBlurRT);
            TEXTURE2D(_PlanarReflectionTexture);SAMPLER(sampler_PlanarReflectionTexture);
            TEXTURE2D(_FoamNoiseMap);SAMPLER(sampler_FoamNoiseMap);

            float4 _FoamNoiseMap_ST;
            float4 _FoamNoisePowScaleVec;
            
            // Texture2D _NoiseMap; SamplerState sampler_NoiseMap;
            // Texture2D _NormalMap; SamplerState sampler_NormalMap;
            // Texture2D _DetailNormalMap;SamplerState sampler_DetailNormalMap;float4 _DetailNormalMap_ST;
            float _CausticFade,_CausticUVScale,_CausticIntensity;
            float4 _CausticMap_ST;

            float _DeepDistance,_ShallowDistance,_Density;

            float _SepcularNormalMapIntensity,_DiffuseNormalMapIntensity, _NormalMapScale,_DetailNormalMapScale;
            float4 _LightColor0;

            float4  _SSSColor;
            float _SSSDistance,_SSSExp,_SSSIntensity;

            float4 _CloudMap_ST;
            float4 _WindDirection;
            float _WaveColorIntensity,_CloudMoveSpeed,_CloudIntensity;

            float4 _PlayerPosition;//xyz
            float _SSRIntensity,_SSRNormalDistortion,_SSPRDistortion;
            float4 _SSPRFresnelVec;

            float _DiffuseIntensity;
            float _ShadowIntensity;

            float _FoamWidth,_FoamSpeed,_FoamFadeDistance,_EnableDynamicFoam;
            float4 _FoamColor;

            float _SpecularRange,_SpecularIntensity;
            float4 _SpecularColor;

            float4 _NoiseMap_ST,_NormalMap_ST,_DetailNormalMap_ST;

            float4 _TBNVec;

            struct Attributes
            {
                float4 positionOS : POSITION;
                float4 normalOS   : NORMAL;
                float4 tangentOS  : TANGENT;
                // float4 uv         : TEXCOORD0;
            };
            
            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float4 screenUV   : TEXCOORD1;
                float4 shadowCoord: TEXCOORD2;
                float3 normalWS   : TEXCOORD3;
                float3 tangentWS  : TEXCOORD4;
                float3 bitangentWS: TEXCOORD5;
                // float2 uv         : TEXCOORD6;
            };
            
            Varyings vert(Attributes input)
            {
                Varyings output = (Varyings)0;
                
                output.positionCS   = TransformObjectToHClip(input.positionOS);
                output.positionWS   = TransformObjectToWorld(input.positionOS);
                // output.positionWS   = mul(unity_ObjectToWorld,input.positionOS);
                
                output.screenUV     = ComputeScreenPos(output.positionCS);
                output.normalWS     = TransformObjectToWorldNormal(input.normalOS);
                output.tangentWS    = TransformObjectToWorldNormal(input.tangentOS);

                //unity自己的
                float sign          = input.tangentOS.w * ( unity_WorldTransformParams.w >= 0.0 ? 1.0 : -1.0 );
				output.bitangentWS  = cross( output.normalWS, output.tangentWS ) * sign;
                
                return output;
            }
            
            float CheapSSS(float3 N,float3 L,float3 V,float SSSDistance,float SSSExp,float SSSIntensity)
            {
                float3 fakeN = -normalize(lerp(N,L,SSSDistance));
                float sss = SSSIntensity * pow( saturate( dot(fakeN,V)),SSSExp);
                return max(0,sss);
            }

            float2 voronoihash5( float2 p )
            {
                
                p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
                return frac( sin( p ) *43758.5453);
            }
    
            float voronoi5( float2 v, float time, inout float2 id, inout float2 mr, float smoothness )
            {
                float2 n = floor( v );
                float2 f = frac( v );
                float F1 = 8.0;
                float F2 = 8.0; float2 mg = 0;
                for ( int j = -1; j <= 1; j++ )
                {
                    for ( int i = -1; i <= 1; i++ )
                    {
                        float2 g = float2( i, j );
                        float2 o = voronoihash5( n + g );
                        o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
                        float d = 0.5 * dot( r, r );
                        if( d<F1 ) {
                            F2 = F1;
                            F1 = d; mg = g; mr = r; id = o;
                        } else if( d<F2 ) {
                            F2 = d;
                        }
                    }
                }
                return (F2 + F1) * 0.5;
            }

            // x = width
            // y = height
            // z = 1 + 1.0/width
            // w = 1 + 1.0/height
            //float4 _ScreenParams;

             // x = 1 or -1 (-1 if projection is flipped)
            // y = near plane
            // z = far plane
            // w = 1/far plane
            // float4 _ProjectionParams;

            //screenPixelNdcZ xy: screenPixel z:ndcZ
            void GetScreenInfo(float4 positionCS,out float3 screenPixelNdcZ)
            {
                positionCS.y *= _ProjectionParams.x;
                positionCS.xyz /= positionCS.w;//ndc
                positionCS.xy = positionCS*0.5+0.5;//xy [-1,1] z:[1,0]
                // return float4( positionCS.xy,0,0);
                screenPixelNdcZ.xyz = positionCS.xyz;// NDC空间坐标
            }

            //获取深度值
            float GetDepth(float2 uv)
            {
                return SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, uv).r;
            }

            //获取屏幕rt颜色
            float4 GetSceneColor(float2 uv)
            {
                return SAMPLE_TEXTURE2D(_CameraOpaqueTexture, sampler_CameraOpaqueTexture,uv);
            }

            //判断是否在归一化的ndc坐标内
            bool IsInClipView(float3 Ray)
            {
                if(Ray.z<0 || Ray.z>1 || Ray.x<0 || Ray.x>1 || Ray.y<0 || Ray.y>1)
                {
                    return false;
                }
                return true;
            }
            
            //在ndc 空间之内变换
            //最远距离 当做背景
            //近处的距离 走ssr
            float4 WaterSSR(float3 positionWS,float3 waterNormal=float3(0,1,0))
            {
                float3 V = normalize (  GetWorldSpaceViewDir(positionWS));
                //裁剪空间坐标系 clip space
                float4 positionCS = TransformWorldToHClip(positionWS);
                
                //ssr反射的最远距离
                float SSRLength = 15;
                float FarSSRLength = 15;
                float MaxLingearStep = 16;
                
                float3 reflectDir = reflect(-V,waterNormal);
                
                float3 endWS = positionWS + reflectDir*SSRLength;
                float4 endPositionCS = TransformWorldToHClip(endWS);
                
                float3 farWS = positionWS + reflectDir*FarSSRLength;
                float4 farPositionCS = TransformWorldToHClip(farWS);

                float3 begin_ScreenPixelNdcZ , end_ScreenPixelNdcZ,far_ScreenPixelNdcZ;

                //变换到归一化的ndc坐标 [0,1]
                GetScreenInfo(positionCS,begin_ScreenPixelNdcZ);
                GetScreenInfo(endPositionCS,end_ScreenPixelNdcZ);
                GetScreenInfo(farPositionCS,far_ScreenPixelNdcZ);

                //每一次步进的 向量
                float3 Step = (end_ScreenPixelNdcZ-begin_ScreenPixelNdcZ)/MaxLingearStep;
                float3 Ray = begin_ScreenPixelNdcZ;
                bool isHit = false;
                float2 hitUV = (float2)0;
                
                float LastDepth =Ray.z;
                
                float4 SSRColor = 0;
                //远处的反射 RayMarch 无法Hit到
                // float isFar = 1;
                float isFar=0;

                float fade = pow(1-dot(normalize(V),waterNormal),5);//fresnel
                
                //最远端在相机视口内，取一个屏幕像素当做最远端的反射颜色
                UNITY_BRANCH if((far_ScreenPixelNdcZ).y<1)
                {
                    float farDepth = GetDepth(far_ScreenPixelNdcZ.xy);

                    farDepth = LinearEyeDepth(farDepth,_ZBufferParams);
                    
                    //最远端的距离 大于 ssrlength，那么就取一个保底像素
                    UNITY_BRANCH if(abs(farDepth)>SSRLength)
                    {
                        SSRColor =  GetSceneColor(far_ScreenPixelNdcZ.xy)*fade;
                    }
                }
                                
                // return  SSRColor;
                UNITY_LOOP
                for (int n=1;n<MaxLingearStep;n++)
                {
                    Ray += Step;
                    //如果测试点跑到 视口外面去了，那么停止for循环
                    UNITY_BRANCH if(Ray.z<0 || Ray.z>1 || Ray.x<0 || Ray.x>1 || Ray.y<0 || Ray.y>1)
                    {
                        break;
                    }
                    
                    float Depth = GetDepth(Ray.xy);
                    
                    //上一次深度<Depth<这一次深度
                    if(Ray.z<Depth  && Depth<LastDepth)
                    {
                        isHit = true;
                        hitUV = Ray.xy;
                        break;
                    }
                    LastDepth =Ray.z;
                }
                
                if(isHit)
                {
                    SSRColor = GetSceneColor(hitUV);
                }
                
                return  SSRColor;
            }
            
            half4 frag(Varyings input) : SV_Target
            {
                
                float4 finalColor = 0;
                float3 positionWS = input.positionWS;
                //屏幕空间坐标
                //除以w => 涉及到 mvp 矩阵的推导
                
                /*
                关于MVP&深度图 文章参考
                 -空间变换
                 -两篇文章
                 https://zhuanlan.zhihu.com/p/373489211
                 https://zhuanlan.zhihu.com/p/389971233
                */
                
                float2 screenUV = input.screenUV.xy / input.screenUV.w; //直接在VS中做了除法，效果会出错
                float3 V = normalize( _WorldSpaceCameraPos - positionWS);
                // float3 V = ( GetWorldSpaceViewDir(positionWS));
                float3 L = normalize(_MainLightPosition.xyz);

                //获取阴影 -> shaodwmap -> 面试会问到
                float4 shadowCoord = TransformWorldToShadowCoord(input.positionWS);
                Light mainLight = GetMainLight(shadowCoord);
                    
                float shadow = lerp(_ShadowIntensity,1, mainLight.shadowAttenuation);
                                
//===================== Refraction  扭曲 =======================================================================
                float4 noise = SAMPLE_TEXTURE2D(_NoiseMap, sampler_NoiseMap, input.positionWS.xz*0.1 + float2(-_Time.x*0.5,0) );
                
                //用噪音扰动NormalMap消除Tilling感
                float3 N = normalize(input.normalWS.xyz);
                float3 T = normalize(input.tangentWS.xyz);
                float3 B = normalize(input.bitangentWS.xyz);
                // float3 B = normalize(cross(N, T));
                float3x3 TBN = float3x3(T*_TBNVec.x,B*_TBNVec.y,N*_TBNVec.z);
                
                float4 rawNormalMap = SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, input.positionWS.xz *_NormalMap_ST.xy +float2(_Time.x*0.5,0) );
                float4 rawNormalDetailMap = SAMPLE_TEXTURE2D(_DetailNormalMap, sampler_DetailNormalMap, input.positionWS.xz*_DetailNormalMap_ST.xy +float2(-_Time.x*0.3,0));
                float3 normalMap = UnpackNormalScale(rawNormalMap,_NormalMapScale);

                float3 normalDetailMap = UnpackNormalScale(rawNormalDetailMap, _DetailNormalMapScale);

                normalMap = BlendNormal(normalDetailMap,normalMap);
                 // normalMap = lerp(normalDetailMap,normalMap,0.5);
                
                //TBN是从世界空间到切线空间的矩阵，TBN矩阵是正交矩阵,正交矩阵的逆等于其转置
                normalMap = mul(normalMap,TBN);
                
//===================== PR 平面反射=======================================================================
                // #ifdef _REFTYPE_SSPR
                // float4 sspr = SAMPLE_TEXTURE2D(ssprBlurRT, sampler_ssprBlurRT, screenUV + (normalMap.xz)*0.05*_SSPRDistortion);

                float prFresnel = pow(1-V.y + _SSPRFresnelVec.z,_SSPRFresnelVec.x)*_SSPRFresnelVec.y;

                #ifdef _REFTYPE_NONE
                    float4 pr= 0;
                #elif defined( _REFTYPE_PR)
                    float4 pr = SAMPLE_TEXTURE2D(_PlanarReflectionTexture, sampler_PlanarReflectionTexture, screenUV + (normalMap.xz)*_SSPRDistortion );
                #elif defined( _REFTYPE_SSR)   
                    float4 pr = WaterSSR(positionWS,lerp(N,normalMap,0.005));
                    // float4 pr = WaterSSR(positionWS,lerp(N,normalMap,0));
                #endif
                
//===================== Light Setting =======================================================================
                float4 Radiance = _LightColor0; // mainLight.color
                float LightLum = Luminance(Radiance.xyz);
                
 //===================== Depth Fade 根据深度颜色变换 =======================================================================
                float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, screenUV);
                float3 depthWorldPosition = ComputeWorldSpacePosition(screenUV, depth, UNITY_MATRIX_I_VP);
                
                float depthDistance = length(depthWorldPosition - input.positionWS);
                float depthFade = saturate( depthDistance/_DeepDistance);
                finalColor = lerp(_ShallowColor,_DeepColor,depthFade);
               
                finalColor = lerp( finalColor,pr, prFresnel);
                
                float2 distortionUV = (noise*2-1)*0.01*2;//[-1 ,1]
                float4 sceneColor = SAMPLE_TEXTURE2D(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, screenUV +distortionUV );
                
                float distortionDistanceFade = saturate( depthDistance/_ShallowDistance);
                finalColor = lerp(sceneColor,lerp(sceneColor,finalColor,_Density),distortionDistanceFade);
                
 //===================== Diffuse 漫反射 =======================================================================
                // float3 N = normalize( lerp(float3(0,1,0),normalMap,_NormalMapIntensity) );
                float NL = dot(lerp(N,normalMap,_DiffuseNormalMapIntensity) ,L);
                float NL01 =  NL*0.5+0.5;
                float diffuse = lerp(0.25,1.2,NL01);
                finalColor *= diffuse*LightLum*_DiffuseIntensity;

 //===================== Specular 高光 =======================================================================
                // float3 N_Specular = lerp(float3(0,1,0),normalMap,0.1);
                float3 H = normalize(L+V);
                float specular =  D_DistributionGGX(normalize( lerp(N,normalMap,_SepcularNormalMapIntensity) ), H,_SpecularRange)*_SpecularIntensity;

                //在阴影部分不希望有高光
                finalColor += specular*Radiance.xyzz*mainLight.shadowAttenuation*_SpecularColor;
                
 //===================== Foam 边缘水花=======================================================================
                #ifdef USE_FOAM
                    // return _NoiseMap.Sample(sampler_NoiseMap,  input.positionWS.xz*0.1 + float2(_Time.x*2,0));
                    float foamDistance = 1- saturate(depthDistance/2);
                    //从中间往 岸边动
                    float foamDynamic = 0.5* step( _FoamWidth,frac(foamDistance - _Time.y*0.1*_FoamSpeed + noise.r*0.0325)) * foamDistance*foamDistance;
                  
                    //浪花衰减
                    foamDynamic = _EnableDynamicFoam*foamDynamic* smoothstep( _FoamFadeDistance ,1,foamDistance);
                    float foamStatic =  0.5 *step( _FoamWidth,frac(foamDistance  + noise.r*0.03525)) * foamDistance*foamDistance;
                    float foam = max(foamDynamic,foamStatic);
                    
                    //加点噪音举出
                    float foamNoise = SAMPLE_TEXTURE2D(_FoamNoiseMap, sampler_FoamNoiseMap,positionWS.xz*_FoamNoiseMap_ST.xy);
                    foamNoise = saturate( pow(foamNoise,_FoamNoisePowScaleVec.x) *_FoamNoisePowScaleVec.y);
                 
                    finalColor += foam*LightLum*_FoamColor*foamNoise* saturate(dot(N,V));
                #endif
                
//===================== Caustic 模拟焦散 =======================================================================
                //用深度图的世界坐标采样 CausticMap 模拟其在水中晃动的感觉
                //贴图焦散
                
                #ifndef  USE_PROCEDURAL_CAUSTIC
                    float4 caustic = SAMPLE_TEXTURE2D(_CausticMap, sampler_CausticMap, depthWorldPosition.xz*0.2*_CausticMap_ST.xy+distortionUV*5);
                    // float4 caustic = SAMPLE_TEXTURE2D(_CausticMap, sampler_CausticMap, positionWS.xz*0.2*_CausticMap_ST.xy+distortionUV*5);
                #else
                //程序化焦散
                    float4 caustic =GetCaustic(depthWorldPosition*0.4*_CausticUVScale+distortionUV.xyy*5 + float3(0,_Time.x,0)).xyzz;
                #endif
                                
                caustic *= smoothstep(_CausticFade,1, (1-distortionDistanceFade) )*_CausticIntensity*NL01;
                finalColor += caustic*LightLum* mainLight.shadowAttenuation;
                
//===================== Cloud 云=======================================================================
                #ifdef USE_CLOUD_MAP
                    float2 cloudMapUV = positionWS.xz*_CloudMap_ST.xy*0.01 + _WindDirection.xy* _CloudMoveSpeed*_Time.y;
                    float cloudMap = SAMPLE_TEXTURE2D(_CloudMap,sampler_CloudMap,cloudMapUV).r;
                    float cloud = cloudMap * _CloudIntensity;
                    finalColor +=cloud;
                #endif
                
            //       float4 _CloudMap_ST;
            // float4 _WindDirection;
            // float _WaveColorIntensity,_CloudMoveSpeed;
                

 //===================== SSS 简易次表面散射 =======================================================================
                float4 waterSSS = CheapSSS(N,L,V,_SSSDistance,_SSSExp,_SSSIntensity)*_SSSColor;
                
                finalColor += waterSSS;
                finalColor *= shadow;
                finalColor.a =1;
                // return min(100,finalColor);
                return finalColor;
              
            }
            ENDHLSL

        }
    }
}
