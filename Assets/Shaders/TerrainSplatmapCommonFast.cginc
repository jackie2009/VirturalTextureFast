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
  
UNITY_DECLARE_TEX2DARRAY(AlbedoAtlas);
UNITY_DECLARE_TEX2DARRAY(NormalAtlas);
UNITY_DECLARE_TEX2DARRAY(SpaltWeightTex);


#ifdef _TERRAIN_NORMAL_MAP
    sampler2D _Normal0, _Normal1, _Normal2, _Normal3;
#endif

void SplatmapVert(inout appdata_full v, out Input data)
{
    UNITY_INITIALIZE_OUTPUT(Input, data);
    data.tc_Control = TRANSFORM_TEX(v.texcoord, _Control);  // Need to manually transform uv here, as we choose not to use 'uv' prefix for this texcoord.
    float4 pos = UnityObjectToClipPos(v.vertex);
    UNITY_TRANSFER_FOG(data, pos);


    v.tangent.xyz = cross(v.normal, float3(0,0,1));
    v.tangent.w = -1;

}
 float getChannelValue(float4 clr,int index ){
 
 //return index==0?clr.r:(index==1?clr.g:(index==2?clr.b:clr.a));
 // 应该这样纯数学计算性能更高 （未测试验证）
 const uint  step=256;
  uint v=(uint)(clr.r*step)+(uint)(clr.g*step)*step+(uint)(clr.b*step)*step*step+(uint)(clr.a*step)*step*step*step;
   v/= (uint)(pow(step,(float)index)+0.5);
  return (v%step)/(float)step;
  
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
 int id=(int)( splat_control.r*16+0.5);
 
 float space = 1.0 / clipSize;
 float clipRepeatWid = (1.0 / clipCount - 2.0 *space);
 float2 initUVAlbedo = clipRepeatWid * frac(initScale) + space;
 float2 dx =  clamp(clipRepeatWid * ddx(initScale), -1.0/ clipCount/2, 1.0/ clipCount/2);
 float2 dy =  clamp(clipRepeatWid * ddy(initScale), -1.0/ clipCount/2, 1.0/ clipCount/2);
 int mipmap=(int)(0.5+ log2(max(sqrt(dot(dx, dx)), sqrt(dot(dy, dy)))*clipSize));
 space =( pow(2.0, mipmap)-0.5) / clipSize;
 clipRepeatWid = (1.0 / clipCount - 2.0 *space);
 initUVAlbedo = clipRepeatWid * frac(initScale) + space;
 
float2 dxSplat = clamp(0.5*ddx(IN.tc_Control), -1.0 / clipSize / 2, 1.0 / clipSize / 2);
float2 dySplat = clamp(0.5* ddy(IN.tc_Control), -1.0 / clipSize / 2, 1.0 / clipSize / 2);

float3 uvR = float3(initScale,id);//
half3 colorR = UNITY_SAMPLE_TEX2DARRAY(AlbedoAtlas, uvR);
 
 //根据混合总和为1 把丢弃的部分算给 混合最多的 这样画面影响最小 而且 少采样一次又提升性能
  // 
  //
   id=(int)( splat_control.g*16+0.5);
 float3 uvG= float3(initScale, id);//
 half3 colorG = UNITY_SAMPLE_TEX2DARRAY(AlbedoAtlas, uvG);

   float weightG=  getChannelValue(UNITY_SAMPLE_TEX2DARRAY(SpaltWeightTex, float3(IN.tc_Control, id/4)),id%4);
  
      id=(int)( splat_control.b*16+0.5);
	  float3 uvB = float3(initScale, id);//
	  half3 colorB = UNITY_SAMPLE_TEX2DARRAY(AlbedoAtlas, uvB);

 	  float weightB = getChannelValue(UNITY_SAMPLE_TEX2DARRAY(SpaltWeightTex, float3(IN.tc_Control, id/4)), id % 4);

  // 
   mixedDiffuse.rgb=  colorR*(1-weightG-weightB)+colorG*weightG +colorB*weightB; 
   mixedDiffuse.a=1;
     
    
    //法线少采样一张 一般也够表达效果 因为 3种半透明区域 法线已经减弱了
    
        fixed4 nrm = 0.0f;
        nrm += saturate(1-weightG)* UNITY_SAMPLE_TEX2DARRAY(NormalAtlas, uvR);
        nrm += weightG * UNITY_SAMPLE_TEX2DARRAY(NormalAtlas, uvG);
        
        mixedNormal = UnpackNormal(nrm);
  
       
  
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
