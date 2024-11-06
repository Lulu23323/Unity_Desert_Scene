using UnityEngine;

public class RutBrush : MonoBehaviour
{
    public RutPainter painter;//轨迹绘制总控制器
    public Texture2D brushTex;//笔刷法线高度纹理
    [Range(0, 5)] public float brushRadius = 1;//笔刷半径
    [Range(-10, 10)] public float brushInt = 1;//笔刷强度
    [Range(0, 1)] public float stepLength = 0.1f;//绘制间隔

    private Vector2 oldPosXZ;//上次绘制的XZ面投影位置
    void Start()
    {
        oldPosXZ = this.transform.position;
    }

    public void Paint()
    {
        Vector2 newPosXZ = new Vector2(transform.position.x, transform.position.z);
        if (transform.hasChanged && (newPosXZ - oldPosXZ).sqrMagnitude >= stepLength * stepLength)
        {
            painter.Paint(this.transform, brushTex, brushRadius, brushInt);
            oldPosXZ = newPosXZ;
            transform.hasChanged = false;
        }
    }
}