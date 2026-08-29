extends RefCounted

const ContentDefinition := preload("res://core/content/registry/content_definition.gd")
const CategorySchema := preload("res://core/content/schema/category_schema.gd")
const CategorySchemaRegistry := preload("res://core/content/schema/category_schema_registry.gd")
const CapabilitySchema := preload("res://core/content/schema/capability_schema.gd")
const CapabilitySchemaRegistry := preload("res://core/content/schema/capability_schema_registry.gd")
const ContentValidationPipeline := preload("res://core/content/validation/content_validation_pipeline.gd")
const ArchetypeDefinition := preload("res://core/content/archetypes/archetype_definition.gd")
const ArchetypeComposition := preload("res://core/content/archetypes/archetype_composition.gd")
const ItemDefinition := preload("res://gameplay/items/definitions/item_definition.gd")
const ItemFamilyValidator := preload("res://gameplay/items/validation/item_family_validator.gd")
const WeaponDefinition := preload("res://gameplay/items/weapons/definitions/weapon_definition.gd")
const WeaponAttackSetDefinition := preload("res://gameplay/items/weapons/definitions/weapon_attack_set_definition.gd")
const WeaponAttackResolver := preload("res://gameplay/items/weapons/runtime/weapon_attack_resolver.gd")
const WeaponItemRuleExtension := preload("res://gameplay/items/weapons/validation/weapon_item_rule_extension.gd")
const PlayerAttackDefinition := preload("res://gameplay/combat/attacks/player_attack_definition.gd")
const AnimationSetDefinition := preload("res://presentation/characters/animation/animation_set_definition.gd")
const RigProfileDefinition := preload("res://presentation/characters/animation/rig_profile_definition.gd")
const CharacterSemanticSchemaCatalog := preload("res://presentation/characters/animation/character_semantic_schema_catalog.gd")

const WEAPON_PATH_A := "res://tests/fixtures/content/weapon_path_a/iron_sword.tres"
const WEAPON_PATH_B := "res://tests/fixtures/content/weapon_path_b/renamed_iron_sword_definition.tres"

const ITEM_ROOT := "category.item"
const ITEM_EQUIPMENT := "category.item.equipment"
const ITEM_WEAPON := "category.item.equipment.weapon"
const ITEM_WEAPON_MELEE := "category.item.equipment.weapon.melee"
const ITEM_SWORD := "category.item.equipment.weapon.melee.sword"
const ITEM_AXE := "category.item.equipment.weapon.melee.axe"
const ITEM_TOOL := "category.item.equipment.tool"

const EQUIPABLE := "capability.equipable"
const DAMAGE_DEALER := "capability.damage_dealer"
const HARVEST_TOOL := "capability.harvest_tool"

const ATTACK_ROLE := "animation_role.action.attack.light_01"
const RIGHT_GRIP := "rig_role.socket.hand.right"
const LIGHT_TECHNIQUE := "weapon_technique.light.primary"

const SWORD_ATTACK_SET := "attack_set.weapon.sword.basic"
const SWORD_ARCHETYPE := "archetype.weapon.iron_sword"


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_authored_sword_and_path_identity(failures)
	_test_attack_resolution_preserves_gameplay_authority(failures)
	_test_weapon_and_tool_capability_composition(failures)
	_test_weapon_family_fails_closed(failures)
	_test_semantic_role_requirements_fail_closed(failures)
	_test_character_presentation_pack_replaceability(failures)
	return failures


static func _test_authored_sword_and_path_identity(failures: Array[String]) -> void:
	var first = ResourceLoader.load(WEAPON_PATH_A)
	var moved = ResourceLoader.load(WEAPON_PATH_B)
	if (
		first == null
		or moved == null
		or not first is WeaponDefinition
		or not moved is WeaponDefinition
	):
		failures.append("authored weapon path fixtures did not load as WeaponDefinition resources")
		return

	for candidate in [first, moved]:
		candidate.configure_schema_declarations([ITEM_SWORD], [EQUIPABLE, DAMAGE_DEALER])
		var result: Dictionary = _validate_weapon(candidate, _sword_targets())
		if not bool(result.get("success", false)):
			failures.append("valid authored sword failed CONTENT-005 validation: %s" % [result.get("diagnostics", [])])

	if first.content_id != "item.weapon.iron_sword" or moved.content_id != first.content_id:
		failures.append("physical weapon file move changed semantic weapon identity")
	if str(first.resource_path) == str(moved.resource_path):
		failures.append("weapon path-independence proof did not use two physical paths")
	if first.canonical_descriptor() != moved.canonical_descriptor():
		failures.append("weapon canonical descriptor changed after physical file move")
	if first.stack_limit != 1 or not is_equal_approx(first.unit_weight, 3.0):
		failures.append("authored sword did not retain ITEM-001 base fields")

	if _has_property(first, "animation_set_id") or _has_property(first, "rig_profile_id"):
		failures.append("WeaponDefinition still owns a concrete character Animation Set or Rig Profile")
	var descriptor: Dictionary = first.canonical_descriptor()
	if descriptor.has("animation_set_id") or descriptor.has("rig_profile_id"):
		failures.append("weapon canonical identity still includes concrete character presentation-pack ids")
	if _has_reference_role(first, "presentation.animation_set") or _has_reference_role(first, "presentation.rig_profile"):
		failures.append("weapon validation references still select concrete character presentation definitions")

	var stable_id: String = first.content_id
	first.archetype_id = "archetype.weapon.iron_sword.presentation_replacement"
	if first.content_id != stable_id:
		failures.append("replaceable weapon presentation archetype changed semantic weapon identity")
	if _has_property(first, "startup") or _has_property(first, "active") or _has_property(first, "recovery"):
		failures.append("gameplay attack timing leaked into authored WeaponDefinition")
	if _has_property(first, "damage") or _has_property(first, "reach"):
		failures.append("combat-resolution fields leaked into authored WeaponDefinition")


static func _test_attack_resolution_preserves_gameplay_authority(failures: Array[String]) -> void:
	var sword = _weapon(
		"item.weapon.runtime_sword",
		SWORD_ATTACK_SET,
		SWORD_ARCHETYPE,
		ITEM_SWORD,
		[EQUIPABLE, DAMAGE_DEALER],
		RIGHT_GRIP
	)
	var attack_set = _attack_set(SWORD_ATTACK_SET, LIGHT_TECHNIQUE, "sword_light_01")
	var attack = PlayerAttackDefinition.new(
		&"sword_light_01",
		0.18,
		0.11,
		0.27,
		22,
		2.9,
		1.7,
		1.05,
		0.10
	)
	var before := [attack.startup, attack.active, attack.recovery, attack.damage, attack.reach]
	var resolver = WeaponAttackResolver.new()
	resolver.configure_attack_definitions([attack])
	if not resolver.is_valid():
		failures.append("valid gameplay-owned attack definition failed weapon resolver registration: %s" % [resolver.diagnostics()])
		return
	var resolved: Dictionary = resolver.resolve_primary_attack(sword, attack_set)
	if not resolved.get("diagnostics", []).is_empty():
		failures.append("semantic sword attack resolution failed: %s" % [resolved.get("diagnostics", [])])
		return
	if resolved.get("attack_definition", null) != attack:
		failures.append("weapon resolver copied/replaced gameplay-owned attack definition instead of returning it")
	var after := [attack.startup, attack.active, attack.recovery, attack.damage, attack.reach]
	if before != after:
		failures.append("weapon attack resolution mutated gameplay-owned timing/combat data")

	var second_set = _attack_set("attack_set.weapon.axe.basic", LIGHT_TECHNIQUE, "stone_axe_light")
	var axe_attack = PlayerAttackDefinition.new(
		&"stone_axe_light",
		0.12,
		0.10,
		0.20,
		16,
		2.8,
		1.65,
		1.05,
		0.10
	)
	resolver.configure_attack_definitions([attack, axe_attack])
	var axe = _weapon(
		"item.weapon.prototype_axe",
		second_set.content_id,
		"archetype.weapon.prototype_axe",
		ITEM_AXE,
		[EQUIPABLE, DAMAGE_DEALER, HARVEST_TOOL],
		RIGHT_GRIP
	)
	var axe_resolved: Dictionary = resolver.resolve_primary_attack(axe, second_set)
	if axe_resolved.get("attack_definition", null) != axe_attack:
		failures.append("second weapon did not select its semantic attack-set binding without a central switch")


static func _test_weapon_and_tool_capability_composition(failures: Array[String]) -> void:
	var axe = _weapon(
		"item.weapon.harvest_axe",
		"attack_set.weapon.axe.harvest",
		"archetype.weapon.harvest_axe",
		ITEM_AXE,
		[EQUIPABLE, DAMAGE_DEALER, HARVEST_TOOL],
		RIGHT_GRIP
	)
	var axe_targets: Array = [
		_attack_set(axe.attack_set_id, LIGHT_TECHNIQUE, "stone_axe_light"),
		_archetype(axe.archetype_id),
	]
	var axe_result: Dictionary = _validate_weapon(axe, axe_targets)
	if not bool(axe_result.get("success", false)):
		failures.append("weapon + harvest capability composition failed for axe: %s" % [axe_result.get("diagnostics", [])])

	var pickaxe = ItemDefinition.new()
	pickaxe.configure_item("item.tool.prototype_pickaxe_compat", 1, 2.0, 1)
	pickaxe.configure_schema_declarations([ITEM_TOOL], [HARVEST_TOOL, DAMAGE_DEALER])
	var pickaxe_result: Dictionary = ContentValidationPipeline.new().validate_all(
		[pickaxe],
		_categories(),
		_capabilities(),
		[_item_validator()]
	)
	if not bool(pickaxe_result.get("success", false)):
		failures.append("damage-capable harvest tool was incorrectly forced into WeaponDefinition: %s" % [pickaxe_result.get("diagnostics", [])])


static func _test_weapon_family_fails_closed(failures: Array[String]) -> void:
	var wrong_type = ItemDefinition.new()
	wrong_type.configure_item("item.weapon.invalid_base_definition", 1, 1.0, 1)
	wrong_type.configure_schema_declarations([ITEM_SWORD], [EQUIPABLE, DAMAGE_DEALER])
	var wrong_result: Dictionary = ContentValidationPipeline.new().validate_all(
		[wrong_type],
		_categories(),
		_capabilities(),
		[_item_validator()]
	)
	if not _has_code_fragment(wrong_result, "family_rule", "must inherit WeaponDefinition"):
		failures.append("base ItemDefinition under weapon category bypassed the weapon rulebook")

	var missing_capability = _weapon(
		"item.weapon.missing_damage_capability",
		SWORD_ATTACK_SET,
		SWORD_ARCHETYPE,
		ITEM_SWORD,
		[EQUIPABLE],
		RIGHT_GRIP
	)
	var missing_result: Dictionary = _validate_weapon(missing_capability, _sword_targets())
	if not _has_code_fragment(missing_result, "family_rule", DAMAGE_DEALER):
		failures.append("weapon without damage-dealer capability did not fail closed")

	var wrong_attack_target = _weapon(
		"item.weapon.generic_attack_set_target",
		"attack_set.weapon.generic_wrong_type",
		SWORD_ARCHETYPE,
		ITEM_SWORD,
		[EQUIPABLE, DAMAGE_DEALER],
		RIGHT_GRIP
	)
	var generic_attack_set = ContentDefinition.new()
	generic_attack_set.configure(wrong_attack_target.attack_set_id, "attack_set", 1)
	var wrong_targets: Array = [generic_attack_set, _archetype(SWORD_ARCHETYPE)]
	var wrong_target_result: Dictionary = _validate_weapon(wrong_attack_target, wrong_targets)
	if not _has_code_fragment(wrong_target_result, "family_rule", "must inherit WeaponAttackSetDefinition"):
		failures.append("generic attack_set content bypassed the weapon attack-set contract")

	var missing_technique = _weapon(
		"item.weapon.missing_technique",
		"attack_set.weapon.missing_technique",
		SWORD_ARCHETYPE,
		ITEM_SWORD,
		[EQUIPABLE, DAMAGE_DEALER],
		RIGHT_GRIP
	)
	var alternate_set = _attack_set(
		missing_technique.attack_set_id,
		"weapon_technique.heavy.primary",
		"sword_heavy_01"
	)
	var alternate_targets: Array = [alternate_set, _archetype(SWORD_ARCHETYPE)]
	var missing_technique_result: Dictionary = _validate_weapon(missing_technique, alternate_targets)
	if not _has_code_fragment(missing_technique_result, "family_rule", "does not provide primary technique role"):
		failures.append("weapon attack set missing the selected semantic technique did not fail")


static func _test_semantic_role_requirements_fail_closed(failures: Array[String]) -> void:
	var bad_grip = _weapon(
		"item.weapon.bad_grip",
		SWORD_ATTACK_SET,
		SWORD_ARCHETYPE,
		ITEM_SWORD,
		[EQUIPABLE, DAMAGE_DEALER],
		"rig_role.head"
	)
	var bad_grip_result: Dictionary = _validate_weapon(bad_grip, _sword_targets())
	if not _has_code_fragment(bad_grip_result, "family_rule", "must be a hand socket"):
		failures.append("weapon grip accepted a non-hand rig role")

	var unknown_animation = _weapon(
		"item.weapon.unknown_animation_role",
		SWORD_ATTACK_SET,
		SWORD_ARCHETYPE,
		ITEM_SWORD,
		[EQUIPABLE, DAMAGE_DEALER],
		RIGHT_GRIP
	)
	unknown_animation.attack_animation_role = "animation_role.action.attack.unknown"
	var unknown_result: Dictionary = _validate_weapon(unknown_animation, _sword_targets())
	if not _has_code_fragment(unknown_result, "family_rule", "unknown weapon attack animation role"):
		failures.append("unknown semantic weapon animation role did not fail")


static func _test_character_presentation_pack_replaceability(failures: Array[String]) -> void:
	var weapon = _weapon(
		"item.weapon.presentation_independent_sword",
		SWORD_ATTACK_SET,
		SWORD_ARCHETYPE,
		ITEM_SWORD,
		[EQUIPABLE, DAMAGE_DEALER],
		RIGHT_GRIP
	)
	var weapon_result: Dictionary = _validate_weapon(weapon, _sword_targets())
	if not bool(weapon_result.get("success", false)):
		failures.append("presentation-independent weapon failed its own authored validation: %s" % [weapon_result.get("diagnostics", [])])
		return

	var rig_a = _rig_profile(
		"rig_profile.humanoid.weapon_pack_a",
		RIGHT_GRIP,
		RigProfileDefinition.BINDING_KIND_SOCKET,
		"HandSocket_A"
	)
	var animation_a = _animation_set(
		"animation_set.character.weapon_pack_a",
		rig_a.content_id,
		ATTACK_ROLE,
		RIGHT_GRIP,
		"character_a.sword_light"
	)
	var rig_b = _rig_profile(
		"rig_profile.humanoid.weapon_pack_b",
		RIGHT_GRIP,
		RigProfileDefinition.BINDING_KIND_SOCKET,
		"HandSocket_B"
	)
	var animation_b = _animation_set(
		"animation_set.character.weapon_pack_b",
		rig_b.content_id,
		ATTACK_ROLE,
		RIGHT_GRIP,
		"character_b.sword_light"
	)

	if animation_a.content_id == animation_b.content_id or rig_a.content_id == rig_b.content_id:
		failures.append("presentation replaceability proof did not use two distinct character presentation packs")
	if (
		str(animation_a.resolve_role_binding(ATTACK_ROLE).get("binding", ""))
		== str(animation_b.resolve_role_binding(ATTACK_ROLE).get("binding", ""))
	):
		failures.append("presentation replaceability proof did not vary concrete animation bindings")
	if (
		str(rig_a.binding_for_role(RIGHT_GRIP).get("target", ""))
		== str(rig_b.binding_for_role(RIGHT_GRIP).get("target", ""))
	):
		failures.append("presentation replaceability proof did not vary concrete rig/socket bindings")

	var before_id: String = weapon.content_id
	var before_descriptor: Dictionary = weapon.canonical_descriptor().duplicate(true)
	for pack in [[animation_a, rig_a], [animation_b, rig_b]]:
		var compatibility_failures: Array[String] = _presentation_pack_failures(
			weapon,
			pack[0],
			pack[1]
		)
		if not compatibility_failures.is_empty():
			failures.append("compatible character presentation pack rejected weapon semantic requirements: %s" % [compatibility_failures])

	if weapon.content_id != before_id or weapon.canonical_descriptor() != before_descriptor:
		failures.append("consuming a different compatible character presentation pack mutated weapon identity")

	var attack_set = _attack_set(SWORD_ATTACK_SET, LIGHT_TECHNIQUE, "sword_light_01")
	var attack = PlayerAttackDefinition.new(
		&"sword_light_01",
		0.18,
		0.11,
		0.27,
		22,
		2.9,
		1.7,
		1.05,
		0.10
	)
	var timing_before := [attack.startup, attack.active, attack.recovery, attack.damage, attack.reach]
	var resolver = WeaponAttackResolver.new()
	resolver.configure_attack_definitions([attack])
	for _pack in [[animation_a, rig_a], [animation_b, rig_b]]:
		var resolved: Dictionary = resolver.resolve_primary_attack(weapon, attack_set)
		if resolved.get("attack_definition", null) != attack:
			failures.append("character presentation choice changed gameplay attack-definition identity")
	if timing_before != [attack.startup, attack.active, attack.recovery, attack.damage, attack.reach]:
		failures.append("character presentation choice changed gameplay attack timing/combat data")


static func _presentation_pack_failures(weapon, animation_set, rig_profile) -> Array[String]:
	var failures: Array[String] = []
	if animation_set == null or not animation_set is AnimationSetDefinition:
		failures.append("expected AnimationSetDefinition")
		return failures
	if rig_profile == null or not rig_profile is RigProfileDefinition:
		failures.append("expected RigProfileDefinition")
		return failures
	if str(animation_set.rig_profile_id) != str(rig_profile.content_id):
		failures.append("animation set does not target supplied rig profile")

	var role_registry = CharacterSemanticSchemaCatalog.build_registry()
	for failure in animation_set.validate_definition():
		failures.append("animation definition: %s" % failure)
	for failure in rig_profile.validate_definition():
		failures.append("rig definition: %s" % failure)
	for failure in animation_set.validate_semantic_contract(role_registry):
		failures.append("animation semantic contract: %s" % failure)
	for failure in rig_profile.validate_semantic_contract(role_registry):
		failures.append("rig semantic contract: %s" % failure)

	var animation_resolution: Dictionary = animation_set.resolve_role_binding(weapon.attack_animation_role)
	if not animation_resolution.get("diagnostics", []).is_empty():
		failures.append("animation pack cannot resolve weapon attack role")
	var grip_binding: Dictionary = rig_profile.binding_for_role(weapon.grip_rig_role)
	if grip_binding.is_empty():
		failures.append("rig pack cannot resolve weapon grip role")
	elif str(grip_binding.get("kind", "")) != RigProfileDefinition.BINDING_KIND_SOCKET:
		failures.append("rig pack resolves weapon grip role to a non-socket binding")
	return failures


static func _weapon(
	content_id: String,
	attack_set_id: String,
	archetype_id: String,
	category_id: String,
	capabilities: Array,
	grip_role: String
):
	var weapon = WeaponDefinition.new()
	weapon.configure_weapon(
		content_id,
		attack_set_id,
		archetype_id,
		LIGHT_TECHNIQUE,
		ATTACK_ROLE,
		grip_role,
		2.0,
		1
	)
	weapon.configure_schema_declarations([category_id], capabilities)
	return weapon


static func _sword_targets() -> Array:
	return [
		_attack_set(SWORD_ATTACK_SET, LIGHT_TECHNIQUE, "sword_light_01"),
		_archetype(SWORD_ARCHETYPE),
	]


static func _attack_set(content_id: String, technique_role: String, attack_id: String):
	var definition = WeaponAttackSetDefinition.new()
	definition.configure_attack_set(content_id, {technique_role: attack_id}, 1)
	return definition


static func _archetype(content_id: String):
	var composition = ArchetypeComposition.new()
	composition.configure("weapon.test_adapter", Curve.new(), ["weapon_visual"], [])
	var definition = ArchetypeDefinition.new()
	definition.configure_archetype(content_id, "archetype", composition, 1)
	return definition


static func _animation_set(
	content_id: String,
	rig_profile_id: String,
	animation_role: String,
	rig_role: String,
	binding: String = "weapon_attack_clip"
):
	var definition = AnimationSetDefinition.new()
	definition.configure_animation_set(content_id, rig_profile_id, 1)
	definition.set_role_binding(animation_role, binding)
	definition.configure_required_roles([animation_role], [rig_role])
	return definition


static func _rig_profile(
	content_id: String,
	rig_role: String,
	binding_kind: String = RigProfileDefinition.BINDING_KIND_SOCKET,
	target: String = "WeaponBinding"
):
	var definition = RigProfileDefinition.new()
	definition.configure_rig_profile(content_id, "humanoid", 1)
	definition.set_role_binding(rig_role, binding_kind, target)
	return definition


static func _validate_weapon(weapon, targets: Array) -> Dictionary:
	var definitions: Array = [weapon]
	definitions.append_array(targets)
	return ContentValidationPipeline.new().validate_all(
		definitions,
		_categories(),
		_capabilities(),
		[_item_validator()]
	)


static func _item_validator():
	var extension = WeaponItemRuleExtension.new()
	extension.configure_weapon_rules(CharacterSemanticSchemaCatalog.build_registry())
	var validator = ItemFamilyValidator.new()
	validator.configure_item_rules([extension])
	return validator


static func _categories():
	var registry = CategorySchemaRegistry.new()
	var diagnostics: Array[String] = registry.index_schemas([
		CategorySchema.new().configure(ITEM_ROOT),
		CategorySchema.new().configure(ITEM_EQUIPMENT, [ITEM_ROOT]),
		CategorySchema.new().configure(ITEM_WEAPON, [ITEM_EQUIPMENT]),
		CategorySchema.new().configure(ITEM_WEAPON_MELEE, [ITEM_WEAPON]),
		CategorySchema.new().configure(ITEM_SWORD, [ITEM_WEAPON_MELEE]),
		CategorySchema.new().configure(ITEM_AXE, [ITEM_WEAPON_MELEE]),
		CategorySchema.new().configure(ITEM_TOOL, [ITEM_EQUIPMENT]),
	])
	assert(diagnostics.is_empty())
	return registry


static func _capabilities():
	var registry = CapabilitySchemaRegistry.new()
	var diagnostics: Array[String] = registry.index_schemas([
		CapabilitySchema.new().configure(EQUIPABLE),
		CapabilitySchema.new().configure(DAMAGE_DEALER),
		CapabilitySchema.new().configure(HARVEST_TOOL),
	])
	assert(diagnostics.is_empty())
	return registry


static func _has_property(value, property_name: String) -> bool:
	for descriptor in value.get_property_list():
		if str(descriptor.get("name", "")) == property_name:
			return true
	return false


static func _has_reference_role(value, role: String) -> bool:
	for reference in value.validation_references():
		if reference != null and str(reference.role) == role:
			return true
	return false


static func _has_code_fragment(result: Dictionary, code: String, fragment: String) -> bool:
	for diagnostic in result.get("diagnostics", []):
		if (
			str(diagnostic.get("code", "")) == code
			and str(diagnostic.get("message", "")).contains(fragment)
		):
			return true
	return false