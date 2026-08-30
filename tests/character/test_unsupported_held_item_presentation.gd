extends RefCounted

const PlayerScript := preload("res://gameplay/player/player.gd")
const VoxelProvider := preload("res://presentation/characters/voxel/voxel_character_presentation_provider.gd")


static func run(tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	if tree == null or tree.root == null:
		failures.append("unsupported held-item fixture requires SceneTree root")
		return failures

	var root := Node3D.new()
	tree.root.add_child(root)
	var provider = VoxelProvider.new()
	var player = PlayerScript.new()
	player.set("character_presentation_provider", provider)
	root.add_child(player)

	var collision: CollisionShape3D = player.get_node_or_null("CollisionShape3D")
	var collision_radius: float = collision.shape.radius if collision != null and collision.shape is CapsuleShape3D else -1.0
	var collision_height: float = collision.shape.height if collision != null and collision.shape is CapsuleShape3D else -1.0
	var action_controller = player.get("action_controller")
	var action_state_before: StringName = action_controller.state_name()

	player.call("set_equipped_tool", "stone_axe")
	var presentation = player.get("character_presentation")
	var tool_root: Node3D = presentation.get_tool_visual_root() if presentation != null else null
	_expect_true(
		failures,
		"supported stone axe realizes concrete held-item presentation",
		tool_root != null and tool_root.find_children("VoxelHeld*", "MeshInstance3D", true, false).size() == 2
	)

	var unsupported_id := "fixture.unsupported_equipment"
	player.call("set_equipped_tool", unsupported_id)
	_expect_equal(
		failures,
		"unsupported presentation fallback cannot rewrite gameplay equipment identity",
		str(player.get("equipped_tool_visual")),
		unsupported_id
	)
	_expect_equal(
		failures,
		"unsupported equipment leaves semantic hand presentation hidden",
		tool_root.find_children("VoxelHeld*", "MeshInstance3D", true, false).size() if tool_root != null else -1,
		0
	)
	_expect_equal(failures, "unsupported equipment uses explicit hidden fallback mode", provider.held_item_fallback_mode(), &"hidden")
	var diagnostic: String = provider.last_held_item_diagnostic()
	_expect_true(
		failures,
		"unsupported held-item diagnostic identifies the rejected semantic id",
		diagnostic.contains("unsupported") and diagnostic.contains(unsupported_id)
	)
	_expect_true(
		failures,
		"presentation fallback cannot mutate Player collision",
		collision != null
		and collision.shape is CapsuleShape3D
		and is_equal_approx(collision.shape.radius, collision_radius)
		and is_equal_approx(collision.shape.height, collision_height)
	)
	_expect_equal(
		failures,
		"presentation fallback cannot mutate Player action state",
		action_controller.state_name(),
		action_state_before
	)

	root.free()
	return failures


static func _expect_true(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)


static func _expect_equal(failures: Array[String], label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		failures.append("%s — expected %s, got %s" % [label, str(expected), str(actual)])
