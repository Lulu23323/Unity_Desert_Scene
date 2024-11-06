using UnityEngine;

public class RutBrush : MonoBehaviour
{
    public RutPainter painter;//�켣�����ܿ�����
    public Texture2D brushTex;//��ˢ���߸߶�����
    [Range(0, 5)] public float brushRadius = 1;//��ˢ�뾶
    [Range(-10, 10)] public float brushInt = 1;//��ˢǿ��
    [Range(0, 1)] public float stepLength = 0.1f;//���Ƽ��

    private Vector2 oldPosXZ;//�ϴλ��Ƶ�XZ��ͶӰλ��
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