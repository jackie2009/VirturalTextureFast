Shader "Custom/TerrainMesh" {
	Properties {
		_Color ("Color", Color) = (1,1,1,1)
		_MainTex ("Albedo (RGB)", 2D) = "white" {}
		_Glossiness ("Smoothness", Range(0,1)) = 0.5
		_Metallic ("Metallic", Range(0,1)) = 0.0
	}
	SubShader {
		Tags { "RenderType"="Opaque" }
		LOD 200
		
		CGPROGRAM
		// Physically based Standard lighting model, and enable shadows on all light types
		#pragma surface surf Standard fullforwardshadows

		// Use shader model 3.0 target, to get nicer looking lighting
		#pragma target 3.0

		sampler2D _MainTex;

		struct Input {
			float2 uv_MainTex;
		};

		half _Glossiness;
		half _Metallic;
		fixed4 _Color;
uniform sampler2D SpaltIDTex;
uniform sampler2D SpaltWeightTex;
uniform  sampler2D AlbedoAtlas;
uniform  sampler2D NormalAtlas;

		// Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
		// See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
		// #pragma instancing_options assumeuniformscaling
		UNITY_INSTANCING_CBUFFER_START(Props)
			// put more per-instance properties here
		UNITY_INSTANCING_CBUFFER_END
half getColorByIndex(half4 clr,int index)
{
return index==0?  clr.r:(index==1?  clr.g:(index==2? clr.b:clr.a));
}
		void surf (Input IN, inout SurfaceOutputStandard o) {
 half4			 splat_control = tex2D(SpaltIDTex, IN.uv_MainTex);
    
    
 
 
     
     
float    weight = 1;

 
   float clipSize=1024;
   int adgeAdd=1; 
   int clipCount=4;
   float scale=clipSize/(clipSize*clipCount+clipCount*2*adgeAdd);
 float2 initUV=frac(IN.uv_MainTex*500/33)*scale;
 int id=(int)( splat_control.r/10+0.5);
 int idTest=id;
 float weightR=  getColorByIndex(tex2D(SpaltWeightTex, IN.uv_MainTex/2+half2((id/4)%2,id/4/2)/2),id%4);// [id%4];
 float2 uvR=initUV+ float2(id%clipCount,id/clipCount)/clipCount+scale*adgeAdd/clipSize;
 
 
 half3 colorR=tex2D(AlbedoAtlas, uvR);

   id=(int)( splat_control.g/10+0.5);
   float weightG=getColorByIndex(tex2D(SpaltWeightTex, IN.uv_MainTex/2+half2((id/4)%2,id/4/2)/2),id%4);
 float2 uvG=initUV+ float2(id%clipCount,id/clipCount)/clipCount+scale*adgeAdd/clipSize;
   half3 colorG=tex2D(AlbedoAtlas, uvG);
   
      id=(int)( splat_control.b/10+0.5);
      float weightB= getColorByIndex(tex2D(SpaltWeightTex, IN.uv_MainTex/2+half2((id/4)%2,id/4/2)/2),id%4);
float2 uvB=initUV+ float2(id%clipCount,id/clipCount)/clipCount+scale*adgeAdd/clipSize;
   half3 colorB=tex2D(AlbedoAtlas, uvB);
 //mixedDiffuse=lerp(mixedDiffuse, tex2D(AlbedoAtlas, uv),pow(splat_weight.g,1));
 weightR=1-weightG-weightB;
 //weightB=0;
o.Albedo = (colorR*weightR+colorG*weightG+colorB*weightB);//idTest==4?half3(1,0,0):half3(0,1,0);//
 
  
    
    #ifdef _TERRAIN_NORMAL_MAP
        fixed4 nrm = 0.0f;
    //  nrm+=tex2D(NormalAtlas, uvR)*weightR;
      //nrm+=tex2D(NormalAtlas, uvG)*weightG;
    //  nrm+=tex2D(NormalAtlas, uvB)*weightB;
 
      // mixedNormal = UnpackNormal(nrm);
    #endif
		 
			// Metallic and smoothness come from slider variables
			o.Metallic = 0;
			o.Smoothness = 0.1;
			o.Alpha = 1;
		}
		ENDCG
	}
	FallBack "Diffuse"
}
