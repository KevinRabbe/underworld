extends RefCounted

const ContentRegistry := preload("res://core/content/registry/content_registry.gd")
const LootRewardService := preload("res://gameplay/loot/runtime/loot_reward_service.gd")
const EncounterController := preload("res://gameplay/creatures/spawning/prototype_burrower_encounter_controller.gd")

const BURROWER_PATH := "res://content/characters/creatures/prototype_burrower_definition.tres"
const LOOT_PROFILE_PATH := "res://content/loot/profiles/prototype_burrower_reward_profile.tres"
const CHITIN_PATH := "res://content/items/resources/burrower_chitin_definition.tres"


static func run() -> Array[String]:
	var failures: Array[String] = []
	var registry = ContentRegistry.new()
	failures.append_array(registry.index_definitions([
		ResourceLoader.load(BURROWER_PATH),
		ResourceLoader.load(LOOT_PROFILE_PATH),
		ResourceLoader.load(CHITIN_PATH),
	]))
	if not failures.is_empty():
		return failures

	var source = LootRewardService.new()
	var issued: Dictionary = source.issue_for_creature(
		"burrower_12",
		ResourceLoader.load(BURROWER_PATH),
		ResourceLoader.load(LOOT_PROFILE_PATH),
		registry
	)
	if not bool(issued.get("success", false)):
		failures.append("restore probe source issuance failed")
		return failures

	var restored_state = source.pending_state("burrower_12")
	var controller = EncounterController.new()
	controller.configure(null, null, null)
	var import_result: Dictionary = controller.import_pending_loot_states([
		restored_state
	], Vector3(14.0, 2.0, -6.0))
	if not bool(import_result.get("success", false)):
		failures.append("restore probe import failed: %s" % [import_result.get("diagnostics", [])])
	controller.free()
	return failures
