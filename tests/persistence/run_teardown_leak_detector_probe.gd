extends SceneTree

# Isolated expected-leak probe for the CI teardown detector. This runner must
# never be composed into semantic Persistence validation. The detached Node is
# intentionally not freed, and it owns the Resource through metadata so both
# remain live until engine shutdown.
var _retained_node: Node


func _init() -> void:
	var retained_resource := Resource.new()
	retained_resource.resource_name = "teardown_leak_detector_probe_resource"

	_retained_node = Node.new()
	_retained_node.name = "TeardownLeakDetectorProbeNode"
	_retained_node.set_meta("retained_resource", retained_resource)

	print("[TEARDOWN LEAK DETECTOR PROBE] intentional retained Node + Resource armed")
	quit(0)
