extends RefCounted

const ContentDefinition := preload("res://core/content/registry/content_definition.gd")
const CategorySchema := preload("res://core/content/schema/category_schema.gd")
const CategorySchemaRegistry := preload("res://core/content/schema/category_schema_registry.gd")
const CapabilitySchema := preload("res://core/content/schema/capability_schema.gd")
const CapabilitySchemaRegistry := preload("res://core/content/schema/capability_schema_registry.gd")
const ContentValidationPipeline := preload("res://core/content/validation/content_validation_pipeline.gd")
const ItemDefinition := preload("res://gameplay/items/definitions/item_definition.gd")
const ItemFamilyValidator := preload("res://gameplay/items/validation/item_family_validator.gd")
const WeaponDefinition := preload("res://gameplay/items/definitions/weapon_definition.gd")
const WeaponRuleExtension := preload("res://gameplay/items/validation/weapon_rule_extension.gd")
const WeaponAttackAdapter := preload("res://gameplay/items/weapon_attack_adapter.gd")
const AttackCatalog := preload("res://gameplay/combat/attacks/player_attack_catalog.gd")
const Stamina := preload("res://gameplay/player/components/stamina_component.gd")
const PlayerActionController := preload("res://gameplay/player/actions/player_action_controller.gd")
const CharacterSemanticSchemaCatalog := preload("res://presentation/characters/animation/character_semantic_schema_catalog.gd")

const SWORD_PATH := "res://content/items/weapons/prototype_sword.tres"
const ITEM_ROOT := "category.item"
const ITEM_EQUIPMENT := "category.item.equipment"
const ITEM_WEAPON := "category.item.equipment.weapon"
const ITEM_WEAPON_MELEE := "category.item.equipment.weapon.melee"
const ITEM_WEAPON_SWORD := "category.item.equipment.weapon.melee.sword"
const DAMAGE_DEALER := "capability.damage_dealer"
const SWORD_ARCHETYPE := "archetype.weapon.prototype_sword"


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_authored_sword_child_contract(failures)
	_test_wrong_concrete_weapon_type_fails_closed(failures)
	_test_attack_profile_resolution(failures)
	_test_semantic_role_validation(failures)
	_test_presentation_binding_does_not_own_identity(failures)
	_test_player_action_controller_keeps_timing_authority(failures)
	_test_legacy_tool_profiles_remain_compatible(failures)
	return failures


static func _test_authored_sword_child_contract(failures: Array[String]) -> void:
	var sword = ResourceLoader.load(SWORD_PATH)
	if sword == null or not sword is WeaponDefinition:
		failures.append("authored prototype sword did not load as WeaponDefinition")
		return
	if not sword is ItemDefinition:
		failures.append("WeaponDefinition is not ItemDefinition-compatible")
		return

	var result: Dictionary = _pipeline().validate_all(
		[sword, _content_definition(SWORD_ARCHETYPE, "archetype")],
		_categories(),
		_capabilities(),
		[_weapon_validator()]
	)
	if not bool(result.get("success", false)):
		failures.append("valid authored prototype sword failed weapon/item validation: %s" % [result.get("diagnostics", [])])
	if sword.content_id != "item.weapon.prototype_sword":
		failures.append("prototype sword semantic ContentId was not preserved")
	if sword.stack_limit != 1:
		failures.append("weapon child definition did not preserve ItemDefinition stack contract")

	var attack = WeaponAttackAdapter.resolve_light_attack(sword)
	if attack == null or not bool(attack.call("is_valid")):
		failures.append("prototype sword did not resolve a valid attack through generic weapon adapter")
	elif StringName(attack.attack_id) != &"standard_blade_light":
		failures.append("prototype sword resolved the wrong semantic attack profile")

	var binding: Dictionary = WeaponAttackAdapter.presentation_binding(sword)
	if str(binding.get("archetype_id", "")) != SWORD_ARCHETYPE:
		failures.append("prototype sword presentation archetype did not pass through semantic binding")
	if str(binding.get("animation_role", "")) != "animation_role.action.attack.light_01":
		failures.append("prototype sword animation binding did not use semantic animation role")
	if str(binding.get("grip_rig_role", "")) != "rig_role.socket.hand.right":
		failures.append("prototype sword grip binding did not use semantic rig socket role")


static func _test_wrong_concrete_weapon_type_fails_closed(failures: Array[String]) -> void:
	var impostor = ItemDefinition.new()
	impostor.configure_item("item.weapon.impostor", 1, 1.0, 1)
	impostor.configure_schema_declarations([ITEM_WEAPON_SWORD], [DAMAGE_DEALER])
	var result: Dictionary = _pipeline().validate_all(
		[impostor],
		_categories(),
		_capabilities(),
		[_weapon_validator()]
	)
	if not _has_code_fragment(result, "family_rule", "must inherit WeaponDefinition"):
		failures.append("weapon-category ItemDefinition bypassed the WeaponDefinition child boundary")


static func _test_attack_profile_resolution(failures: Array[String]) -> void:
	var first = _weapon(
		"item.weapon.first_probe",
		AttackCatalog.PROFILE_STANDARD_BLADE_LIGHT,
		"archetype.weapon.first_probe"
	)
	var second = _weapon(
		"item.weapon.second_probe",
		AttackCatalog.PROFILE_STONE_AXE_LIGHT,
		"archetype.weapon.second_probe"
	)
	var first_attack = WeaponAttackAdapter.resolve_light_attack(first)
	var second_attack = WeaponAttackAdapter.resolve_light_attack(second)
	if first_attack == null or second_attack == null:
		failures.append("compatible weapon definitions did not resolve through the same generic attack adapter")
	else:
		if first_attack.attack_id == second_attack.attack_id:
			failures.append("two weapon definitions could not select different semantic attack profiles")
		if int(first_attack.damage) == int(second_attack.damage):
			failures.append("distinct semantic attack profiles unexpectedly collapsed to identical damage contracts")

	var first_binding: Dictionary = WeaponAttackAdapter.presentation_binding(first)
	var second_binding: Dictionary = WeaponAttackAdapter.presentation_binding(second)
	if first_binding.get("archetype_id") == second_binding.get("archetype_id"):
		failures.append("generic weapon path could not carry different presentation bindings")

	var missing = _weapon(
		"item.weapon.missing_profile",
		"attack_profile.player.missing_light",
		"archetype.weapon.missing_profile"
	)
	if WeaponAttackAdapter.resolve_light_attack(missing) != null:
		failures.append("missing semantic weapon attack profile did not fail closed")
	var missing_result: Dictionary = _pipeline().validate_all(
		[missing, _content_definition("archetype.weapon.missing_profile", "archetype")],
		_categories(),
		_capabilities(),
		[_weapon_validator()]
	)
	if not _has_code_fragment(missing_result, "family_rule", "attack-definition boundary"):
		failures.append("missing weapon attack profile did not fail authored-content validation")

	var invalid = _weapon(
		"item.weapon.invalid_profile",
		"not a semantic profile",
		"archetype.weapon.invalid_profile"
	)
	var invalid_result: Dictionary = _pipeline().validate_all(
		[invalid, _content_definition("archetype.weapon.invalid_profile", "archetype")],
		_categories(),
		_capabilities(),
		[_weapon_validator()]
	)
	if not _has_code_fragment(invalid_result, "definition_invalid", "semantic attack_profile.* id"):
		failures.append("malformed weapon attack profile id did not fail definition validation")


static func _test_semantic_role_validation(failures: Array[String]) -> void:
	var unknown_animation = _weapon(
		"item.weapon.unknown_animation",
		AttackCatalog.PROFILE_STANDARD_BLADE_LIGHT,
		"archetype.weapon.unknown_animation"
	)
	unknown_animation.attack_animation_role = "animation_role.action.attack.unregistered"
	var animation_result: Dictionary = _pipeline().validate_all(
		[unknown_animation, _content_definition("archetype.weapon.unknown_animation", "archetype")],
		_categories(),
		_capabilities(),
		[_weapon_validator()]
	)
	if not _has_code_fragment(animation_result, "family_rule", "animation role is not registered"):
		failures.append("unregistered semantic weapon animation role did not fail closed")

	var invalid_socket = _weapon(
		"item.weapon.invalid_socket",
		AttackCatalog.PROFILE_STANDARD_BLADE_LIGHT,
		"archetype.weapon.invalid_socket"
	)
	invalid_socket.grip_rig_role = "rig_role.socket.weapon_primary"
	var socket_result: Dictionary = _pipeline().validate_all(
		[invalid_socket, _content_definition("archetype.weapon.invalid_socket", "archetype")],
		_categories(),
		_capabilities(),
		[_weapon_validator()]
	)
	if not _has_code_fragment(socket_result, "family_rule", "grip rig role is not registered"):
		failures.append("unregistered semantic weapon rig socket role did not fail closed")


static func _test_presentation_binding_does_not_own_identity(failures: Array[String]) -> void:
	var weapon = _weapon(
		"item.weapon.identity_probe",
		AttackCatalog.PROFILE_STANDARD_BLADE_LIGHT,
		"archetype.weapon.presentation_a"
	)
	var original_id: String = weapon.content_id
	var first_binding: Dictionary = WeaponAttackAdapter.presentation_binding(weapon)
	weapon.presentation_archetype_id = "archetype.weapon.presentation_b"
	var second_binding: Dictionary = WeaponAttackAdapter.presentation_binding(weapon)
	if weapon.content_id != original_id:
		failures.append("presentation binding mutation changed semantic weapon ContentId")
	if first_binding.get("archetype_id") == second_binding.get("archetype_id"):
		failures.append("presentation binding probe did not exercise a presentation-only change")


static func _test_player_action_controller_keeps_timing_authority(failures: Array[String]) -> void:
	var weapon = _weapon(
		"item.weapon.timing_probe",
		AttackCatalog.PROFILE_STANDARD_BLADE_LIGHT,
		"archetype.weapon.timing_probe"
	)
	var attack = WeaponAttackAdapter.resolve_light_attack(weapon)
	if attack == null:
		failures.append("timing-authority probe could not resolve weapon attack")
		return
	var stamina = Stamina.new()
	var actions = PlayerActionController.new(stamina)
	if not actions.try_start_attack(attack.startup, attack.active, attack.recovery):
		failures.append("PlayerActionController rejected valid weapon attack timings")
		return
	if actions.get_attack_phase_name() != "STARTUP":
		failures.append("PlayerActionController did not own weapon attack STARTUP phase")
	actions.tick(maxf(attack.startup - 0.001, 0.0))
	if actions.get_attack_phase_name() != "STARTUP":
		failures.append("weapon definition bypassed PlayerActionController startup timing")
	actions.tick(0.002)
	if actions.get_attack_phase_name() != "ACTIVE":
		failures.append("PlayerActionController did not transition weapon attack into ACTIVE phase")
	if not actions.consume_attack_activation():
		failures.append("PlayerActionController did not own weapon active-frame activation")


static func _test_legacy_tool_profiles_remain_compatible(failures: Array[String]) -> void:
	var hands = AttackCatalog.for_tool("hands")
	var axe = AttackCatalog.for_tool("stone_axe")
	var pickaxe = AttackCatalog.for_tool("stone_pickaxe")
	if hands == null or int(hands.damage) != 7 or hands.attack_id != &"hands_light":
		failures.append("hands compatibility attack changed during weapon-profile generalization")
	if axe == null or int(axe.damage) != 16 or axe.attack_id != &"stone_axe_light":
		failures.append("stone axe compatibility attack changed during weapon-profile generalization")
	if pickaxe == null or int(pickaxe.damage) != 13 or pickaxe.attack_id != &"stone_pickaxe_light":
		failures.append("stone pickaxe compatibility attack changed during weapon-profile generalization")


static func _weapon(content_id: String, profile_id: String, archetype_id: String):
	var weapon = WeaponDefinition.new()
	weapon.configure_weapon(
		content_id,
		profile_id,
		archetype_id,
		"animation_role.action.attack.light_01",
		"rig_role.socket.hand.right",
		"one_handed",
		2.0,
		1
	)
	weapon.configure_schema_declarations([ITEM_WEAPON_SWORD], [DAMAGE_DEALER])
	return weapon


static func _weapon_validator():
	var extension = WeaponRuleExtension.new()
	extension.configure_weapon_rules(CharacterSemanticSchemaCatalog.build_registry())
	var validator = ItemFamilyValidator.new()
	validator.configure_item_rules([extension])
	return validator


static func _pipeline():
	return ContentValidationPipeline.new()


static func _categories():
	var registry = CategorySchemaRegistry.new()
	var diagnostics: Array[String] = registry.index_schemas([
		CategorySchema.new().configure(ITEM_ROOT),
		CategorySchema.new().configure(ITEM_EQUIPMENT, [ITEM_ROOT]),
		CategorySchema.new().configure(ITEM_WEAPON, [ITEM_EQUIPMENT]),
		CategorySchema.new().configure(ITEM_WEAPON_MELEE, [ITEM_WEAPON]),
		CategorySchema.new().configure(ITEM_WEAPON_SWORD, [ITEM_WEAPON_MELEE]),
	])
	assert(diagnostics.is_empty())
	return registry


static func _capabilities():
	var registry = CapabilitySchemaRegistry.new()
	var diagnostics: Array[String] = registry.index_schemas([
		CapabilitySchema.new().configure(DAMAGE_DEALER),
	])
	assert(diagnostics.is_empty())
	return registry


static func _content_definition(content_id: String, family: String):
	var definition = ContentDefinition.new()
	definition.configure(content_id, family, 1)
	return definition


static func _has_code_fragment(result: Dictionary, code: String, fragment: String) -> bool:
	for diagnostic in result.get("diagnostics", []):
		if (
			str(diagnostic.get("code", "")) == code
			and str(diagnostic.get("message", "")).contains(fragment)
		):
			return true
	return false
