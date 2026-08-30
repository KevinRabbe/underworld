extends RefCounted

const SurvivalScript := preload("res://gameplay/survival/prototype_survival_controller.gd")
const STREAMER_PATH := "res://world/runtime/streaming/surface_chunk_streamer.gd"
const WORLD_SETTINGS_PATH := "res://world/runtime/config/world_settings.gd"
const SURVIVAL_SETTINGS_PATH := "res://gameplay/survival/prototype_survival_settings.gd"
const WATER_SETTINGS_PATH := "res://presentation/world/environment/prototype_water_settings.gd"
const LEGACY_MANAGER_PATH := "res://world/chunk_manager.gd"
const LEGACY_DATA_SETTINGS_PATH := "res://" + "data/world_settings.gd"
const APP_GAME_PATH := "res://app/game/game.gd"
const SURVIVAL_PATH := "res://gameplay/survival/prototype_survival_controller.gd"
const INTEGRATED_SURVIVAL_PATH := "res://gameplay/survival/integrated_survival_controller.gd"
const GAMEPLAY_SAVE_CATALOG_PATH := "res://gameplay/persistence/gameplay_save_catalog.gd"
const TEST_WORLD_SEED: int = 987654321


class FakeSettings:
	extends RefCounted
	var pickup_collect_radius: float = 1.5
	var pickup_collect_interval: float = 0.15
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
	var pickup_candidates: Array = []
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

	func find_nearby_pickups(_position: Vector3, _radius: float) -> Array:
		var result: Array = []
		for pickup_variant in pickup_candidates:
			var pickup: Dictionary = pickup_variant
			if not destroyed.has(str(pickup.get("object_id", ""))):
				result.append(pickup.duplicate(true))
		return result


static func run() -> Array[String]:
	var failures: Array[String] = []
	var settings = FakeSettings.new()
	var world = FakeWorld.new()
	var survival = SurvivalScript.new()

	_cleanup_test_save(TEST_WORLD_SEED)
	survival.configure(world, settings, TEST_WORLD_SEED)

	_expect_true(failures, "survival exposes semantic inventory", survival.has_method("get_inventory_state"))
	_expect_true(failures, "survival exposes accepted equipment state", survival.has_method("get_equipment_state"))
	_expect_true(failures, "survival exposes resource compatibility view", survival.has_method("get_resource_counts"))
	_expect_true(failures, "survival preserves legacy craft entrypoint", survival.has_method("request_craft"))
	_expect_true(failures, "survival exposes recipe costs without leaking settings", survival.has_method("get_crafting_cost"))
	_expect_true(failures, "survival does not own generated-world delta count", not survival.has_method("get_destroyed_object_count"))
	_expect_true(failures, "survival reports prototype persistence retired", not survival.legacy_persistence_enabled())

	var wood = survival.get_item_definition("item.resource.wood")
	var stone = survival.get_item_definition("item.resource.stone")
	var wood_seed: Dictionary = survival.get_inventory_state().add_stack(wood, 10)
	var stone_seed: Dictionary = survival.get_inventory_state().add_stack(stone, 10)
	_expect_true(failures, "semantic wood test seed succeeds", bool(wood_seed.get("success", false)))
	_expect_true(failures, "semantic stone test seed succeeds", bool(stone_seed.get("success", false)))
	survival.request_craft("stone_axe")
	_expect_true(failures, "stone axe compatibility bridge creates semantic ownership", survival.has_tool("stone_axe"))
	_expect_equal(failures, "stone axe becomes selected through EQUIP", survival.get_selected_hotbar_slot(), 2)
	_expect_equal(failures, "stone axe crafting wood cost preserved", survival.get_resource_counts().x, 6)
	_expect_equal(failures, "stone axe crafting stone cost preserved", survival.get_resource_counts().y, 7)

	survival.gathered_wood = 999
	survival.has_stone_pickaxe = true
	_expect_equal(failures, "legacy wood mirror is derived, not authority", survival.get_resource_counts().x, 6)
	_expect_true(failures, "legacy tool boolean is derived, not authority", not survival.has_tool("stone_pickaxe"))

	var streamer_source: String = FileAccess.get_file_as_string(STREAMER_PATH)
	_expect_true(failures, "surface streamer source is readable", not streamer_source.is_empty())
	_expect_true(failures, "streamer owns generated-world delta loading", "func load_destroyed_object_ids" in streamer_source)
	_expect_true(failures, "streamer owns generated-object destruction", "func destroy_world_object" in streamer_source)
	_expect_true(failures, "streamer exposes non-mutating pickup discovery", "func find_nearby_pickups" in streamer_source)
	_expect_true(failures, "streamer retains legacy pickup compatibility seam", "func collect_nearby_pickups" in streamer_source)
	_expect_true(failures, "streamer does not own crafting", not "func request_craft" in streamer_source)
	_expect_true(failures, "streamer does not own resource inventory", not "gathered_wood" in streamer_source and not "gathered_stone" in streamer_source)
	_expect_true(failures, "streamer does not own hotbar state", not "selected_hotbar_slot" in streamer_source)

	var survival_source: String = FileAccess.get_file_as_string(SURVIVAL_PATH)
	_expect_true(failures, "survival source is readable", not survival_source.is_empty())
	_expect_true(failures, "harvest eligibility no longer compares stone-axe string", not "equipped_tool != \"stone_axe\"" in survival_source)
	_expect_true(failures, "harvest eligibility no longer compares stone-pickaxe string", not "equipped_tool != \"stone_pickaxe\"" in survival_source)
	_expect_true(failures, "harvest does not increment legacy wood counter", not "gathered_wood +=" in survival_source)
	_expect_true(failures, "harvest does not increment legacy stone counter", not "gathered_stone +=" in survival_source)
	_expect_true(failures, "surface collection uses non-mutating world query", "world.find_nearby_pickups" in survival_source)
	_expect_true(failures, "survival consumes shared durable gameplay catalog", GAMEPLAY_SAVE_CATALOG_PATH in survival_source)
	_expect_true(failures, "prototype survival no longer declares legacy load hook", not "func _load_state()" in survival_source)
	_expect_true(failures, "prototype survival no longer declares legacy save hook", not "func _save_state()" in survival_source)
	_expect_true(failures, "prototype survival contains no direct FileAccess authority", not "FileAccess" in survival_source)

	var integrated_survival_source: String = FileAccess.get_file_as_string(INTEGRATED_SURVIVAL_PATH)
	_expect_true(failures, "integrated survival adapter source is readable", not integrated_survival_source.is_empty())
	_expect_true(failures, "integrated survival preserves prototype gameplay behavior", "extends \"%s\"" % SURVIVAL_PATH in integrated_survival_source)
	_expect_true(failures, "integrated survival does not reintroduce legacy load hook", not "func _load_state()" in integrated_survival_source)
	_expect_true(failures, "integrated survival does not reintroduce legacy save hook", not "func _save_state()" in integrated_survival_source)
	_expect_true(failures, "integrated survival contains no direct FileAccess authority", not "FileAccess" in integrated_survival_source)

	var world_settings_source: String = FileAccess.get_file_as_string(WORLD_SETTINGS_PATH)
	var survival_settings_source: String = FileAccess.get_file_as_string(SURVIVAL_SETTINGS_PATH)
	var water_settings_source: String = FileAccess.get_file_as_string(WATER_SETTINGS_PATH)
	_expect_true(failures, "world runtime settings are canonical", not world_settings_source.is_empty())
	_expect_true(failures, "survival settings are canonical", not survival_settings_source.is_empty())
	_expect_true(failures, "water settings are canonical", not water_settings_source.is_empty())
	_expect_true(failures, "world settings do not own crafting", not "stone_axe_wood_cost" in world_settings_source)
	_expect_true(failures, "world settings do not own water presentation", not "water_plane_size" in world_settings_source)
	_expect_true(failures, "survival settings do not own streaming", not "load_radius" in survival_settings_source)
	_expect_true(failures, "water settings do not own gameplay", not "harvest_range" in water_settings_source)

	var app_source: String = FileAccess.get_file_as_string(APP_GAME_PATH)
	_expect_true(failures, "application composition source is readable", not app_source.is_empty())
	_expect_true(failures, "application composes canonical surface streamer", STREAMER_PATH in app_source)
	_expect_true(failures, "application composes integrated survival adapter", INTEGRATED_SURVIVAL_PATH in app_source)
	_expect_true(failures, "application no longer composes prototype survival controller directly", not SURVIVAL_PATH in app_source)
	_expect_true(failures, "application composes world settings", WORLD_SETTINGS_PATH in app_source)
	_expect_true(failures, "application composes survival settings", SURVIVAL_SETTINGS_PATH in app_source)
	_expect_true(failures, "application composes water settings", WATER_SETTINGS_PATH in app_source)
	_expect_true(failures, "application does not reference retired data settings", not LEGACY_DATA_SETTINGS_PATH in app_source)
	_expect_true(failures, "player harvesting routes to survival", "player.harvest_requested.connect(survival.try_harvest)" in app_source)
	_expect_true(failures, "player crafting routes to survival", "player.craft_requested.connect(survival.request_craft)" in app_source)
	_expect_true(failures, "legacy mixed chunk manager path is retired", not FileAccess.file_exists(LEGACY_MANAGER_PATH))
	_expect_true(failures, "legacy data settings path is retired", not FileAccess.file_exists(LEGACY_DATA_SETTINGS_PATH))

	_cleanup_test_save(TEST_WORLD_SEED)
	survival.free()
	return failures


static func _cleanup_test_save(world_seed: int) -> void:
	var path: String = "user://underworld_seed_%d.json" % world_seed
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func _expect_true(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)


static func _expect_equal(failures: Array[String], label: String, actual, expected) -> void:
	if actual != expected:
		failures.append("%s: expected=%s actual=%s" % [label, expected, actual])
