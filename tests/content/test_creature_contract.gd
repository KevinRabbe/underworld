extends RefCounted

const ContentDefinition := preload("res://core/content/registry/content_definition.gd")
const CategorySchema := preload("res://core/content/schema/category_schema.gd")
const CategorySchemaRegistry := preload("res://core/content/schema/category_schema_registry.gd")
const CapabilitySchema := preload("res://core/content/schema/capability_schema.gd")
const CapabilitySchemaRegistry := preload("res://core/content/schema/capability_schema_registry.gd")
const ContentValidationPipeline := preload("res://core/content/validation/content_validation_pipeline.gd")
const CreatureDefinition := preload("res://gameplay/creatures/definitions/creature_definition.gd")
const CreatureAttackProfileDefinition := preload("res://gameplay/creatures/definitions/creature_attack_profile_definition.gd")
const CreatureFamilyValidator := preload("res://gameplay/creatures/validation/creature_family_validator.gd")
const EnemyScript := preload("res://gameplay/creatures/underworld/burrower/burrower.gd")
const ArchetypeDefinition := preload("res://core/content/archetypes/archetype_definition.gd")
const AnimationSetDefinition := preload("res://presentation/characters/animation/animation_set_definition.gd")
const RigProfileDefinition := preload("res://presentation/characters/animation/rig_profile_definition.gd")

const BURROWER_PATH := "res://content/characters/creatures/prototype_burrower_definition.tres"
const ATTACK_PROFILE_PATH := "res://content/characters/attacks/prototype_burrower_attack_profile.tres"
const ARCHETYPE_PATH := "res://content/characters/archetypes/prototype_burrower_archetype.tres"
const ANIMATION_SET_PATH := "res://content/characters/animation_sets/prototype_humanoid_animation_set.tres"
const RIG_PROFILE_PATH := "res://content/characters/rig_profiles/prototype_humanoid_rig_profile.tres"

const CREATURE_ROOT := "category.creature"
const ENEMY_CATEGORY := "category.creature.enemy"
const ENEMY_DESCENDANT_CATEGORY := "category.creature.enemy.elite"
const ORTHOGONAL_CATEGORY := "category.environment.cave"
const MOVEMENT := "capability.movement"
const SENSING := "capability.sensing"
const DAMAGE_DEALER := "capability.damage_dealer"

const ATTACK_ID := "attack_profile.creature.burrower.melee"
const ARCHETYPE_ID := "archetype.creature.burrower.prototype"
const ANIMATION_SET_ID := "animation_set.humanoid.prototype"
const RIG_PROFILE_ID := "rig_profile.humanoid.prototype"


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_burrower_authored_baseline(failures)
	_test_noncombat_creature_stays_generic(failures)
	_test_enemy_descendant_requires_capabilities(failures)
	_test_wrong_concrete_types_fail_closed(failures)
	_test_invalid_semantic_bindings_fail(failures)
	_test_two_creatures_reuse_same_boundary(failures)
	_test_runtime_and_encounter_state_stay_separate(failures)
	return failures


static func _test_burrower_authored_baseline(failures: Array[String]) -> void:
	var definitions: Array = _accepted_bundle()
	if definitions.is_empty():
		failures.append("Burrower authored definition bundle failed to load")
		return
	var burrower = definitions[0]
	if not burrower is CreatureDefinition:
		failures.append("Burrower fixture did not load as CreatureDefinition")
		return

	var result: Dictionary = _pipeline().validate_all(
		definitions,
		_categories(),
		_capabilities(),
		[_validator()]
	)
	if not bool(result.get("success", false)):
		failures.append("valid Burrower authored bundle failed CONTENT-005: %s" % [
			result.get("diagnostics", []),
		])

	_expect_equal(failures, "Burrower ContentId", burrower.content_id, "creature.enemy.burrower")
	_expect_equal(failures, "Burrower health", burrower.max_health, 36)
	_expect_close(failures, "Burrower move speed", burrower.move_speed, 3.3)
	_expect_close(failures, "Burrower detection range", burrower.detection_range, 16.0)
	_expect_close(failures, "Burrower attack range", burrower.attack_range, 1.80)
	_expect_equal(failures, "Burrower attack damage", burrower.attack_damage, 10)
	_expect_close(failures, "Burrower attack cooldown", burrower.attack_cooldown, 1.20)
	_expect_close(failures, "Burrower attack windup", burrower.attack_windup, 0.42)

	var runtime_stats: Dictionary = burrower.runtime_stats()
	_expect_equal(failures, "runtime stats health", runtime_stats.get("health"), 36)
	_expect_close(failures, "runtime stats move speed", float(runtime_stats.get("move_speed", 0.0)), 3.3)
	_expect_close(failures, "runtime stats detection", float(runtime_stats.get("detection_range", 0.0)), 16.0)
	_expect_close(failures, "runtime stats range", float(runtime_stats.get("attack_range", 0.0)), 1.80)
	_expect_equal(failures, "runtime stats damage", runtime_stats.get("attack_damage"), 10)
	_expect_close(failures, "runtime stats cooldown", float(runtime_stats.get("attack_cooldown", 0.0)), 1.20)
	_expect_close(failures, "runtime stats windup", float(runtime_stats.get("attack_windup", 0.0)), 0.42)


static func _test_noncombat_creature_stays_generic(failures: Array[String]) -> void:
	var passive = CreatureDefinition.new()
	passive.configure_creature(
		"creature.passive.contract_probe",
		"Passive Contract Probe",
		12,
		0.0,
		0.0,
		0.0,
		0,
		0.0,
		0.0,
		1
	)
	passive.configure_schema_declarations([CREATURE_ROOT, ORTHOGONAL_CATEGORY], [])
	passive.configure_semantic_bindings("", ARCHETYPE_ID, "", "", [], [])
	var definitions: Array = _shared_targets()
	definitions.push_front(passive)
	var result: Dictionary = _pipeline().validate_all(
		definitions,
		_categories(),
		_capabilities(),
		[_validator()]
	)
	if not bool(result.get("success", false)):
		failures.append(
			"generic non-combat creature or its orthogonal category was rejected: %s" % [
				result.get("diagnostics", []),
			]
		)

	var orthogonal_only = CreatureDefinition.new()
	orthogonal_only.configure_creature(
		"creature.passive.missing_creature_category",
		"Missing Creature Category",
		12,
		0.0,
		0.0,
		0.0,
		0,
		0.0,
		0.0,
		1
	)
	orthogonal_only.configure_schema_declarations([ORTHOGONAL_CATEGORY], [])
	orthogonal_only.configure_semantic_bindings("", ARCHETYPE_ID, "", "", [], [])
	var orthogonal_definitions: Array = _shared_targets()
	orthogonal_definitions.push_front(orthogonal_only)
	var orthogonal_result: Dictionary = _pipeline().validate_all(
		orthogonal_definitions,
		_categories(),
		_capabilities(),
		[_validator()]
	)
	if not _has_code_fragment(
		orthogonal_result,
		"family_rule",
		"at least one registered category under"
	):
		failures.append("creature with only an orthogonal category bypassed creature classification")


static func _test_enemy_descendant_requires_capabilities(failures: Array[String]) -> void:
	var descendant_enemy = CreatureDefinition.new()
	descendant_enemy.configure_creature(
		"creature.enemy.elite.descendant_probe",
		"Enemy Descendant Probe",
		20,
		0.0,
		0.0,
		0.0,
		0,
		0.0,
		0.0,
		1
	)
	descendant_enemy.configure_schema_declarations([ENEMY_DESCENDANT_CATEGORY], [])
	descendant_enemy.configure_semantic_bindings("", ARCHETYPE_ID, "", "", [], [])
	var definitions: Array = _shared_targets()
	definitions.push_front(descendant_enemy)
	var result: Dictionary = _pipeline().validate_all(
		definitions,
		_categories(),
		_capabilities(),
		[_validator()]
	)
	for required_capability in [MOVEMENT, SENSING, DAMAGE_DEALER]:
		if not _has_code_fragment(result, "family_rule", required_capability):
			failures.append(
				"registered enemy descendant did not require capability: %s" % required_capability
			)


static func _test_wrong_concrete_types_fail_closed(failures: Array[String]) -> void:
	var wrong_creature = ContentDefinition.new()
	wrong_creature.configure("creature.enemy.generic_wrong_type", "creature", 1)
	wrong_creature.configure_schema_declarations([ENEMY_CATEGORY], [MOVEMENT, SENSING, DAMAGE_DEALER])
	var wrong_creature_result: Dictionary = _pipeline().validate_all(
		[wrong_creature],
		_categories(),
		_capabilities(),
		[_validator()]
	)
	if not _has_code_fragment(
		wrong_creature_result,
		"family_rule",
		"must inherit CreatureDefinition"
	):
		failures.append("generic ContentDefinition under semantic creature family bypassed rulebook")

	var wrong_attack = ContentDefinition.new()
	wrong_attack.configure("attack_profile.creature.generic_wrong_type", "attack_profile", 1)
	var creature = _creature("creature.enemy.wrong_attack_type")
	creature.attack_profile_id = wrong_attack.content_id
	var definitions: Array = _shared_targets()
	definitions.push_front(creature)
	definitions.append(wrong_attack)
	var wrong_attack_result: Dictionary = _pipeline().validate_all(
		definitions,
		_categories(),
		_capabilities(),
		[_validator()]
	)
	if not _has_code_fragment(
		wrong_attack_result,
		"family_rule",
		"must inherit CreatureAttackProfileDefinition"
	):
		failures.append("creature accepted a generic attack-profile family target")

	var wrong_archetype = ContentDefinition.new()
	wrong_archetype.configure("archetype.creature.generic_wrong_type", "archetype", 1)
	var archetype_creature = _creature("creature.enemy.wrong_archetype_type")
	archetype_creature.archetype_id = wrong_archetype.content_id
	var archetype_definitions: Array = _shared_targets()
	archetype_definitions.push_front(archetype_creature)
	archetype_definitions.append(wrong_archetype)
	var wrong_archetype_result: Dictionary = _pipeline().validate_all(
		archetype_definitions,
		_categories(),
		_capabilities(),
		[_validator()]
	)
	if not _has_code_fragment(
		wrong_archetype_result,
		"family_rule",
		"must inherit accepted ArchetypeDefinition"
	):
		failures.append("creature accepted a generic archetype-family presentation target")


static func _test_invalid_semantic_bindings_fail(failures: Array[String]) -> void:
	var missing_attack = _creature("creature.enemy.missing_attack")
	missing_attack.attack_profile_id = "attack_profile.creature.missing"
	var missing_definitions: Array = _shared_targets()
	missing_definitions.push_front(missing_attack)
	var missing_result: Dictionary = _pipeline().validate_all(
		missing_definitions,
		_categories(),
		_capabilities(),
		[_validator()]
	)
	if not _has_code_fragment(missing_result, "reference_resolution", "missing content definition"):
		failures.append("missing creature attack reference did not fail through CONTENT-005")

	var invalid_rig_role = _creature("creature.enemy.invalid_rig_role")
	invalid_rig_role.required_rig_role_ids.clear()
	invalid_rig_role.required_rig_role_ids.append("rig_role.socket.nonexistent")
	var invalid_rig_definitions: Array = _shared_targets()
	invalid_rig_definitions.push_front(invalid_rig_role)
	var invalid_rig_result: Dictionary = _pipeline().validate_all(
		invalid_rig_definitions,
		_categories(),
		_capabilities(),
		[_validator()]
	)
	if not _has_code_fragment(invalid_rig_result, "family_rule", "does not satisfy required role"):
		failures.append("creature accepted a rig role not provided by selected rig profile")

	var missing_sensing = _creature("creature.enemy.missing_sensing")
	missing_sensing.configure_schema_declarations([ENEMY_CATEGORY], [MOVEMENT, DAMAGE_DEALER])
	var missing_sensing_definitions: Array = _shared_targets()
	missing_sensing_definitions.push_front(missing_sensing)
	var missing_sensing_result: Dictionary = _pipeline().validate_all(
		missing_sensing_definitions,
		_categories(),
		_capabilities(),
		[_validator()]
	)
	if not _has_code_fragment(missing_sensing_result, "family_rule", SENSING):
		failures.append("creature with sensing tuning but no sensing capability did not fail closed")

	var missing_damage_dealer = _creature("creature.enemy.missing_damage_dealer")
	missing_damage_dealer.configure_schema_declarations([ENEMY_CATEGORY], [MOVEMENT, SENSING])
	var missing_damage_definitions: Array = _shared_targets()
	missing_damage_definitions.push_front(missing_damage_dealer)
	var missing_damage_result: Dictionary = _pipeline().validate_all(
		missing_damage_definitions,
		_categories(),
		_capabilities(),
		[_validator()]
	)
	if not _has_code_fragment(missing_damage_result, "family_rule", DAMAGE_DEALER):
		failures.append("creature with attack tuning/reference but no damage-dealer capability did not fail closed")


static func _test_two_creatures_reuse_same_boundary(failures: Array[String]) -> void:
	var first = _creature("creature.enemy.first_probe")
	var second = _creature("creature.enemy.second_probe")
	second.max_health = 52
	second.move_speed = 4.1
	second.attack_damage = 14
	var definitions: Array = _shared_targets()
	definitions.push_front(second)
	definitions.push_front(first)
	var result: Dictionary = _pipeline().validate_all(
		definitions,
		_categories(),
		_capabilities(),
		[_validator()]
	)
	if not bool(result.get("success", false)):
		failures.append("two compatible creature definitions did not reuse one generic boundary: %s" % [
			result.get("diagnostics", []),
		])
	if first.runtime_stats() == second.runtime_stats():
		failures.append("two compatible creature definitions did not retain independent authored tuning")
	if first.get_script() != second.get_script():
		failures.append("second creature proof bypassed the shared CreatureDefinition boundary")

	var first_actor = EnemyScript.new()
	var second_actor = EnemyScript.new()
	first_actor.configure("first_probe", null, Vector3.ZERO, first.runtime_stats())
	second_actor.configure("second_probe", null, Vector3.ZERO, second.runtime_stats())
	_expect_equal(failures, "first generic actor health", first_actor.max_health, first.max_health)
	_expect_equal(failures, "second generic actor health", second_actor.max_health, second.max_health)
	_expect_close(failures, "first generic actor move speed", first_actor.move_speed, first.move_speed)
	_expect_close(failures, "second generic actor move speed", second_actor.move_speed, second.move_speed)
	_expect_equal(failures, "first generic actor attack damage", first_actor.attack_damage, first.attack_damage)
	_expect_equal(failures, "second generic actor attack damage", second_actor.attack_damage, second.attack_damage)
	first_actor.free()
	second_actor.free()


static func _test_runtime_and_encounter_state_stay_separate(failures: Array[String]) -> void:
	var creature = _creature("creature.enemy.state_separation")
	for forbidden_property in [
		"health",
		"target",
		"home_position",
		"velocity",
		"attack_timer",
		"attack_windup_timer",
		"wander_timer",
		"wander_target",
		"dead",
		"target_enemy_count",
		"spawn_min_distance",
		"spawn_max_distance",
		"spawn_interval",
		"release_distance",
	]:
		if _has_property(creature, forbidden_property):
			failures.append("runtime/encounter field leaked into CreatureDefinition: %s" % forbidden_property)

	var stable_id: String = creature.content_id
	creature.archetype_id = "archetype.creature.replacement.presentation"
	creature.animation_set_id = "animation_set.creature.replacement.presentation"
	if creature.content_id != stable_id:
		failures.append("replaceable creature presentation binding changed semantic creature identity")
	if creature.canonical_descriptor().has("resource_path"):
		failures.append("CreatureDefinition canonical identity leaked physical resource path")


static func _accepted_bundle() -> Array:
	var burrower = ResourceLoader.load(BURROWER_PATH)
	var shared: Array = _shared_targets()
	if burrower == null or shared.is_empty():
		return []
	shared.push_front(burrower)
	return shared


static func _shared_targets() -> Array:
	var attack_profile = ResourceLoader.load(ATTACK_PROFILE_PATH)
	var archetype = ResourceLoader.load(ARCHETYPE_PATH)
	var animation_set = ResourceLoader.load(ANIMATION_SET_PATH)
	var rig_profile = ResourceLoader.load(RIG_PROFILE_PATH)
	if (
		attack_profile == null
		or not attack_profile is CreatureAttackProfileDefinition
		or archetype == null
		or not archetype is ArchetypeDefinition
		or animation_set == null
		or not animation_set is AnimationSetDefinition
		or rig_profile == null
		or not rig_profile is RigProfileDefinition
	):
		return []
	return [attack_profile, archetype, animation_set, rig_profile]


static func _creature(content_id: String):
	var creature = CreatureDefinition.new()
	creature.configure_creature(content_id, "Contract Probe", 30, 3.0, 12.0, 1.7, 8, 1.1, 0.35, 1)
	creature.configure_schema_declarations([ENEMY_CATEGORY], [MOVEMENT, SENSING, DAMAGE_DEALER])
	creature.configure_semantic_bindings(
		ATTACK_ID,
		ARCHETYPE_ID,
		ANIMATION_SET_ID,
		RIG_PROFILE_ID,
		["animation_role.locomotion.idle", "animation_role.action.attack.light_01"],
		["rig_role.root", "rig_role.head"]
	)
	return creature


static func _validator():
	return CreatureFamilyValidator.new().configure_creature_rules()


static func _pipeline():
	return ContentValidationPipeline.new()


static func _categories():
	var registry = CategorySchemaRegistry.new()
	var diagnostics: Array[String] = registry.index_schemas([
		CategorySchema.new().configure(CREATURE_ROOT),
		CategorySchema.new().configure(ENEMY_CATEGORY, [CREATURE_ROOT]),
		CategorySchema.new().configure(ENEMY_DESCENDANT_CATEGORY, [ENEMY_CATEGORY]),
		CategorySchema.new().configure(ORTHOGONAL_CATEGORY),
	])
	assert(diagnostics.is_empty())
	return registry


static func _capabilities():
	var registry = CapabilitySchemaRegistry.new()
	var diagnostics: Array[String] = registry.index_schemas([
		CapabilitySchema.new().configure(MOVEMENT),
		CapabilitySchema.new().configure(SENSING),
		CapabilitySchema.new().configure(DAMAGE_DEALER),
	])
	assert(diagnostics.is_empty())
	return registry


static func _has_property(value, property_name: String) -> bool:
	for descriptor in value.get_property_list():
		if str(descriptor.get("name", "")) == property_name:
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


static func _expect_equal(
	failures: Array[String],
	label: String,
	actual: Variant,
	expected: Variant
) -> void:
	if actual != expected:
		failures.append("%s — expected %s, got %s" % [label, str(expected), str(actual)])


static func _expect_close(
	failures: Array[String],
	label: String,
	actual: float,
	expected: float
) -> void:
	if not is_equal_approx(actual, expected):
		failures.append("%s — expected %.4f, got %.4f" % [label, expected, actual])
