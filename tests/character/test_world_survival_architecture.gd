extends RefCounted

const SurvivalScript := preload("res://gameplay/survival/prototype_survival_controller.gd")
const STREAMER_PATH := "res://world/runtime/streaming/surface_chunk_streamer.gd"
const LEGACY_MANAGER_PATH := "res://world/chunk_manager.gd"
const APP_GAME_PATH := "res://app/game/game.gd"


class FakeSettings:
	extends RefCounted
	var world_seed: int = 987654321
	var world_object_update_interval: float = 0.15
	var pickup_collect_radius: float = 1.5
	var tree_hits_with_axe: int = 3
	var rock_hits_with_pickaxe: int = 4
	var tree_wood_yield: int = 4
	var rock_stone_yield: int = 3
	var stone_axe_wood_cost: int = 4
	var stone_axe_stone_cost: int = 3
	var stone_pickaxe_wood_cost: int = 3
	var stone_pickaxe_stone_cost: int = 4


class FakeWorld:
	extends RefCounted
	var destroyed: Dictionary = {}
	var pickup_queue: Array = []
	var destroy_calls: int = 0

	func load_destroyed_object_ids(object_ids: Array) -> void:
		destroyed.clear()
		for object_id_variant in object_ids:
			destroyed[str(object_id_variant)] = true

	func get_destroyed_object_ids() -> Array:
		var result: Array = destroyed.keys()
		result.sort()
		return result

	func get_destroyed_object_count() -> int:
		return destroyed.size()

	func is_world_object_destroyed(object_id: String) -> bool:
		return destroyed.has(object_id)

	func destroy_world_object(
		object_id: String,
		_object_type: String,
		_object_index: int,
		_object_chunk: Vector2i
	) -> bool:
		if destroyed.has(object_id):
			return false
		destroyed[object_id] = true
		destroy_calls += 1
		return true

	func collect_nearby_pickups(_position: Vector3, _radius: float) -> Array:
		var result: Array = pickup_queue.duplicate(true)
		pickup_queue.clear()
		for pickup_variant in result:
			var pickup: Dictionary = pickup_variant
			var object_id: String = str(pickup.get("object_id", ""))
			if not object_id.is_empty():
				destroyed[object_id] = true
		return result


static func run() -> Array[String]:
	var failures: Array[String] = []
	var settings = FakeSettings.new()
	var world = FakeWorld.new()
	var survival = SurvivalScript.new()

	_cleanup_test_save(settings.world_seed)
	survival.configure(world, settings)

	_expect_true(
		failures,
		"survival owns resource inventory",
		survival.has_method("get_resource_counts")
	)
	_expect_true(
		failures,
		"survival owns crafting",
		survival.has_method("request_craft")
	)
	_expect_true(
		failures,
		"survival does not own generated-world delta count",
		not survival.has_method("get_destroyed_object_count")
	)

	survival.gathered_wood = 10
	survival.gathered_stone = 10
	survival.request_craft("stone_axe")
	_expect_true(failures, "stone axe crafting moved intact", survival.has_tool("stone_axe"))
	_expect_equal(failures, "stone axe becomes selected", survival.get_selected_hotbar_slot(), 2)
	_expect_equal(failures, "stone axe crafting wood cost preserved", survival.get_resource_counts().x, 6)
	_expect_equal(failures, "stone axe crafting stone cost preserved", survival.get_resource_counts().y, 7)

	var streamer_source: String = FileAccess.get_file_as_string(STREAMER_PATH)
	_expect_true(failures, "surface streamer source is readable", not streamer_source.is_empty())
	_expect_true(
		failures,
		"streamer owns generated-world delta loading",
		"func load_destroyed_object_ids" in streamer_source
	)
	_expect_true(
		failures,
		"streamer owns generated-object destruction",
		"func destroy_world_object" in streamer_source
	)
	_expect_true(
		failures,
		"streamer owns spatial pickup extraction",
		"func collect_nearby_pickups" in streamer_source
	)
	_expect_true(
		failures,
		"streamer does not own crafting",
		not "func request_craft" in streamer_source
	)
	_expect_true(
		failures,
		"streamer does not own resource inventory",
		not "gathered_wood" in streamer_source and not "gathered_stone" in streamer_source
	)
	_expect_true(
		failures,
		"streamer does not own hotbar state",
		not "selected_hotbar_slot" in streamer_source
	)

	var app_source: String = FileAccess.get_file_as_string(APP_GAME_PATH)
	_expect_true(failures, "application composition source is readable", not app_source.is_empty())
	_expect_true(
		failures,
		"application composes canonical surface streamer",
		STREAMER_PATH in app_source
	)
	_expect_true(
		failures,
		"application composes prototype survival controller",
		"res://gameplay/survival/prototype_survival_controller.gd" in app_source
	)
	_expect_true(
		failures,
		"player harvesting routes to survival",
		"player.harvest_requested.connect(survival.try_harvest)" in app_source
	)
	_expect_true(
		failures,
		"player crafting routes to survival",
		"player.craft_requested.connect(survival.request_craft)" in app_source
	)
	_expect_true(
		failures,
		"legacy mixed chunk manager path is retired",
		not FileAccess.file_exists(LEGACY_MANAGER_PATH)
	)

	_cleanup_test_save(settings.world_seed)
	survival.free()
	return failures


static func _cleanup_test_save(world_seed: int) -> void:
	var path: String = "user://underworld_seed_%d.json" % world_seed
	if not FileAccess.file_exists(path):
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func _expect_true(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)


static func _expect_equal(failures: Array[String], label: String, actual, expected) -> void:
	if actual != expected:
		failures.append("%s: expected=%s actual=%s" % [label, expected, actual])
