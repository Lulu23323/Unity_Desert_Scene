using UnityEngine;

public class CameraControl : MonoBehaviour
{
    public Transform playerTf;
    [Range(1, 10)] public float radius = 5;
    [Range(1, 10)] public float speed = 2;
    public float heightOffset = 2.0f; 

    private Transform camTf;

    private void Start()
    {
        camTf = this.transform;
        Cursor.visible = false;
    }

    void Update()
    {
        radius -= Input.GetAxis("Mouse ScrollWheel") * speed;
        radius = Mathf.Clamp(radius, 1, 10);

        camTf.RotateAround(playerTf.position, Vector3.up, speed * Input.GetAxis("Mouse X"));
        camTf.RotateAround(playerTf.position, camTf.right, -speed * Input.GetAxis("Mouse Y"));
        camTf.position = playerTf.position - radius * camTf.forward + Vector3.up * heightOffset;
        
        playerTf.forward = new Vector3(camTf.forward.x, 0, camTf.forward.z);
    }
}