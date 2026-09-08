extends RefCounted
class_name UnderworldResourceCellObserver

const RuntimeSourceQuery := preload("res://worldgen/runtime/underworld_runtime_cell_source_query.gd")

const REQUIRED_TIER := "render"


## Resource-facing adapter over the #372-owned detached runtime source query.
## Gameplay never reaches cave definition/streamer mutable internals directly.
static func current_snapshot(controller, address) -> Dictionary:
	return RuntimeSourceQuery.current_snapshot(controller, address, REQUIRED_TIER)


static func current_snapshots(controller) -> Array[Dictionary]:
	return RuntimeSourceQuery.current_snapshots(controller, REQUIRED_TIER)


static func snapshot_is_current(controller, snapshot: Dictionary) -> bool:
	return RuntimeSourceQuery.snapshot_is_current(controller, snapshot, REQUIRED_TIER)


static func collision_is_current(controller, snapshot: Dictionary) -> bool:
	return RuntimeSourceQuery.tier_is_current_for_snapshot(controller, snapshot, "collision")
