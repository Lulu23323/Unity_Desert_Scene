using UnityEngine;

public class PlayerControl : MonoBehaviour
{
    public float speed = 1.5f;
    public float mulSpeed = 2;
    public float jumpH = 1;

    private CharacterController controller;
    private RutBrush brush;
    private void Start()
    {
        controller = this.GetComponent<CharacterController>();
        brush = this.GetComponent<RutBrush>();
    }

    private const float g = 9.8f;
    void Update()
    {
        if (controller.isGrounded)
        {
            float currentSpeed = speed;
            if (Input.GetKey(KeyCode.LeftShift))
            {
                currentSpeed = mulSpeed * speed;
            }
            if (Input.GetKey(KeyCode.W))
            {
                controller.SimpleMove(transform.forward * currentSpeed);
            }
            if (Input.GetKey(KeyCode.S))
            {
                controller.SimpleMove(-transform.forward * currentSpeed);
            }
            if (Input.GetKey(KeyCode.A))
            {
                controller.SimpleMove(-transform.right * currentSpeed);
            }
            if (Input.GetKey(KeyCode.D))
            {
                controller.SimpleMove(transform.right * currentSpeed);
            }
            if (Input.GetKeyDown(KeyCode.Space))
            {
                controller.Move((controller.velocity + Mathf.Sqrt(2 * g * jumpH) * Vector3.up) * Time.deltaTime);
            }
        }
        else
        {
            controller.Move((controller.velocity + g * Time.deltaTime * Vector3.down) * Time.deltaTime);
        }

        if (controller.collisionFlags == CollisionFlags.Below)
        {
            if (brush)
            {
                brush.Paint();
            }
        }
    }
}