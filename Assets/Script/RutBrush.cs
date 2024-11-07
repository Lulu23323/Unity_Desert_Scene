using UnityEngine;

public class RutBrush : MonoBehaviour
{
    public RutPainter painter;
    public Texture2D brushTex;
    [Range(0, 5)] public float brushRadius = 1;
    [Range(-10, 10)] public float brushInt = 1;
    [Range(0, 1)] public float stepLength = 0.1f;

    private Vector2 oldPosXZ;
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