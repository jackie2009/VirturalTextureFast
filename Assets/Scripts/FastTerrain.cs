using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net;
 
using UnityEngine;

public class FastTerrain : MonoBehaviour
{
     public Texture2DArray albedoAtlas;
    public Texture2DArray normalAtlas;

    //slplat 区分id和Weight 主要是因为 id不能插值 但weight需要插值 如果分辨率精度够大 point 采样够平滑 就不需要分2张
    public Texture2D splatID;
    public Texture2DArray splatWeight;
    public Shader terrainShader;
    public TerrainData normalTerrainData;//{ get { return GetComponent<Terrain>().terrainData; } }
    public TerrainData empytTerrainData;
#if UNITY_EDITOR
    [ContextMenu("MakeAlbedoAtlas")]
    // Update is called once per frame
    void MakeAlbedoAtlas()
    {
      
         int sqrCount = 4;
        int wid = normalTerrainData.splatPrototypes[0].texture.width;
        int hei =normalTerrainData.splatPrototypes[0].texture.height;

        int widNormal = normalTerrainData.splatPrototypes[0].normalMap.width;
        int heiNormal = normalTerrainData.splatPrototypes[0].normalMap.height;
        albedoAtlas = new Texture2DArray(wid, hei, sqrCount* sqrCount, normalTerrainData.splatPrototypes[0].texture.format, true,false);
        normalAtlas = new Texture2DArray(widNormal, heiNormal, sqrCount* sqrCount, normalTerrainData.splatPrototypes[0].normalMap.format, true,true);
         
        for (int i = 0; i < sqrCount; i++)
        {
            for (int j = 0; j < sqrCount; j++)
            {
                int index = i * sqrCount + j;

                if (index >= normalTerrainData.splatPrototypes.Length) break;
                for (int k = 0; k < normalTerrainData.splatPrototypes[index].texture.mipmapCount; k++)
                {
                    Graphics.CopyTexture(normalTerrainData.splatPrototypes[index].texture, 0, k, albedoAtlas, index, k);
 
                }
                for (int k = 0; k < normalTerrainData.splatPrototypes[index].normalMap.mipmapCount; k++)
                {
                    Graphics.CopyTexture(normalTerrainData.splatPrototypes[index].normalMap, 0, k, normalAtlas, index, k);
 
                }
     
            }
        }
 
  
    }


    struct SplatData
    {
        public int id;
        public float weight;
        public float nearWeight;
    }


    [ContextMenu("MakeSplat")]
    // Update is called once per frame
    void MakeSplat()
    {
      

         
        int wid = normalTerrainData.alphamapTextures[0].width;
        int hei = normalTerrainData.alphamapTextures[0].height;
        List<Color[]> colors = new List<Color[]>();
        //t.terrainData.alphamapTextures[i].GetPixels();
        for (int i = 0; i < normalTerrainData.alphamapTextures.Length; i++)
        {
            colors.Add(normalTerrainData.alphamapTextures[i].GetPixels());
        }

        splatID = new Texture2D(wid, hei, TextureFormat.RGB24, false, true);

        splatID.filterMode = FilterMode.Point;

        var splatIDColors = splatID.GetPixels();
  
 
        for (int i = 0; i < hei; i++)
        {
            for (int j = 0; j < wid; j++)
            {
                List<SplatData> splatDatas = new List<SplatData>();
                int index = i * wid + j;
   // splatIDColors[index].r=1 / 16.0f;
                //struct 是值引用 所以 Add到list后  可以复用（修改他属性不会影响已经加入的数据）
                for (int k = 0; k < colors.Count; k++)
                {
                    SplatData sd;
                    sd.id = k * 4;
                    sd.weight = colors[k][index].r;
                    sd.nearWeight = getNearWeight(colors[k], index, wid, 0);
                    splatDatas.Add(sd);
                    sd.id++;
                    sd.weight = colors[k][index].g;
                    sd.nearWeight = getNearWeight(colors[k], index, wid, 1);

                    splatDatas.Add(sd);
                    sd.id++;
                    sd.weight = colors[k][index].b;
                    sd.nearWeight = getNearWeight(colors[k], index, wid, 2);

                    splatDatas.Add(sd);
                    sd.id++;
                    sd.weight = colors[k][index].a;
                    sd.nearWeight = getNearWeight(colors[k], index, wid, 3);

                    splatDatas.Add(sd);
                }

            
                //按权重排序选出最重要几个
               splatDatas.Sort((x, y) => -(x.weight+x.nearWeight).CompareTo(y.weight+y.nearWeight));
       
 


                //只存最重要3个图层 用一点压缩方案可以一张图存更多图层 ,这里最多支持16张
                splatIDColors[index].r = splatDatas[0].id / 16f; //
                 splatIDColors[index].g = splatDatas[1].id / 16f;
                 splatIDColors[index].b =  splatDatas[2].id / 16f;
  
            }
        }


        splatID.SetPixels(splatIDColors);
        splatID.Apply();

        
        splatWeight = new Texture2DArray(wid, hei, normalTerrainData.alphamapTextures.Length, normalTerrainData.alphamapTextures[0].format, true, true);
        splatWeight.filterMode = FilterMode.Bilinear;
        for (int i = 0; i < normalTerrainData.alphamapTextures.Length; i++)
        {
            splatWeight.SetPixels(normalTerrainData.alphamapTextures[i].GetPixels(), i);

         }

        splatWeight.Apply();
    }


    private float getNearWeight(Color[] colors, int index, int wid, int rgba)
    {
        float value = 0;
        for (int i = 1; i <= 2; i++)
        {
            value += colors[(index + colors.Length - i) % colors.Length][rgba];
            value += colors[(index + colors.Length + i) % colors.Length][rgba];
            value += colors[(index + colors.Length - wid * i) % colors.Length][rgba];
            value += colors[(index + colors.Length + wid * i) % colors.Length][rgba];
            value += colors[(index + colors.Length + (-1 - wid) * i) % colors.Length][rgba];
            value += colors[(index + colors.Length + (-1 + wid) * i) % colors.Length][rgba];
            value += colors[(index + colors.Length + (1 - wid) * i) % colors.Length][rgba];
            value += colors[(index + colors.Length + (1 + wid) * i) % colors.Length][rgba];
        }

        return value / (8 * 2);
    }

#endif
  
    [ContextMenu("UseFastMode")]
    void useFastMode()
    {
        Terrain t = GetComponent<Terrain>();
      t.terrainData = empytTerrainData;
       
        t.materialType = Terrain.MaterialType.Custom;
      
            t.materialTemplate = new Material(terrainShader);
     

        Shader.SetGlobalTexture("SpaltIDTex", splatID);
        Shader.SetGlobalTexture("SpaltWeightTex", splatWeight);
        Shader.SetGlobalTexture("AlbedoAtlas", albedoAtlas);
        Shader.SetGlobalTexture("NormalAtlas", normalAtlas);
        
    }

    [ContextMenu("UseBuildinMode")]
    void useBuildinMode()
    {
        Terrain t = GetComponent<Terrain>();
        t.terrainData = normalTerrainData;
        t.materialType = Terrain.MaterialType.BuiltInStandard;
        t.materialTemplate = null;
    }


    private bool fastMode = false;

    private void OnGUI()
    {
        if (GUILayout.Button(fastMode ? "自定义渲染ing" : "引擎默认渲染ing"))
        {
            fastMode = !fastMode;
            if (fastMode)
            {
                useFastMode();
            }
            else
            {
                useBuildinMode();
            }
        }
    }
}