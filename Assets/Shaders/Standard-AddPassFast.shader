// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

Shader "Hidden/TerrainEngine/Splatmap/Standard-AddPassFast" {
 

	SubShader {
		Tags {
			"Queue" = "Geometry-99"
			"IgnoreProjector"="True"
			"RenderType" = "Opaque"
  }
		LOD 100

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
 
			
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
 			};

			struct v2f
			{
				 
			 
				float4 vertex : SV_POSITION;
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;
			
			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
			 
				 
				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				 discard;
				return 1;
			}
			ENDCG
		}
	}
}
