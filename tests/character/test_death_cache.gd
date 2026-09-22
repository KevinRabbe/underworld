extends RefCounted

const ItemContainerState := preload("res://gameplay/items/inventory/item_container_state.gd")
const DeathCacheService := preload("res://gameplay/player/lifecycle/player_death_cache_service.gd")
const DeathRecoveryController := preload("res://gameplay/player/lifecycle/player_death_recovery_controller.gd")
const WoodDefinition := preload("res://content/items/resources/wood_definition.tres")


class FakeEquipment:
	func canonical_snapshot() -> Dictionary:
		return {"schema": "equipment.hotbar.v1", "retained": true}


class FakePlayer:
	var global_position := Vector3(3.0, 10.0, 4.0)
	func is_defeated() -> bool: return true
	func commit_respawn(_target: Vector3) -> bool: return true


class FakeWorld:
	var preferred_calls: Array[Vector3] = []
	func find_spawn_xz(preferred: Vector3) -> Vector3:
		preferred_calls.append(preferred)
		return preferred
	func get_height_at_world(_x: float, _z: float) -> float: return 10.0


class FakeSettings:
	var sea_level := 0.0
	var chunk_size := 64.0


class FakeBed:
	func get_bed_respawn_position() -> Vector3: return Vector3(40.0, 0.0, -12.0)


static func run() -> Array[String]:
	var failures: Array[String] = []
	var inventory := ItemContainerState.new().configure(8)
	var service = DeathCacheService.new().configure(inventory, FakeEquipment.new(), [WoodDefinition])
	var added: Dictionary = inventory.add_stack(WoodDefinition, 3)
	if not bool(added.get("success", false)):
		failures.append("death cache fixture could not add cargo")
	var first: Dictionary = service.capture_death(Vector3(8.0, 2.0, 9.0))
	if not bool(first.get("success", false)) or bool(first.get("already_captured", true)):
		failures.append("first legitimate death did not create cache")
	if inventory.quantity_of("item.resource.wood") != 0:
		failures.append("death did not transfer cargo out of player ownership")
	var replay: Dictionary = service.capture_death(Vector3(99.0, 2.0, 99.0))
	if not bool(replay.get("already_captured", false)):
		failures.append("replayed death created a second cache")
	var collected: Dictionary = service.collect_cache()
	if not bool(collected.get("success", false)) or inventory.quantity_of("item.resource.wood") != 3:
		failures.append("cache collection did not restore cargo exactly once")
	if bool(service.collect_cache().get("success", false)):
		failures.append("collected cache was collectible twice")
	var malformed_inventory := ItemContainerState.new().configure(8)
	malformed_inventory.add_stack(WoodDefinition, 2)
	var malformed_service = DeathCacheService.new().configure(malformed_inventory, FakeEquipment.new(), [WoodDefinition])
	malformed_service.capture_death(Vector3(1.0, 2.0, 3.0))
	var malformed_snapshot: Dictionary = malformed_service.durable_snapshot()
	malformed_snapshot["cache"]["cargo"]["slots"].append({"slot": 99, "kind": "stack", "state": {"item_id": "missing", "quantity": 1, "stack_state": {}}})
	var malformed_restore := DeathCacheService.new().configure(malformed_inventory, FakeEquipment.new(), [WoodDefinition])
	_expect_failure(failures, "malformed death cache hydration fails closed", malformed_restore.restore_durable_snapshot(malformed_snapshot))
	var restored = DeathCacheService.new().configure(inventory, FakeEquipment.new(), [WoodDefinition])
	if not bool(restored.restore_durable_snapshot(service.durable_snapshot()).get("success", false)):
		failures.append("death cache durable state did not restore")
	var world := FakeWorld.new()
	var controller := DeathRecoveryController.new()
	var configure_failures: Array[String] = controller.configure(FakePlayer.new(), world, FakeSettings.new(), null, FakeBed.new())
	if not configure_failures.is_empty():
		failures.append_array(configure_failures)
	else:
		var target: Dictionary = controller.resolve_safe_target(Vector3(3.0, 10.0, 4.0))
		if not bool(target.get("success", false)) or world.preferred_calls.is_empty() or not world.preferred_calls[0].is_equal_approx(Vector3(40.0, 0.0, -12.0)):
			failures.append("bed respawn anchor was not preferred by death recovery")
	controller.free()
	return failures

static func _expect_failure(failures: Array[String], label: String, result: Dictionary) -> void:
	if bool(result.get("success", false)):
		failures.append(label)
