extends RefCounted

const Cleanup := preload("res://tests/helpers/headless_scene_tree_cleanup.gd")


static func run_runtime(tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	if tree == null or tree.root == null:
		return ["headless cleanup regression requires a live SceneTree root"]

	# Blindness control: a genuinely retained owner must remain observable across
	# the same drain. The helper must never force-free arbitrary live objects.
	var retained_node := Node.new()
	retained_node.name = "QaTeardownRetainedNode"
	tree.root.add_child(retained_node)
	var retained_node_ref: WeakRef = weakref(retained_node)

	var retained_resource := Resource.new()
	var retained_resource_ref: WeakRef = weakref(retained_resource)

	failures.append_array(await Cleanup.drain(tree))
	if retained_node_ref.get_ref() == null:
		failures.append("bounded cleanup hid/freed an intentionally retained Node")
	if retained_resource_ref.get_ref() == null:
		failures.append("bounded cleanup hid/freed an intentionally retained Resource")

	# Explicit release must become observable after the bounded lifecycle window.
	retained_node.free()
	retained_node = null
	retained_resource = null
	failures.append_array(await Cleanup.drain(tree))
	if retained_node_ref.get_ref() != null:
		failures.append("explicitly freed Node remained reachable after bounded cleanup")
	if retained_resource_ref.get_ref() != null:
		failures.append("released Resource remained reachable after bounded cleanup")

	# queue_free() is the normal deferred ownership path; prove the first process
	# boundary in the helper actually retires it before the runner exits.
	var queued_node := Node.new()
	queued_node.name = "QaTeardownQueuedNode"
	tree.root.add_child(queued_node)
	var queued_node_ref: WeakRef = weakref(queued_node)
	queued_node.queue_free()
	queued_node = null
	failures.append_array(await Cleanup.drain(tree))
	if queued_node_ref.get_ref() != null:
		failures.append("queue_free Node remained reachable after bounded cleanup")

	return failures
