// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)
// Upgrade NOTE: excluded shader from DX11, OpenGL ES 2.0 because it uses unsized arrays
#pragma exclude_renderers d3d11 gles

#ifndef TERRAIN_SPLATMAP_COMMON_CGINC_INCLUDED
#define TERRAIN_SPLATMAP_COMMON_CGINC_INCLUDED

struct Input
{
    float2 uv_Splat0 : TEXCOORD0;
    float2 uv_Splat1 : TEXCOORD1;
    float2 uv_Splat2 : TEXCOORD2;
    float2 uv_Splat3 : TEXCOORD3;
    float2 tc_Control : TEXCOORD4;  // Not prefixing '_Contorl' with 'uv' allows a tighter packing of interpolators, which is necessary to support directional lightmap.
    UNITY_FOG_COORDS(5)
};

sampler2D _Control;
float4 _Control_ST;
sampler2D _Splat0,_Splat1,_Splat2,_Splat3;
uniform sampler2D SpaltIDTex;
uniform sampler2D SpaltWeightTex;
uniform  sampler2D AlbedoAtlas;
uniform  sampler2D NormalAtlas;

#ifdef _TERRAIN_NORMAL_MAP
    sampler2D _Normal0, _Normal1, _Normal2, _Normal3;
#endif

void SplatmapVert(inout appdata_full v, out Input data)
{
    UNITY_INITIALIZE_OUTPUT(Input, data);
    data.tc_Control = TRANSFORM_TEX(v.texcoord, _Control);  // Need to manually transform uv here, as we choose not to use 'uv' prefix for this texcoord.
    float4 pos = UnityObjectToClipPos(v.vertex);
    UNITY_TRANSFER_FOG(data, pos);

#ifdef _TERRAIN_NORMAL_MAP
    v.tangent.xyz = cross(v.normal, float3(0,0,1));
    v.tangent.w = -1;
#endif
}
 
#ifdef TERRAIN_STANDARD_SHADER
void SplatmapMix(Input IN, half4 defaultAlpha, out half4 splat_control, out half weight, out fixed4 mixedDiffuse, inout fixed3 mixedNormal)
#else
void SplatmapMix(Input IN, out float4 splat_control, out half weight, out fixed4 mixedDiffuse, inout fixed3 mixedNormal)
#endif
{

    splat_control = tex2D(SpaltIDTex, IN.tc_Control);
    
     
     
    weight = 1;

    #if !defined(SHADER_API_MOBILE) && defined(TERRAIN_SPLAT_ADDPASS)
        clip(weight == 0.0f ? -1 : 1);
    #endif
float clipSize=1024;//单张图片大小  
int clipCount=4;//4x4 16张的图集
   
float2 initScale = (IN.tc_Control*500/33);//terrain Size/ tile scale
float2 initUVAlbedo = (0.25-2/clipSize) * frac(initScale) +  1/clipSize;
float2 dx = clamp((1.0/clipCount-2/clipSize) * ddx(initScale), -1/clipSize, 1/clipSize);
float2 dy = clamp((1.0/clipCount-2/clipSize) * ddy(initScale), -1/clipSize, 1/clipSize);
   
 int id=(int)( splat_control.r*16+0.5);
 float2 uvR=initUVAlbedo+ float2(id%clipCount,id/clipCount)/clipCount;
 half3 colorR=tex2D(AlbedoAtlas, uvR,dx,dy);
 
 float weightR=  saturate( tex2D(SpaltWeightTex, IN.tc_Control).r);;


   id=(int)( splat_control.g*16+0.5);
  float2 uvG=initUVAlbedo+ float2(id%clipCount,id/clipCount)/clipCount;
   half3 colorG=tex2D(AlbedoAtlas, uvG,dx,dy);
   
  
 
 
   mixedDiffuse.rgb= lerp(colorG,colorR,weightR); 
  mixedDiffuse.a=1;
  
    
    
    //这里图集的法线贴图格式与 常规法线贴图 不同 所以效果有点不同 建议换成普通法线格式 比如 外部sd ps合并图集 
        fixed4 nrm =lerp(tex2D(NormalAtlas, uvG),tex2D(NormalAtlas, uvR),weightR);
 
       mixedNormal = UnpackNormal( nrm);
 
   
   //mixedDiffuse.rgb=idmain==1?half3(1,0,0):half3(0,1,0);
}

#ifndef TERRAIN_SURFACE_OUTPUT
    #define TERRAIN_SURFACE_OUTPUT SurfaceOutput
#endif

void SplatmapFinalColor(Input IN, TERRAIN_SURFACE_OUTPUT o, inout fixed4 color)
{
    color *= o.Alpha;
    #ifdef TERRAIN_SPLAT_ADDPASS
        UNITY_APPLY_FOG_COLOR(IN.fogCoord, color, fixed4(0,0,0,0));
    #else
        UNITY_APPLY_FOG(IN.fogCoord, color);
    #endif
}

void SplatmapFinalPrepass(Input IN, TERRAIN_SURFACE_OUTPUT o, inout fixed4 normalSpec)
{
    normalSpec *= o.Alpha;
}

void SplatmapFinalGBuffer(Input IN, TERRAIN_SURFACE_OUTPUT o, inout half4 outGBuffer0, inout half4 outGBuffer1, inout half4 outGBuffer2, inout half4 emission)
{
    UnityStandardDataApplyWeightToGbuffer(outGBuffer0, outGBuffer1, outGBuffer2, o.Alpha);
    emission *= o.Alpha;
}

#endif // TERRAIN_SPLATMAP_COMMON_CGINC_INCLUDED
