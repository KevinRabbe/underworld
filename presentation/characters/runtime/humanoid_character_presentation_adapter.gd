extends RefCounted
class_name UnderworldHumanoidCharacterPresentationAdapter

const ANIMATION_BINDINGS: Array[String] = [
	"prototype.idle", "prototype.walk_forward", "prototype.walk_backward",
	"prototype.strafe_left", "prototype.strafe_right", "prototype.sprint",
	"prototype.jump_start", "prototype.fall", "prototype.land",
	"prototype.attack.light_01", "prototype.dodge.forward",
	"prototype.dodge.backward", "prototype.dodge.left", "prototype.dodge.right",
	"prototype.parry", "prototype.block", "prototype.hit.front",
]

var presentation


func _init(presentation_value = null) -> void:
	presentation = presentation_value


func presentation_kind() -> StringName:
	return &"humanoid"


func supports_animation_binding(binding: String) -> bool:
	return presentation != null and ANIMATION_BINDINGS.has(binding)


func supports_rig_binding(kind: String, target: String) -> bool:
	if presentation == null:
		return false
	if kind == "bone":
		return presentation.skeleton != null and presentation.skeleton.find_bone(target) >= 0
	if kind == "socket":
		return presentation.get_socket(StringName(target)) != null
	return false


func play_animation(binding: String, parameters: Dictionary = {}) -> void:
	if presentation == null:
		return
	match binding:
		"prototype.attack.light_01":
			var duration: float = float(parameters.get("duration", 0.0))
			var attack_kind: StringName = StringName(parameters.get("attack_kind", &"light"))
			presentation.play_attack(duration if duration > 0.0 else 0.42, attack_kind)
		"prototype.parry":
			presentation.play_parry()
		"prototype.dodge.forward", "prototype.dodge.backward", "prototype.dodge.left", "prototype.dodge.right":
			var local_direction: Vector2 = parameters.get("local_direction", Vector2.ZERO)
			if local_direction.is_zero_approx():
				local_direction = _direction_for_dodge_binding(binding)
			presentation.play_dodge(local_direction)
		"prototype.hit.front":
			presentation.play_hit()


func set_held_animation(binding: String, active: bool, _parameters: Dictionary = {}) -> void:
	if presentation != null and binding == "prototype.block":
		presentation.set_blocking(active)


func update_locomotion(_binding: String, context: Dictionary) -> void:
	if presentation == null:
		return
	presentation.update_visual(
		float(context.get("delta", 0.0)),
		context.get("local_velocity", Vector3.ZERO),
		bool(context.get("grounded", false)),
		bool(context.get("sprinting", false))
	)


func resolve_rig_node(kind: String, target: String):
	if presentation == null or kind != "socket":
		return null
	return presentation.get_socket(StringName(target))


func attachment_root(kind: String, target: String):
	if presentation == null or kind != "socket":
		return null
	if target == "hand_r" and presentation.get_tool_visual_root() != null:
		return presentation.get_tool_visual_root()
	return presentation.get_socket(StringName(target))


func reset_presentation() -> void:
	if presentation != null:
		presentation.reset_pose()


static func _direction_for_dodge_binding(binding: String) -> Vector2:
	match binding:
		"prototype.dodge.backward": return Vector2(0.0, -1.0)
		"prototype.dodge.left": return Vector2(-1.0, 0.0)
		"prototype.dodge.right": return Vector2(1.0, 0.0)
	return Vector2(0.0, 1.0)
