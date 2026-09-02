extends RefCounted

const ContentRegistry := preload("res://core/content/registry/content_registry.gd")
const SemanticRoleSchemaRegistry := preload("res://core/content/schema/semantic_role_schema_registry.gd")
const AnimationSetDefinition := preload("res://presentation/characters/animation/animation_set_definition.gd")
const RigProfileDefinition := preload("res://presentation/characters/animation/rig_profile_definition.gd")

const ROLE_IDLE := "animation_role.locomotion.idle"
const ROLE_WALK_FORWARD := "animation_role.locomotion.walk_forward"
const ROLE_WALK_BACKWARD := "animation_role.locomotion.walk_backward"
const ROLE_STRAFE_LEFT := "animation_role.locomotion.strafe_left"
const ROLE_STRAFE_RIGHT := "animation_role.locomotion.strafe_right"
const ROLE_SPRINT := "animation_role.locomotion.sprint"
const ROLE_JUMP_START := "animation_role.locomotion.jump_start"
const ROLE_FALL := "animation_role.locomotion.fall"
const ROLE_ATTACK_LIGHT := "animation_role.action.attack.light_01"
const ROLE_ATTACK_HEAVY := "animation_role.action.attack.heavy_01"
const ROLE_TOOL_USE := "animation_role.action.tool_use"
const ROLE_DODGE_FORWARD := "animation_role.action.dodge.forward"
const ROLE_DODGE_BACKWARD := "animation_role.action.dodge.backward"
const ROLE_DODGE_LEFT := "animation_role.action.dodge.left"
const ROLE_DODGE_RIGHT := "animation_role.action.dodge.right"
const ROLE_PARRY := "animation_role.action.parry"
const ROLE_BLOCK := "animation_role.action.block"
const ROLE_HIT_FRONT := "animation_role.reaction.hit.front"
const ROLE_DEATH := "animation_role.reaction.death"

const SOCKET_HAND_RIGHT := "rig_role.socket.hand.right"

var _content_registry
var _role_registry
var _animation_set
var _rig_profile
var _adapter
var _diagnostics: Array[String] = []
var _last_animation_role: String = ""
var _last_locomotion_role: String = ""


func configure(
	content_registry,
	validation_result: Dictionary,
	role_registry,
	animation_set_id: String,
	presentation_adapter
) -> Array[String]:
	_clear_configuration()
	var failures: Array[String] = []

	if content_registry == null or not content_registry is ContentRegistry:
		failures.append("expected ContentRegistry")
	else:
		for failure in content_registry.diagnostics():
			failures.append("content registry: %s" % failure)

	if role_registry == null or not role_registry is SemanticRoleSchemaRegistry:
		failures.append("expected SemanticRoleSchemaRegistry")
	else:
		for failure in role_registry.diagnostics():
			failures.append("semantic role registry: %s" % failure)

	if not validation_result.has("success"):
		failures.append("expected CONTENT-005 validation result")
	elif not bool(validation_result.get("success", false)):
		failures.append("CONTENT-005 validation did not accept animation presentation content")
		for candidate in validation_result.get("diagnostics", []):
			if candidate is Dictionary:
				failures.append("CONTENT-005 %s: %s" % [
					str(candidate.get("code", "diagnostic")),
					str(candidate.get("message", "")),
				])

	failures.append_array(_validate_adapter_shape(presentation_adapter))
	if not failures.is_empty():
		failures.sort()
		_diagnostics.append_array(failures)
		return diagnostics()

	var set_resolution: Dictionary = content_registry.resolve(animation_set_id, AnimationSetDefinition.DEFINITION_FAMILY)
	for failure in set_resolution.get("diagnostics", []):
		failures.append("animation set resolution: %s" % failure)
	var animation_set = set_resolution.get("definition", null)
	if animation_set == null or not animation_set is AnimationSetDefinition:
		failures.append("content definition is not an AnimationSetDefinition: %s" % animation_set_id)
	else:
		failures.append_array(_validation_coverage_failures(validation_result, animation_set_id))
		for failure in animation_set.validate_semantic_contract(role_registry):
			failures.append("animation set semantic contract: %s" % failure)

	var rig_profile = null
	if animation_set != null and animation_set is AnimationSetDefinition:
		var rig_resolution: Dictionary = content_registry.resolve(
			animation_set.rig_profile_id,
			RigProfileDefinition.DEFINITION_FAMILY
		)
		for failure in rig_resolution.get("diagnostics", []):
			failures.append("rig profile resolution: %s" % failure)
		rig_profile = rig_resolution.get("definition", null)
		if rig_profile == null or not rig_profile is RigProfileDefinition:
			failures.append("content definition is not a RigProfileDefinition: %s" % animation_set.rig_profile_id)
		else:
			failures.append_array(_validation_coverage_failures(validation_result, rig_profile.content_id))
			for failure in rig_profile.validate_semantic_contract(role_registry):
				failures.append("rig profile semantic contract: %s" % failure)

	if animation_set != null and animation_set is AnimationSetDefinition:
		for role_id in animation_set.required_role_ids:
			var resolved: Dictionary = animation_set.resolve_role_binding(role_id)
			for failure in resolved.get("diagnostics", []):
				failures.append("required animation role %s: %s" % [role_id, failure])
		for raw_role_id in animation_set.role_bindings.keys():
			var role_id: String = str(raw_role_id)
			var binding: String = str(animation_set.role_bindings[raw_role_id])
			if not bool(presentation_adapter.call("supports_animation_binding", binding)):
				failures.append("presentation adapter does not support animation binding: %s -> %s" % [role_id, binding])

	if (
		animation_set != null
		and animation_set is AnimationSetDefinition
		and rig_profile != null
		and rig_profile is RigProfileDefinition
	):
		for role_id in animation_set.required_rig_role_ids:
			if not rig_profile.role_bindings.has(role_id):
				failures.append("rig profile missing required semantic role: %s" % role_id)
		for raw_role_id in rig_profile.role_bindings.keys():
			var role_id: String = str(raw_role_id)
			var binding: Dictionary = rig_profile.binding_for_role(role_id)
			if binding.is_empty():
				continue
			if not bool(presentation_adapter.call(
				"supports_rig_binding",
				str(binding.get("kind", "")),
				str(binding.get("target", ""))
			)):
				failures.append("presentation adapter does not support rig binding: %s -> %s:%s" % [
					role_id,
					str(binding.get("kind", "")),
					str(binding.get("target", "")),
				])

	failures.sort()
	if not failures.is_empty():
		_diagnostics.append_array(failures)
		return diagnostics()

	_content_registry = content_registry
	_role_registry = role_registry
	_animation_set = animation_set
	_rig_profile = rig_profile
	_adapter = presentation_adapter
	return diagnostics()


func is_ready() -> bool:
	return _diagnostics.is_empty() and _animation_set != null and _rig_profile != null and _adapter != null


func diagnostics() -> Array[String]:
	var result: Array[String] = []
	result.append_array(_diagnostics)
	return result


func animation_set_id() -> String:
	return str(_animation_set.content_id) if _animation_set != null else ""


func rig_profile_id() -> String:
	return str(_rig_profile.content_id) if _rig_profile != null else ""


func last_animation_role() -> String:
	return _last_animation_role


func last_locomotion_role() -> String:
	return _last_locomotion_role


func semantic_role_for_action(action: StringName, local_direction: Vector2 = Vector2.ZERO) -> String:
	match action:
		&"attack": return ROLE_ATTACK_LIGHT
		&"parry": return ROLE_PARRY
		&"block": return ROLE_BLOCK
		&"hit": return ROLE_HIT_FRONT
		&"death": return ROLE_DEATH
		&"dodge": return _dodge_role(local_direction)
	return ""


func semantic_role_for_locomotion(
	local_velocity: Vector3,
	vertical_velocity: float,
	grounded: bool,
	sprinting: bool
) -> String:
	if not grounded:
		return ROLE_JUMP_START if vertical_velocity > 0.2 else ROLE_FALL
	var horizontal := Vector2(local_velocity.x, local_velocity.z)
	if horizontal.length_squared() < 0.0064:
		return ROLE_IDLE
	if sprinting:
		return ROLE_SPRINT
	if absf(horizontal.x) > absf(horizontal.y):
		return ROLE_STRAFE_RIGHT if horizontal.x > 0.0 else ROLE_STRAFE_LEFT
	return ROLE_WALK_FORWARD if horizontal.y >= 0.0 else ROLE_WALK_BACKWARD


func animation_binding_for_role(role_id: String) -> String:
	if not is_ready():
		return ""
	var resolved: Dictionary = _animation_set.resolve_role_binding(role_id)
	if not resolved.get("diagnostics", []).is_empty():
		return ""
	return str(resolved.get("binding", ""))


func rig_binding_for_role(role_id: String) -> Dictionary:
	if not is_ready() or not _role_registry.has_rig_role(role_id):
		return {}
	return _rig_profile.binding_for_role(role_id)


func present_attack(duration: float, attack_kind: StringName = &"light") -> bool:
	var role_id: String = ROLE_ATTACK_HEAVY if attack_kind == &"heavy" else ROLE_ATTACK_LIGHT
	return _play_role(role_id, {
		"duration": maxf(duration, 0.0),
		"attack_kind": attack_kind,
	})


func present_tool_use(duration: float) -> bool:
	return _play_role(ROLE_TOOL_USE, {"duration": maxf(duration, 0.0), "attack_kind": &"light", "presentation_action": "tool_use"})


func present_parry() -> bool:
	return _play_role(ROLE_PARRY)


func present_dodge(local_direction: Vector2) -> bool:
	return _play_role(_dodge_role(local_direction), {"local_direction": local_direction})


func present_hit() -> bool:
	return _play_role(ROLE_HIT_FRONT)


func present_death() -> bool:
	return _play_role(ROLE_DEATH, {"presentation_action": "death"})


func set_blocking(active: bool) -> bool:
	if not is_ready():
		return false
	var binding: String = animation_binding_for_role(ROLE_BLOCK)
	if binding.is_empty():
		return false
	_last_animation_role = ROLE_BLOCK if active else ""
	_adapter.call("set_held_animation", binding, active, {})
	return true


func update_locomotion(
	delta: float,
	local_velocity: Vector3,
	vertical_velocity: float,
	grounded: bool,
	sprinting: bool
) -> bool:
	if not is_ready():
		return false
	var role_id: String = semantic_role_for_locomotion(
		local_velocity,
		vertical_velocity,
		grounded,
		sprinting
	)
	var binding: String = animation_binding_for_role(role_id)
	if binding.is_empty():
		return false
	_last_locomotion_role = role_id
	_adapter.call("update_locomotion", binding, {
		"delta": delta,
		"local_velocity": local_velocity,
		"vertical_velocity": vertical_velocity,
		"grounded": grounded,
		"sprinting": sprinting,
	})
	return true


func resolve_rig_node(role_id: String):
	if not is_ready():
		return null
	var binding: Dictionary = rig_binding_for_role(role_id)
	if binding.is_empty():
		return null
	return _adapter.call(
		"resolve_rig_node",
		str(binding.get("kind", "")),
		str(binding.get("target", ""))
	)


func attachment_root(role_id: String):
	if not is_ready():
		return null
	var binding: Dictionary = rig_binding_for_role(role_id)
	if binding.is_empty():
		return null
	return _adapter.call(
		"attachment_root",
		str(binding.get("kind", "")),
		str(binding.get("target", ""))
	)


func reset_presentation() -> void:
	_last_animation_role = ""
	_last_locomotion_role = ""
	if is_ready():
		_adapter.call("reset_presentation")


func _play_role(role_id: String, parameters: Dictionary = {}) -> bool:
	if not is_ready():
		return false
	var binding: String = animation_binding_for_role(role_id)
	if binding.is_empty():
		return false
	_last_animation_role = role_id
	_adapter.call("play_animation", binding, parameters)
	return true


static func _dodge_role(local_direction: Vector2) -> String:
	if local_direction.is_zero_approx():
		return ROLE_DODGE_FORWARD
	var normalized: Vector2 = local_direction.normalized()
	if absf(normalized.x) > absf(normalized.y):
		return ROLE_DODGE_RIGHT if normalized.x > 0.0 else ROLE_DODGE_LEFT
	return ROLE_DODGE_FORWARD if normalized.y >= 0.0 else ROLE_DODGE_BACKWARD


static func _validation_coverage_failures(
	validation_result: Dictionary,
	content_id: String
) -> Array[String]:
	var failures: Array[String] = []
	var covered: bool = false
	for raw_id in validation_result.get("validated_definition_ids", []):
		if str(raw_id) == content_id:
			covered = true
			break
	if not covered:
		failures.append("CONTENT-005 validation result does not cover content id: %s" % content_id)
	return failures


static func _validate_adapter_shape(candidate) -> Array[String]:
	var failures: Array[String] = []
	if candidate == null:
		return ["presentation adapter is required"]
	var required_methods: Array[String] = [
		"supports_animation_binding",
		"supports_rig_binding",
		"play_animation",
		"set_held_animation",
		"update_locomotion",
		"resolve_rig_node",
		"attachment_root",
		"reset_presentation",
	]
	for method_name in required_methods:
		if not candidate.has_method(method_name):
			failures.append("presentation adapter missing required method: %s" % method_name)
	return failures


func _clear_configuration() -> void:
	_content_registry = null
	_role_registry = null
	_animation_set = null
	_rig_profile = null
	_adapter = null
	_diagnostics.clear()
	_last_animation_role = ""
	_last_locomotion_role = ""
