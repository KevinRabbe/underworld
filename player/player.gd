extends CharacterBody3D

const WALK_SPEED := 8.0
const SPRINT_SPEED := 13.0
const JUMP_VELOCITY := 7.5
const GRAVITY := 24.0

var look_sensitivity := 0.0025
var pitch := -0.2
var camera_pivot: Node3D


func _ready() -> void:
	_build_placeholder_body()
	_build_camera()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * look_sensitivity)
		pitch = clamp(pitch - event.relative.y * look_sensitivity, -1.25, 0.65)
		camera_pivot.rotation.x = pitch

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	if Input.is_physical_key_pressed(KEY_SPACE) and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_vector := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	)

	var direction := Vector3.ZERO
	if input_vector.length_squared() > 0.0:
		input_vector = input_vector.normalized()
		direction = (
			transform.basis * Vector3(input_vector.x, 0.0, input_vector.y)
		).normalized()

	var target_speed := WALK_SPEED
	if Input.is_physical_key_pressed(KEY_SHIFT):
		target_speed = SPRINT_SPEED

	velocity.x = direction.x * target_speed
	velocity.z = direction.z * target_speed
	move_and_slide()


func _build_placeholder_body() -> void:
	var collision := CollisionShape3D.new()
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = 0.45
	capsule_shape.height = 1.8
	collision.shape = capsule_shape
	collision.position.y = 0.9
	add_child(collision)

	var body_mesh := MeshInstance3D.new()
	var capsule_mesh := CapsuleMesh.new()
	capsule_mesh.radius = 0.45
	capsule_mesh.height = 1.8
	body_mesh.mesh = capsule_mesh
	body_mesh.position.y = 0.9

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.65, 0.67, 0.72)
	body_mesh.material_override = material
	add_child(body_mesh)


func _build_camera() -> void:
	camera_pivot = Node3D.new()
	camera_pivot.name = "CameraPivot"
	camera_pivot.position = Vector3(0.0, 1.55, 0.0)
	camera_pivot.rotation.x = pitch
	add_child(camera_pivot)

	var spring_arm := SpringArm3D.new()
	spring_arm.name = "SpringArm3D"
	spring_arm.spring_length = 4.5
	spring_arm.margin = 0.15
	spring_arm.collision_mask = 1
	camera_pivot.add_child(spring_arm)

	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.current = true
	camera.fov = 75.0
	spring_arm.add_child(camera)
