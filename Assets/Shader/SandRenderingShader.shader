Shader "Sand/SandRenderingShader"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		_Roughness("Roughness" , range(0,1)) = 1
		[NoScaleOffset]_RutRTTex ("轨迹渲染纹理", 2D) = "bump" {}
        _PaintRect("轨迹范围", vector) = (0.0, 0.0, 1.0, 1.0)

		[Space(10)]
		[Header(NormalMap)]
		_NormalMapShallowX("Normal Map Shallow X " , 2D ) = "white" {}
		_NormalMapShallowZ("Normal Map Shallow Z " , 2D ) = "white" {}
		_ShallowBumpScale("Shallow Scale " , range(0,2) ) = 1
		_NormalMapSteepX("Normal Map Steep X" , 2D ) = "white" {}
		_NormalMapSteepZ("Normal Map Steep Z" , 2D ) = "white" {}
		_SurfaceNormalScale("Steep Scale " , range(0,2) ) = 1
		_DetailBumpMap( "Detail Bump Map " , 2D ) = "white" {}
		_DetailBumpScale("Detail Bump Scale " ,range(0,2) ) = 1

		[Space(10)]
		[Header(Specular)]
		[Header(OceanSpecular)]
		_OceanSpecularShiness("Ocean Specular Shiness " , float ) = 1
		_Glossiness( "Ocean Shiness Base " , float ) =1
		_OceanSpecularMutiplyer( "Ocean Specular Mutiplyer" , float) = 1
		_OceanSpecularColor ( "Ocean Specular Color " , color ) = (1,1,1,1)
		[Header(NormalSpecular)]
		_SpecularShiness("Specular Shiness " , float ) = 1
		_SpecularColor ( "Specular Color " , color ) = (1,1,1,1)
		_SpecularMutiplyer( "Specular Mutiplyer" , float) = 1

		[Space(10)]
		[Header(Glitter)]
		_GlitterTex( "Glitter Noise Map " , 2D ) = "white" {}
		_Glitterness( "Glitterness " , float ) = 1
		_GlitterRange( "Glitter Range " , float ) = 1
		_GlitterColor( "Glitter Color " , color) = (1,1,1,1)
		_GlitterMutiplyer( "Glitter Mutiplyer" , float) = 1

		[Space(10)]
		[Header(Tessellation)]
        _TessStep ("最大细分段数", range(1, 64)) = 1
        _TessPow ("细分曲线", range(1, 10)) = 2.0
		
		[Space(10)]
		[Header(Rut)]
        _RutHeight ("轨迹高度", float) = 0.5
        _RutNormalInt ("轨迹法线强度", float) = 1.0

		[Space(10)]
		[Header(Test)]
		[Toggle]_IsDiffuse( "Show Diffuse " , float ) = 0
		[Toggle]_IsSmoothSurface( "Smooth Surface " , float ) = 0
		[Toggle]_IsNormal( "Show Normal " , float ) = 0
		[Toggle]_IsDetailNormal( "Show Detail Normal " , float ) = 0
		[Toggle]_IsNormalXZ( "Show Normal XZ" , float ) = 0
		[Toggle]_IsNormalSteep( "SHow Normal Steepness" , float ) = 0
		[Toggle]_IsOceanSpecular( "Ocean Specular" , float ) = 0
		[Toggle]_IsOceanSpecularBase( "Ocean Specular Base" , float ) = 0
		[Toggle]_IsOceanSpecularDetail( "Ocean Specular Detail" , float ) = 0
		[Toggle]_IsSpecular( "Specular" , float ) = 0
		[Toggle]_IsGlitter( "Glitter" , float ) = 0
		[Toggle]_IsGlitterBase( "Glitter Base" , float ) = 0
		[Toggle]_IsGlitterNoise( "Glitter Noise" , float ) = 0
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
            #pragma multi_compile _ _ADDITIONAL_LIGHTS
            #pragma multi_compile_fog
            

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"

            
			CBUFFER_START(UnityPerMaterial)
            
				sampler2D _CameraDepthTexture;
				float4 _MainTex_ST;
	            sampler2D _MainTex;
				sampler2D _RutRTTex;
                float4 _PaintRect;


				// Height Map
				sampler2D _NormalMapShallowX;
				float4 _NormalMapShallowX_ST;
				sampler2D _NormalMapShallowZ;
				float4 _NormalMapShallowZ_ST;
				float _ShallowBumpScale;
				sampler2D _NormalMapSteepX;
				float4 _NormalMapSteepX_ST;
				sampler2D _NormalMapSteepZ;
				float4 _NormalMapSteepZ_ST;
				float _SurfaceNormalScale;

				// Difuuse
				float _Roughness;

				// Detail BumpMap
				sampler2D _DetailBumpMap;
				float4 _DetailBumpMap_ST;
				float _DetailBumpScale;
				float _SpecularShiness;
				float _OceanSpecularShiness;
				float4 _OceanSpecularColor;
				float4 _SpecularColor;
				float _Glossiness;
				float _SpecularMutiplyer;
				float _OceanSpecularMutiplyer;

				float _Glitterness;
				sampler2D _GlitterTex;
				float4 _GlitterTex_ST;
				float4 _GlitterColor;
				float _GlitterRange;
				float _GlitterMutiplyer;
            
				 //细分参数
                uint _TessStep;
                float _TessPow;

                //痕迹
                float _RutHeight;
                float _RutNormalInt;

				float _IsDiffuse;
				float _IsNormal;
				float _IsSmoothSurface;
				float _IsDetailNormal;
				float _IsNormalXZ;
				float _IsNormalSteep;
				float _IsOceanSpecular;
				float _IsSpecular;
				float _IsOceanSpecularBase;
				float _IsOceanSpecularDetail;
				float _IsGlitter;
				float _IsGlitterBase;
				float _IsGlitterNoise;
			CBUFFER_END

            //重映射01
            float Remap(float min, float max, float input)
            {
                float k = 1.0 / (max - min);
                float b = -min * k;
                return saturate(k * input + b);
            }

            //三角是否存在顶点包含在矩形内
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

                //坐标
                o.posWS = TransformObjectToWorld(i.posOS.xyz);

                //向量
                o.nDirWS = TransformObjectToWorldNormal(i.nDirOS);
                o.tDirWS = TransformObjectToWorldDir(i.tDirOS.xyz);
                o.bDirWS = cross(o.nDirWS, o.tDirWS) * i.tDirOS.w;

                //UV
                o.uv0 = i.uv0;
                o.uv_Rut = float2(Remap(_PaintRect.x, _PaintRect.z, o.posWS.x), Remap(_PaintRect.y, _PaintRect.w, o.posWS.z));

                return o;
            }

			//对三角面或其他形式图元进行细分的配置
            struct TessParam
            {
                float EdgeTess[3]	: SV_TessFactor;//各边细分数
                float InsideTess	    : SV_InsideTessFactor;//内部点细分数
            };
            TessParam ConstantHS(InputPatch<v2t, 3> i, uint id : SV_PrimitiveID)
            {
                TessParam o;

                 //判断当前三角面与轨迹的矩形范围是否存在交集
                 float2 triVert[3] = { i[0].posWS.xz, i[1].posWS.xz, i[2].posWS.xz };
                 if (IsTriRectCross2D(triVert, _PaintRect))
                 {
                     //计算边与图元的中心
                     float2 edgeUV_Rut[3] = { 
                         0.5 * (i[1].uv_Rut + i[2].uv_Rut),
                         0.5 * (i[2].uv_Rut + i[0].uv_Rut),
                         0.5 * (i[0].uv_Rut + i[1].uv_Rut)
                     };
                     float2 centerUV_Rut = (i[0].uv_Rut + i[1].uv_Rut + i[2].uv_Rut) / 3.0;
                
                     //基于UV距离进行细分段数判断
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
			
			//将原模型顶点属性按指定图元打包？
            struct TessOut
			{
				float3 posWS	: TEXCOORD0;
                float3 nDirWS : TEXCOORD1;
                float3 tDirWS : TEXCOORD2;
                float3 bDirWS    : TEXCOORD3;
                float2 uv0  : TEXCOORD4;
                float2 uv_Rut : TEXCOORD5;
			};
            [domain("tri")]//图元类型
            [partitioning("integer")]//曲面细分的过渡方式是整数还是小数
            [outputtopology("triangle_cw")]//三角面正方向是顺时针还是逆时针
            [outputcontrolpoints(3)]//输出的控制点数
            [patchconstantfunc("ConstantHS")]//对应之前的细分因子配置阶段的方法名
            [maxtessfactor(64.0)]//最大可能的细分段数
            TessOut hs(InputPatch<v2t, 3> i, uint idx : SV_OutputControlPointID)//在此处进行的操作是对原模型的操作，而非细分后
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
			
			//基于bary在上述打包的图元中进行插值权重混合(经过上面的细分处理形成了一组新的顶点属性组，这一阶段相当于处理这些新顶点的顶点shader)
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

                //线性转换
                o.posWS = i[0].posWS * bary.x + i[1].posWS * bary.y + i[2].posWS * bary.z;
                o.nDirWS = i[0].nDirWS * bary.x + i[1].nDirWS * bary.y + i[2].nDirWS * bary.z;
                o.tDirWS = i[0].tDirWS * bary.x + i[1].tDirWS * bary.y + i[2].tDirWS * bary.z;
                o.bDirWS = i[0].bDirWS * bary.x + i[1].bDirWS * bary.y + i[2].bDirWS * bary.z;
                float2 uv0 = i[0].uv0 * bary.x + i[1].uv0 * bary.y + i[2].uv0 * bary.z;
                o.uv_Rut = i[0].uv_Rut * bary.x + i[1].uv_Rut * bary.y + i[2].uv_Rut * bary.z;

                //痕迹变形
                float height = tex2Dlod(_RutRTTex, float4(o.uv_Rut, 0, 0)).a;
                height = abs(height - 0.5) < minError ? 0.5 : height;//误差截断，防止在平坦区域产生变形
                o.posWS += _RutHeight * (2.0 * height - 1.0) * o.nDirWS;

                //坐标
                o.posCS = TransformWorldToHClip(o.posWS);

                //向量
                o.vDirWS = GetCameraPositionWS() - o.posWS;

                //UV
                o.uv_Main = TRANSFORM_TEX(uv0, _MainTex);
                return o;
            }

            //==== Sand Rendering Function ===//
            float3 GetDetailNormal( float2 uv )
			{
				return normalize( UnpackNormal( tex2D( _DetailBumpMap , _DetailBumpMap_ST.xy * uv.xy + _DetailBumpMap_ST.zw ) ) );
			}

			float3 GetGlitterNoise( float2 uv )
			{
				return tex2D( _GlitterTex , _GlitterTex_ST.xy * uv.xy + _GlitterTex_ST.zw ) ;
			}

			float3 GetSurfaceNormal( float2 uv , float3 temNormal )
			{
				// get the power of xz direction
				// it repersent the how much we should show the x or z texture
				float xzRate = atan( abs( temNormal.z / temNormal.x) ) ;

				xzRate = saturate( pow( xzRate , 9 ) );

				if ( _IsNormalXZ > 0 ) {
					return float3( xzRate , 0 , 0 );
				}

				// get the steepness
				// the shallow and steep texture will be lerped based on this value
				float steepness = atan( 1/ temNormal.y ) ;
				steepness = saturate( pow( steepness , 3 ) );

				if ( _IsNormalSteep ) {
					return float3( steepness , 0 , 0 );
				}

				float3 shallowX = UnpackNormal( tex2D( _NormalMapShallowX , _NormalMapShallowX_ST.xy * uv.xy + _NormalMapShallowX_ST.zw ) ) ;
				float3 shallowZ = UnpackNormal( tex2D( _NormalMapShallowZ , _NormalMapShallowZ_ST.xy * uv.xy + _NormalMapShallowZ_ST.zw ) ) ;
				float3 shallow = shallowX * shallowZ * _ShallowBumpScale; 


				float3 steepX = UnpackNormal( tex2D( _NormalMapSteepX , _NormalMapSteepX_ST.xy * uv.xy + _NormalMapSteepX_ST.zw ) ) ;
				float3 steepZ = UnpackNormal( tex2D( _NormalMapSteepZ , _NormalMapSteepZ_ST.xy * uv.xy + _NormalMapSteepZ_ST.zw ) ) ;
				float3 steep = lerp( steepX , steepZ , xzRate ) ;

				return normalize( lerp( shallow , steep , steepness ) );
			}

            float PhongNormalDistribution(float RdotV, float specularpower, float speculargloss){
			    float Distribution = pow(RdotV,speculargloss) * specularpower;
//			    Distribution *= (2+specularpower) / (2*3.1415926535);
			    return Distribution;
			}

			float GaussianNormalDistribution(float roughness, float NdotH)
			{
			    float roughnessSqr = roughness*roughness;
				float thetaH = atan(NdotH);
			    return exp(-thetaH*thetaH/roughnessSqr);
			}

			float BeckmannNormalDistribution(float roughness, float NdotH)
			{
			    float roughnessSqr = roughness*roughness;
			    float NdotHSqr = NdotH*NdotH;
			    return max(0.000001,(1.0 / (3.1415926535*roughnessSqr*NdotHSqr*NdotHSqr))
						* exp((NdotHSqr-5)/(roughnessSqr*NdotHSqr))) ;
			}

			float GGXNormalDistribution(float roughness, float NdotH)
			{
			    float roughnessSqr = roughness*roughness;
			    float NdotHSqr = NdotH*NdotH;
			    float TanNdotHSqr = (1-NdotHSqr)/NdotHSqr;
			    return saturate( (1.0/3.1415926535) * pow(roughness/(NdotHSqr * roughnessSqr + 1 - NdotHSqr) , 2 ) );
			}

			float TrowbridgeReitzNormalDistribution( float roughness , float NdotH){
			    float roughnessSqr = roughness*roughness;
			    float Distribution = NdotH*NdotH * (roughnessSqr-1.0) + 1.0;
			    return roughnessSqr / (3.1415926535 * Distribution*Distribution);
			}

			float GGXNormalDistributionModify(float roughness, float NdotH)
			{
			    float roughnessSqr = roughness*roughness;
			    float NdotHSqr = NdotH*NdotH;


			    float TanNdotHSqr = saturate(1-NdotHSqr)/NdotHSqr;

			    return (1.0/3.1415926535) * pow(roughness/(NdotHSqr * (roughnessSqr + TanNdotHSqr)) , 2 );
			}

			float TrowbridgeReitzAnisotropicNormalDistribution(float anisotropic,
			 float normal , float3 normalDetail , float3 halfDirection , float3 XDir , float3 YDir ){

				float NdotH = max( 0 , dot( normal , halfDirection ));
				float HdotX = max( 0 , dot( halfDirection , XDir ));
				float HdotY = max( 0 , dot( halfDirection , YDir ));

			    float aspect = sqrt(1.0h-anisotropic * 0.9h);
			    float X = max(.001, pow(1.0-_Glossiness , 2)/aspect) * 5;
			    float Y = max(.001, pow(1.0-_Glossiness, 2)*aspect) * 5;
			    
			    return 1.0 / (3.1415926535 * X*Y * pow( pow(HdotX/X , 2) + pow(HdotY/Y , 2) + NdotH*NdotH , 2 ) );
			}

			float BeckmanGeometricShadowingFunction (float3 light, float3 view , float3 normal, float roughness){
			
				float NdotL = max( 0 , dot( normal , light));
				float NdotV = max( 0 , dot( normal , view));
			    float roughnessSqr = roughness*roughness;
			    float NdotLSqr = NdotL*NdotL;
			    float NdotVSqr = NdotV*NdotV;


			    float calulationL = (NdotL)/(roughnessSqr * sqrt(1- NdotLSqr));
			    float calulationV = (NdotV)/(roughnessSqr * sqrt(1- NdotVSqr));


			    float SmithL = calulationL < 1.6 ? (((3.535 * calulationL)
			 + (2.181 * calulationL * calulationL))/(1 + (2.276 * calulationL) + 
			(2.577 * calulationL * calulationL))) : 1.0;
			    float SmithV = calulationV < 1.6 ? (((3.535 * calulationV) 
			+ (2.181 * calulationV * calulationV))/(1 + (2.276 * calulationV) +
			 (2.577 * calulationV * calulationV))) : 1.0;


				float Gs =  (SmithL * SmithV);
				return Gs;
			}

			float GGXGeometricShadowingFunction (float3 light, float3 view , float3 normal, float roughness){

				float NdotL = max( 0 , dot( normal , light));
				float NdotV = max( 0 , dot( normal , view));
			    float roughnessSqr = roughness*roughness;
			    float NdotLSqr = NdotL*NdotL;
			    float NdotVSqr = NdotV*NdotV;


			    float SmithL = (2 * NdotL)/ (NdotL + sqrt(roughnessSqr +
			 ( 1-roughnessSqr) * NdotLSqr));
			    float SmithV = (2 * NdotV)/ (NdotV + sqrt(roughnessSqr + 
			( 1-roughnessSqr) * NdotVSqr));


				float Gs =  (SmithL * SmithV);
				return Gs;
			}

			

			float GliterDistribution( float3 lightDir , float3 normal, float3 view , float2 uv , float3 pos )
			{
//				float3 halfDirection = normalize( view + lightDir);
				float specBase = saturate( 1 - dot( normal , view ) * 2 );
				float specPow = pow( specBase , 10 / _GlitterRange );

				if ( _IsGlitterBase > 0 )
					return specPow;

				// Get the glitter sparkle from the noise image
				float3 noise = GetGlitterNoise( uv );

				// A very random function to modify the glitter noise 
				float p1 = GetGlitterNoise( uv + float2 ( 0 , _Time.y * 0.001 + view.x * 0.006 )).r;
				float p2 = GetGlitterNoise( uv + float2 ( _Time.y * 0.0006 , _Time.y * 0.0005 + view.y * 0.004  )).g;
//				float p3 = GetGlitterNoise( uv + float2 (  _Time.y * - 0.0005 , 0 )).b;
//				float p4 = GetGlitterNoise( uv + float2 ( _Time.y * 0.0003 , 0  )).r;

//				float sum = (p1 + p2) * (p3 + p4);
				float sum = 4 * p1 * p2;


				float glitter = pow( sum , _Glitterness );
				glitter = max( 0 , glitter * _GlitterMutiplyer - 0.5 ) * 2;

				if ( _IsGlitterNoise > 0 )
					return glitter;

				float sparkle = glitter * specPow;

				return sparkle;
			}


			float SchlickFresnel(float i){
			    float x = clamp(1.0-i, 0.0, 1.0);
			    float x2 = x*x;
			    return x2*x2*x;
			}

			float4 FresnelFunction(float3 SpecularColor,float3 light , float3 viewDirection ){
				float3 halfDirection = normalize( light + viewDirection);
				float power = SchlickFresnel( max( 0 , dot ( light , halfDirection )) );

			    return float4( SpecularColor + (1 - SpecularColor) * power , 1 );
			}

			

			float OrenNayarDiffuse( float3 light, float3 view, float3 norm, float roughness )
			{
			    half VdotN = dot( view , norm );


			    half LdotN = saturate( 4 * dot( light, norm * float3( 1 , 0.5 , 1 ) )); // the function is modifed here 
			    																		// the original one is LdotN = saturate( dot ( light , norm ))

			    half cos_theta_i = LdotN;
			    half theta_r = acos( VdotN );
			    half theta_i = acos( cos_theta_i );
			    half cos_phi_diff = dot( normalize( view - norm * VdotN ),
			                             normalize( light - norm * LdotN ) );
			    half alpha = max( theta_i, theta_r ) ;
			    half beta = min( theta_i, theta_r ) ;
			    half sigma2 = roughness * roughness;
			    half A = 1.0 - 0.5 * sigma2 / (sigma2 + 0.33);
			    half B = 0.45 * sigma2 / (sigma2 + 0.09);
			    
			    return saturate( cos_theta_i ) *
			        (A + (B * saturate( cos_phi_diff ) * sin(alpha) * tan(beta)));
			}

			//像素shader
            float4 frag(t2f i) : SV_Target
            {
                //轨迹图采样
                float4 var_RutTex = tex2D(_RutRTTex, i.uv_Rut);
                var_RutTex.xyw = abs(var_RutTex.xyw - 0.5) < minError ? 0.5 : var_RutTex.xyw;//误差截断，防止在平坦区域应用法线贴图

                //地形法线
                float3 nDirTS = normalize(GetSurfaceNormal( i.uv_Main  , i.nDirWS ) );

                //轨迹法线
                float3 nDirTS_Rut = (2.0 * var_RutTex.xyz - 1.0);
                nDirTS_Rut.xy *= _RutHeight * _RutNormalInt;

                //法线混合
                nDirTS = float3(nDirTS.xy / nDirTS.z + nDirTS_Rut.xy / nDirTS_Rut.z, 1.0);
            	float3x3 TBN = float3x3( normalize( i.tDirWS ) , normalize( i.bDirWS ) , normalize( i.nDirWS ));
				TBN = transpose( TBN);
            	float3 normal = mul( TBN , nDirTS );
            	normal = normalize( normal * _SurfaceNormalScale + i.nDirWS);

            	// 定义主光源方向和颜色
				float3 lightDir = normalize(float3(0.0, 1.0, 0.5)); // 光源方向（可以根据需要调整）
				float3 lightColor = float3(1.0, 1.0, 1.0); // 白色光源

				// 使用点光直射计算
				float intensity = pow(saturate(dot(normal, lightDir)), 8.0); // 使用较高的指数来增强阴影对比
				float3 baseGray = float3(0.5, 0.5, 0.5); // 灰色基色
				float3 directLight = intensity * lightColor * baseGray; // 直接光照效果

				return float4(directLight, 1.0); // 返回直接光照的灰色效果
            }            
            ENDHLSL
        }
    }
}