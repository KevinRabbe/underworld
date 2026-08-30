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
	var issuance_events: Array = []
	controller.loot_pending.connect(func(occurrence_id, profile_id, world_position):
		issuance_events.append([occurrence_id, profile_id, world_position])
	)
	var anchor := Vector3(14.0, 2.0, -6.0)
	var import_result: Dictionary = controller.import_pending_loot_states([restored_state], anchor)
	if not bool(import_result.get("success", false)):
		failures.append("restore probe import failed")
	if not issuance_events.is_empty():
		failures.append("restore probe replayed issuance")
	if controller.get_pending_loot_locator("burrower_12") != anchor:
		failures.append("restore probe locator mismatch")
	if controller.spawn_serial != 12:
		failures.append("restore probe allocator state mismatch")
	if int(import_result.get("next_spawn_serial", -1)) != 13:
		failures.append("restore probe next allocator mismatch")
	controller.free()
	return failures
