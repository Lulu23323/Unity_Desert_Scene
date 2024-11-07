using UnityEngine;

#if UNITY_EDITOR
using UnityEditor;
#endif

public class RutPainter : MonoBehaviour
{
    public Transform playerTf;
    public Renderer groundRenderer;
    public float paintSize = 64;
    public float attenTime = 10;
    public enum RTSize
    {
       _256 = 256,
       _512 = 512,
       _1024 = 1024,
       _2048 = 2048
    }
    public RTSize rtSize = RTSize._1024;
    
    public RenderTexture paintRT;
    private Material paintMat;
    private Material fadeMat;
    public Material groundMat;
    private Vector3 playerOldPos;
    private void Start()
    {
        InitPaintProp();
    }

    private void Update()
    {
        RenderTexture tempRT = RenderTexture.GetTemporary(paintRT.descriptor);
        Graphics.Blit(paintRT, tempRT, fadeMat, 0);
        Graphics.Blit(tempRT, paintRT);
        RenderTexture.ReleaseTemporary(tempRT);
    }
    
    public void InitPaintProp()
    {
        if (playerTf)
        {
            playerOldPos = playerTf.position;
            
            Texture2D tempTex = new Texture2D(1, 1, TextureFormat.ARGB32, 0, true);
            tempTex.SetPixel(0, 0, new Color(0.5f, 0.5f, 1, 0.5f));
            tempTex.Apply();
            
            paintRT = new RenderTexture((int)rtSize, (int)rtSize, 0, RenderTextureFormat.ARGB64, RenderTextureReadWrite.Linear);
            paintRT.wrapMode = TextureWrapMode.Clamp;
            paintRT.filterMode = FilterMode.Bilinear;
            paintRT.anisoLevel = 0;
            Graphics.Blit(tempTex, paintRT);
            
            groundMat = groundRenderer.sharedMaterial;
            groundMat.SetTexture("_RutRTTex", paintRT);
            
            paintMat = new Material(Shader.Find("Scene/RutPaint"));
            fadeMat = new Material(Shader.Find("Scene/RutFade"));
            fadeMat.SetFloat("_AttenTime", attenTime);
        }
    }
    
    public void Paint(Transform tfIN, Texture2D brushTex, float brushRadius, float brushInt)
    {
        Vector4 pos_Offset;
        
        if (tfIN == playerTf)
        {
            Vector3 deltaDir01 = (playerTf.position - playerOldPos) / paintSize;
            int tempRtSize = (int)rtSize;
            deltaDir01 = deltaDir01 * tempRtSize;
            deltaDir01.x = Mathf.Floor(deltaDir01.x) / tempRtSize;
            deltaDir01.z = Mathf.Floor(deltaDir01.z) / tempRtSize;
            pos_Offset = new Vector4(0.5f, 0.5f, deltaDir01.x, deltaDir01.z);
            
            playerOldPos += deltaDir01 * paintSize;
            playerOldPos.y = playerTf.position.y;
            float halfSize = paintSize / 2;
            Vector3 pos00 = playerOldPos - new Vector3(halfSize, 0, halfSize);
            Vector3 pos11 = playerOldPos + new Vector3(halfSize, 0, halfSize);
            groundMat.SetVector("_PaintRect", new Vector4(pos00.x, pos00.z, pos11.x, pos11.z));
        }
        
        else
        {
            Vector3 deltaDir01 = (tfIN.position - playerTf.position) / paintSize;
            pos_Offset = new Vector4(0.5f + deltaDir01.x, 0.5f + deltaDir01.z, 0, 0);
        }
        
        paintMat.SetTexture("_BrushTex", brushTex);
        paintMat.SetVector("_BrushPosTS_Offset", pos_Offset);
        paintMat.SetFloat("_BrushRadius", brushRadius / paintSize);
        paintMat.SetFloat("_BrushInt", brushInt);
        
        RenderTexture tempRT = RenderTexture.GetTemporary(paintRT.descriptor);
        Graphics.Blit(paintRT, tempRT, paintMat, 0);
        Graphics.Blit(tempRT, paintRT);
        RenderTexture.ReleaseTemporary(tempRT);
    }
}

#if UNITY_EDITOR
[CustomEditor(typeof(RutPainter))]
class RutPainterEditor : Editor
{
    RutPainter dst;
    void OnEnable()
    {
        dst = (RutPainter)target;
    }

    public override void OnInspectorGUI()
    {
        Undo.RecordObject(dst, "RutPainter");

        GUILayout.Label("Current Unit Pixel Length = " + dst.paintSize / (float)dst.rtSize);
        dst.playerTf = EditorGUILayout.ObjectField("Player", dst.playerTf, typeof(Transform), true) as Transform;
        dst.groundRenderer = EditorGUILayout.ObjectField("Ground Renderer", dst.groundRenderer, typeof(Renderer), true) as Renderer;
        dst.paintSize = EditorGUILayout.Slider("Paint Range", dst.paintSize, 8, 512);
        dst.attenTime = EditorGUILayout.Slider("Fade Time", dst.attenTime, 0.5f, 60);
        dst.rtSize = (RutPainter.RTSize)EditorGUILayout.EnumPopup("Render Texture Resolution", dst.rtSize);
        GUI.enabled = false;
        dst.paintRT = EditorGUILayout.ObjectField("Trail Texture", dst.paintRT, typeof(RenderTexture), true) as RenderTexture;
        GUI.enabled = true;
        if (GUILayout.Button("Refresh Paint Status"))
        {
            dst.InitPaintProp();
        }

        SceneView.RepaintAll();
    }


    private void OnSceneGUI()
    {
        Transform playerTf = dst.playerTf;
        if (playerTf)
        {
            Handles.color = Color.red;
            float h = 10;
            float r = dst.paintSize / 2;

            Vector3[] tempPos = new Vector3[] {
                playerTf.position + new Vector3(-r, h, -r),
                playerTf.position + new Vector3(-r, h, r),
                playerTf.position + new Vector3(r, h, r),
                playerTf.position + new Vector3(r, h, -r)
            };
            Handles.DrawAAPolyLine(10, tempPos[0], tempPos[1], tempPos[2], tempPos[3], tempPos[0]);
            for (int i = 0; i < tempPos.Length; i++)
            {
                Ray ray = new Ray(tempPos[i], Vector3.down);
                RaycastHit hit = new RaycastHit();
                if (Physics.Raycast(ray, out hit))
                {
                    Handles.DrawAAPolyLine(10, tempPos[i], hit.point);
                }
            }
        }

        Handles.BeginGUI();
        GUI.DrawTexture(new Rect(0, 0, 200, 200), dst.paintRT);
        Handles.EndGUI();
    }
}
#endif