extends RefCounted

const ANIMATION_BINDINGS: Array[String] = [
	"prototype.idle",
	"prototype.walk_forward",
	"prototype.walk_backward",
	"prototype.strafe_left",
	"prototype.strafe_right",
	"prototype.sprint",
	"prototype.jump_start",
	"prototype.fall",
	"prototype.land",
	"prototype.attack.light_01",
	"prototype.dodge.forward",
	"prototype.dodge.backward",
	"prototype.dodge.left",
	"prototype.dodge.right",
	"prototype.parry",
	"prototype.block",
	"prototype.hit.front",
]

var mannequin


func _init(p_mannequin = null) -> void:
	mannequin = p_mannequin


func supports_animation_binding(binding: String) -> bool:
	return mannequin != null and ANIMATION_BINDINGS.has(binding)


func supports_rig_binding(kind: String, target: String) -> bool:
	if mannequin == null:
		return false
	if kind == "bone":
		return mannequin.skeleton != null and mannequin.skeleton.find_bone(target) >= 0
	if kind == "socket":
		return mannequin.get_socket(StringName(target)) != null
	return false


func play_animation(binding: String, parameters: Dictionary = {}) -> void:
	if mannequin == null:
		return
	match binding:
		"prototype.attack.light_01":
			var duration: float = float(parameters.get("duration", 0.0))
			if duration > 0.0:
				mannequin.play_attack(duration)
			else:
				mannequin.play_attack()
		"prototype.parry":
			mannequin.play_parry()
		"prototype.dodge.forward", "prototype.dodge.backward", "prototype.dodge.left", "prototype.dodge.right":
			var local_direction: Vector2 = parameters.get("local_direction", Vector2.ZERO)
			if local_direction.is_zero_approx():
				local_direction = _direction_for_dodge_binding(binding)
			mannequin.play_dodge(local_direction)
		"prototype.hit.front":
			mannequin.play_hit()


func set_held_animation(binding: String, active: bool, _parameters: Dictionary = {}) -> void:
	if mannequin == null:
		return
	if binding == "prototype.block":
		mannequin.set_blocking(active)


func update_locomotion(_binding: String, context: Dictionary) -> void:
	if mannequin == null:
		return
	mannequin.update_visual(
		float(context.get("delta", 0.0)),
		context.get("local_velocity", Vector3.ZERO),
		bool(context.get("grounded", false)),
		bool(context.get("sprinting", false))
	)


func resolve_rig_node(kind: String, target: String):
	if mannequin == null or kind != "socket":
		return null
	return mannequin.get_socket(StringName(target))


func attachment_root(kind: String, target: String):
	if mannequin == null or kind != "socket":
		return null
	if target == "hand_r" and mannequin.get_tool_visual_root() != null:
		return mannequin.get_tool_visual_root()
	return mannequin.get_socket(StringName(target))


func reset_presentation() -> void:
	if mannequin != null:
		mannequin.reset_pose()


static func _direction_for_dodge_binding(binding: String) -> Vector2:
	match binding:
		"prototype.dodge.backward": return Vector2(0.0, -1.0)
		"prototype.dodge.left": return Vector2(-1.0, 0.0)
		"prototype.dodge.right": return Vector2(1.0, 0.0)
	return Vector2(0.0, 1.0)
