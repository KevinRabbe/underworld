extends RefCounted

const ContentRegistry := preload("res://core/content/registry/content_registry.gd")
const CategorySchemaRegistry := preload("res://core/content/schema/category_schema_registry.gd")
const CapabilitySchemaRegistry := preload("res://core/content/schema/capability_schema_registry.gd")
const ContentValidationPipeline := preload("res://core/content/validation/content_validation_pipeline.gd")
const AnimationSetDefinition := preload("res://presentation/characters/animation/animation_set_definition.gd")
const RigProfileDefinition := preload("res://presentation/characters/animation/rig_profile_definition.gd")
const CharacterSemanticSchemaCatalog := preload("res://presentation/characters/animation/character_semantic_schema_catalog.gd")
const CharacterAnimationController := preload("res://presentation/characters/animation/character_animation_controller.gd")
const PrototypeMannequin := preload("res://presentation/characters/player/prototype_mannequin/prototype_mannequin.gd")
const PrototypeAnimationRuntimeFactory := preload("res://presentation/characters/player/prototype_mannequin/prototype_animation_runtime_factory.gd")
const PlayerActionController := preload("res://gameplay/player/actions/player_action_controller.gd")


class RecordingAdapter:
	extends RefCounted
	var animation_bindings: Array[String] = []
	var rig_bindings: Array[String] = []
	var last_played: String = ""
	var last_parameters: Dictionary = {}
	var last_held: String = ""
	var held_active: bool = false
	var last_locomotion: String = ""
	var socket_node := Node3D.new()

	func supports_animation_binding(binding: String) -> bool:
		return animation_bindings.has(binding)

	func supports_rig_binding(kind: String, target: String) -> bool:
		return rig_bindings.has("%s:%s" % [kind, target])

	func play_animation(binding: String, parameters: Dictionary = {}) -> void:
		last_played = binding
		last_parameters = parameters.duplicate(true)

	func set_held_animation(binding: String, active: bool, _parameters: Dictionary = {}) -> void:
		last_held = binding
		held_active = active

	func update_locomotion(binding: String, _context: Dictionary) -> void:
		last_locomotion = binding

	func resolve_rig_node(kind: String, target: String):
		return socket_node if supports_rig_binding(kind, target) else null

	func attachment_root(kind: String, target: String):
		return resolve_rig_node(kind, target)

	func reset_presentation() -> void:
		last_played = ""
		last_parameters.clear()
		last_held = ""
		held_active = false
		last_locomotion = ""

	func dispose() -> void:
		socket_node.free()


class TestStamina:
	extends RefCounted
	var current_stamina: float = 100.0

	func spend(amount: float) -> bool:
		if amount > current_stamina:
			return false
		current_stamina -= amount
		return true

	func can_spend(amount: float) -> bool:
		return current_stamina >= amount


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_two_sets_and_rigs_share_semantics(failures)
	_test_missing_role_diagnostics(failures)
	_test_authored_prototype_runtime(failures)
	return failures


static func _test_two_sets_and_rigs_share_semantics(failures: Array[String]) -> void:
	var role_registry = CharacterSemanticSchemaCatalog.build_registry()
	var rig_a = _rig(
		"rig_profile.humanoid.test_a",
		"root_a",
		"hand_a"
	)
	var rig_b = _rig(
		"rig_profile.humanoid.test_b",
		"root_b",
		"hand_b"
	)
	var set_a = _set(
		"animation_set.humanoid.test_a",
		rig_a.content_id,
		"pack_a"
	)
	var set_b = _set(
		"animation_set.humanoid.test_b",
		rig_b.content_id,
		"pack_b"
	)
	var definitions: Array = [set_b, rig_a, set_a, rig_b]
	var fixture: Dictionary = _validated_content(definitions)
	if not bool(fixture.get("success", false)):
		failures.append("semantic animation fixture failed CONTENT-005: %s" % [fixture.get("diagnostics", [])])
		return

	var adapter_a = _adapter_for_set(set_a, "root_a", "hand_a")
	var adapter_b = _adapter_for_set(set_b, "root_b", "hand_b")
	var controller_a = CharacterAnimationController.new()
	var controller_b = CharacterAnimationController.new()
	var diagnostics_a: Array[String] = controller_a.configure(
		fixture["registry"],
		fixture["validation"],
		role_registry,
		set_a.content_id,
		adapter_a
	)
	var diagnostics_b: Array[String] = controller_b.configure(
		fixture["registry"],
		fixture["validation"],
		role_registry,
		set_b.content_id,
		adapter_b
	)
	if not diagnostics_a.is_empty() or not diagnostics_b.is_empty():
		failures.append("semantic controllers rejected compatible set/rig pairs: %s / %s" % [diagnostics_a, diagnostics_b])
		adapter_a.dispose()
		adapter_b.dispose()
		return

	_expect_equal(
		failures,
		"gameplay attack maps to semantic role",
		controller_a.semantic_role_for_action(&"attack"),
		"animation_role.action.attack.light_01"
	)
	_expect_equal(
		failures,
		"left dodge maps to semantic role",
		controller_a.semantic_role_for_action(&"dodge", Vector2(-1.0, 0.0)),
		"animation_role.action.dodge.left"
	)

	var gameplay = PlayerActionController.new(TestStamina.new())
	_expect_true(
		failures,
		"gameplay attack starts independently of animation set",
		gameplay.try_start_attack(0.12, 0.08, 0.30)
	)
	var authoritative_duration: float = gameplay.get_attack_total_duration()
	controller_a.present_attack(authoritative_duration)
	controller_b.present_attack(authoritative_duration)
	_expect_equal(failures, "set A receives its concrete binding", adapter_a.last_played, "pack_a.attack")
	_expect_equal(failures, "set B receives its concrete binding", adapter_b.last_played, "pack_b.attack")
	_expect_equal(
		failures,
		"presentation receives gameplay-owned attack duration A",
		float(adapter_a.last_parameters.get("duration", -1.0)),
		authoritative_duration
	)
	_expect_equal(
		failures,
		"presentation receives gameplay-owned attack duration B",
		float(adapter_b.last_parameters.get("duration", -1.0)),
		authoritative_duration
	)
	_expect_equal(
		failures,
		"changing animation set does not change gameplay timing",
		gameplay.get_attack_total_duration(),
		authoritative_duration
	)

	controller_a.present_dodge(Vector2(-1.0, 0.0))
	controller_b.present_dodge(Vector2(-1.0, 0.0))
	_expect_equal(failures, "set A left-dodge binding", adapter_a.last_played, "pack_a.dodge_left")
	_expect_equal(failures, "set B left-dodge binding", adapter_b.last_played, "pack_b.dodge_left")

	controller_a.set_blocking(true)
	controller_b.set_blocking(true)
	_expect_equal(failures, "set A block binding", adapter_a.last_held, "pack_a.block")
	_expect_equal(failures, "set B block binding", adapter_b.last_held, "pack_b.block")
	_expect_true(failures, "set A block is held presentation", adapter_a.held_active)
	_expect_true(failures, "set B block is held presentation", adapter_b.held_active)

	controller_a.update_locomotion(1.0 / 60.0, Vector3(0.0, 0.0, 4.0), 0.0, true, false)
	controller_b.update_locomotion(1.0 / 60.0, Vector3(0.0, 0.0, 4.0), 0.0, true, false)
	_expect_equal(failures, "set A locomotion binding", adapter_a.last_locomotion, "pack_a.walk_forward")
	_expect_equal(failures, "set B locomotion binding", adapter_b.last_locomotion, "pack_b.walk_forward")

	_expect_true(
		failures,
		"rig A semantic socket resolves through profile",
		controller_a.resolve_rig_node("rig_role.socket.hand.right") == adapter_a.socket_node
	)
	_expect_true(
		failures,
		"rig B semantic socket resolves through profile",
		controller_b.resolve_rig_node("rig_role.socket.hand.right") == adapter_b.socket_node
	)

	adapter_a.dispose()
	adapter_b.dispose()


static func _test_missing_role_diagnostics(failures: Array[String]) -> void:
	var role_registry = CharacterSemanticSchemaCatalog.build_registry()
	var rig = _rig("rig_profile.humanoid.bad_role", "root_bad", "hand_bad")
	var bad_set = AnimationSetDefinition.new()
	bad_set.configure_animation_set("animation_set.humanoid.bad_role", rig.content_id)
	bad_set.role_bindings = {
		"animation_role.action.not_registered": "bad.unknown",
	}
	bad_set.required_role_ids = ["animation_role.action.not_registered"]
	bad_set.required_rig_role_ids = ["rig_role.root"]
	var fixture: Dictionary = _validated_content([bad_set, rig])
	if not bool(fixture.get("success", false)):
		failures.append("unknown-role fixture should pass generic CONTENT-005 syntax/reference validation")
		return
	var adapter = RecordingAdapter.new()
	adapter.animation_bindings = ["bad.unknown"]
	adapter.rig_bindings = ["bone:root_bad", "socket:hand_bad"]
	var controller = CharacterAnimationController.new()
	var diagnostics: Array[String] = controller.configure(
		fixture["registry"],
		fixture["validation"],
		role_registry,
		bad_set.content_id,
		adapter
	)
	_expect_true(
		failures,
		"unknown semantic role fails clearly after CONTENT-005",
		_has_fragment(diagnostics, "unknown animation role schema id")
	)
	_expect_true(failures, "controller remains unconfigured after unknown role", not controller.is_ready())
	adapter.dispose()


static func _test_authored_prototype_runtime(failures: Array[String]) -> void:
	var mannequin = PrototypeMannequin.new()
	mannequin.build()
	var runtime: Dictionary = PrototypeAnimationRuntimeFactory.build(mannequin)
	if not bool(runtime.get("success", false)):
		failures.append("authored prototype animation runtime failed: %s" % [runtime.get("diagnostics", [])])
		mannequin.free()
		return
	var controller = runtime.get("controller")
	_expect_true(failures, "prototype semantic controller is ready", controller != null and controller.is_ready())
	if controller == null or not controller.is_ready():
		mannequin.free()
		return

	_expect_equal(
		failures,
		"prototype authored animation set id",
		controller.animation_set_id(),
		"animation_set.humanoid.prototype"
	)
	_expect_equal(
		failures,
		"prototype authored rig profile id",
		controller.rig_profile_id(),
		"rig_profile.humanoid.prototype"
	)
	_expect_equal(
		failures,
		"prototype semantic parry resolves to concrete presentation binding",
		controller.animation_binding_for_role("animation_role.action.parry"),
		"prototype.parry"
	)
	_expect_equal(
		failures,
		"prototype configured death fallback resolves explicitly",
		controller.animation_binding_for_role("animation_role.reaction.death"),
		"prototype.hit.front"
	)
	_expect_true(
		failures,
		"prototype semantic right-hand socket resolves to mannequin socket",
		controller.resolve_rig_node("rig_role.socket.hand.right") == mannequin.get_socket(&"hand_r")
	)
	_expect_true(
		failures,
		"prototype attachment root remains available through semantic socket role",
		controller.attachment_root("rig_role.socket.hand.right") == mannequin.get_tool_visual_root()
	)

	controller.present_attack(0.70)
	_expect_equal(failures, "semantic attack reaches mannequin adapter", mannequin.current_action, mannequin.ACTION_ATTACK)
	controller.update_locomotion(0.45, Vector3.ZERO, 0.0, true, false)
	_expect_equal(
		failures,
		"gameplay-supplied attack duration remains active before end",
		mannequin.current_action,
		mannequin.ACTION_ATTACK
	)
	controller.update_locomotion(0.30, Vector3.ZERO, 0.0, true, false)
	_expect_equal(
		failures,
		"gameplay-supplied attack duration ends after supplied duration",
		mannequin.current_action,
		mannequin.ACTION_NONE
	)
	controller.present_death()
	_expect_equal(
		failures,
		"configured death fallback reaches hit presentation",
		mannequin.current_action,
		mannequin.ACTION_HIT
	)
	mannequin.free()


static func _validated_content(definitions: Array) -> Dictionary:
	var registry = ContentRegistry.new()
	var registry_diagnostics: Array[String] = registry.index_definitions(definitions)
	var categories = CategorySchemaRegistry.new()
	categories.index_schemas([])
	var capabilities = CapabilitySchemaRegistry.new()
	capabilities.index_schemas([])
	var validation: Dictionary = ContentValidationPipeline.new().validate_all(
		definitions,
		categories,
		capabilities
	)
	var diagnostics: Array[String] = []
	diagnostics.append_array(registry_diagnostics)
	if not bool(validation.get("success", false)):
		for diagnostic in validation.get("diagnostics", []):
			diagnostics.append(str(diagnostic))
	return {
		"success": diagnostics.is_empty(),
		"registry": registry,
		"validation": validation,
		"diagnostics": diagnostics,
	}


static func _rig(content_id: String, root_target: String, hand_target: String):
	var rig = RigProfileDefinition.new()
	rig.configure_rig_profile(content_id)
	rig.set_role_binding("rig_role.root", "bone", root_target)
	rig.set_role_binding("rig_role.socket.hand.right", "socket", hand_target)
	return rig


static func _set(content_id: String, rig_profile_id: String, prefix: String):
	var set = AnimationSetDefinition.new()
	set.configure_animation_set(content_id, rig_profile_id)
	set.role_bindings = {
		"animation_role.locomotion.idle": prefix + ".idle",
		"animation_role.locomotion.walk_forward": prefix + ".walk_forward",
		"animation_role.locomotion.walk_backward": prefix + ".walk_backward",
		"animation_role.locomotion.strafe_left": prefix + ".strafe_left",
		"animation_role.locomotion.strafe_right": prefix + ".strafe_right",
		"animation_role.locomotion.sprint": prefix + ".sprint",
		"animation_role.locomotion.jump_start": prefix + ".jump_start",
		"animation_role.locomotion.fall": prefix + ".fall",
		"animation_role.action.attack.light_01": prefix + ".attack",
		"animation_role.action.dodge.forward": prefix + ".dodge_forward",
		"animation_role.action.dodge.backward": prefix + ".dodge_backward",
		"animation_role.action.dodge.left": prefix + ".dodge_left",
		"animation_role.action.dodge.right": prefix + ".dodge_right",
		"animation_role.action.parry": prefix + ".parry",
		"animation_role.action.block": prefix + ".block",
	}
	set.required_role_ids = [
		"animation_role.locomotion.idle",
		"animation_role.locomotion.walk_forward",
		"animation_role.locomotion.walk_backward",
		"animation_role.locomotion.strafe_left",
		"animation_role.locomotion.strafe_right",
		"animation_role.locomotion.sprint",
		"animation_role.locomotion.jump_start",
		"animation_role.locomotion.fall",
		"animation_role.action.attack.light_01",
		"animation_role.action.dodge.forward",
		"animation_role.action.dodge.backward",
		"animation_role.action.dodge.left",
		"animation_role.action.dodge.right",
		"animation_role.action.parry",
		"animation_role.action.block",
	]
	set.required_rig_role_ids = ["rig_role.root", "rig_role.socket.hand.right"]
	return set


static func _adapter_for_set(set, root_target: String, hand_target: String):
	var adapter = RecordingAdapter.new()
	for raw_binding in set.role_bindings.values():
		adapter.animation_bindings.append(str(raw_binding))
	adapter.rig_bindings = ["bone:%s" % root_target, "socket:%s" % hand_target]
	return adapter


static func _has_fragment(values: Array, fragment: String) -> bool:
	for value in values:
		if str(value).contains(fragment):
			return true
	return false


static func _expect_true(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)


static func _expect_equal(
	failures: Array[String],
	label: String,
	actual: Variant,
	expected: Variant
) -> void:
	if actual != expected:
		failures.append("%s — expected %s, got %s" % [label, str(expected), str(actual)])
