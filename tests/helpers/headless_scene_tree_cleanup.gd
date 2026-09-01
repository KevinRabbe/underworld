extends RefCounted
class_name HeadlessSceneTreeCleanup

# Headless lifecycle tests often free real Node/resource graphs immediately before
# SceneTree.quit(). Give SceneTree plus the physics/render servers a small,
# deterministic post-free lifecycle window without sleeping, polling ObjectDB, or
# force-freeing production objects.
const PROCESS_DRAIN_FRAMES: int = 2
const PHYSICS_DRAIN_FRAMES: int = 1


static func drain(tree: SceneTree) -> Array[String]:
	if tree == null or tree.root == null:
		return ["headless cleanup requires a live SceneTree root"]

	# The first process frame retires queued/deferred Node work, the physics frame
	# advances physics-server cleanup, and the final process frame lets deferred
	# resource/render cleanup settle before the runner exits.
	await tree.process_frame
	await tree.physics_frame
	await tree.process_frame
	return []
