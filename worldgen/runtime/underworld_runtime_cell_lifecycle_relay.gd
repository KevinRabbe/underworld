extends RefCounted
class_name UnderworldRuntimeCellLifecycleRelay

const CaveRuntimeController := preload("res://worldgen/runtime/underworld_cave_runtime_controller.gd")

signal tier_retired(address, tier: String)

var _controller = null
var _streamer = null


## Read-only lifecycle relay for consumers that must react to #372 retirement
## without reaching UnderworldRuntimeStreamer directly. It owns no demand,
## readiness, cache, generation or eviction state.
func configure(controller) -> Array[String]:
	dispose()
	var failures: Array[String] = []
	if controller == null or not controller is CaveRuntimeController:
		failures.append("underworld lifecycle relay requires UnderworldCaveRuntimeController")
		return failures
	if controller.streamer == null or not controller.streamer.has_signal("tier_retired"):
		failures.append("underworld lifecycle relay requires configured runtime streamer")
		return failures
	_controller = controller
	_streamer = controller.streamer
	var callback := Callable(self, "_on_tier_retired")
	if not _streamer.is_connected("tier_retired", callback):
		_streamer.connect("tier_retired", callback)
	return failures


func dispose() -> void:
	if _streamer != null and is_instance_valid(_streamer):
		var callback := Callable(self, "_on_tier_retired")
		if _streamer.has_signal("tier_retired") and _streamer.is_connected("tier_retired", callback):
			_streamer.disconnect("tier_retired", callback)
	_streamer = null
	_controller = null


func _on_tier_retired(address, tier: String) -> void:
	tier_retired.emit(address, tier)
