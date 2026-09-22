extends RefCounted

## Bounded production-input harness for the playable survival slice.
##
## The harness deliberately enters through AppRoot/Game and sends real input
## events through the SceneTree.  Inventory resources are seeded only as a
## fixture so the normal inventory/crafting UI can be exercised deterministically.
## Some CI hosts cannot instantiate the production 3D scene (notably hosts
## without the imported SVG/rendering resources). In that case we report the
## exact startup blocker as BLOCKED; the bounded harness never converts it to
## PASS and never replaces production input with service-level shortcuts.

const AppRootScene: PackedScene = preload("res://app/app_root.tscn")
const SAVE_CANDIDATE_SUFFIX := ".candidate"
const SAVE_BACKUP_SUFFIX := ".previous"

static func run_runtime(tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	var app := AppRootScene.instantiate()
	if app == null:
		failures.append("BLOCKED: production AppRoot could not instantiate (scene/resource limitation)")
		return failures
	# Never probe or overwrite the user's default slot from an automated run.
	var save_slot_path := "user://codex_playtest_%d.json" % Time.get_ticks_usec()
	if not app.has_method("configure_save_slot_path") or not bool(app.call("configure_save_slot_path", save_slot_path)):
		failures.append("BLOCKED: production AppRoot rejected isolated playtest SAVE slot")
		_cleanup_save_slot(save_slot_path)
		return failures
	tree.root.add_child(app)
	await tree.process_frame
	if not app.has_method("start_new_game") or not bool(app.call("start_new_game")):
		failures.append("BLOCKED: production Game startup failed (SceneTree/rendering/import limitation)")
		app.queue_free()
		await tree.process_frame
		_cleanup_save_slot(save_slot_path)
		return failures
	await tree.process_frame
	await tree.process_frame
	var game = app.get("current_scene")
	if game == null or not is_instance_valid(game) or game.get("player") == null:
		failures.append("production Game did not expose composed Player after startup")
		app.queue_free()
		_cleanup_save_slot(save_slot_path)
		return failures
	var player: Node = game.get("player")
	var survival = game.get("survival")
	_expect(failures, "production Player is inside SceneTree", player.is_inside_tree())
	_expect(failures, "production Survival is composed", survival != null)
	# Game startup composition can finish one deferred pass after Player exposure;
	# seed only after that canonical Survival state is settled.
	await _wait_frames(tree, 4)

	# Frame-polled movement uses a physical W key routed through InputMap.
	var before: Vector3 = player.global_position
	_send_key(tree, KEY_W, true)
	await _wait_physics(tree, 4)
	_send_key(tree, KEY_W, false)
	_expect(failures, "W movement input reaches production Player", player.global_position.distance_to(before) > 0.001)

	# Seed an equippable authored item before opening the UI. The Enter assertion
	# below must prove canonical equipment changed, not merely that a surface lived.
	var inventory = survival.call("get_inventory_state") if survival != null else null
	if survival != null and survival.has_method("get_item_definition") and inventory != null:
		for item_id in ["item.resource.wood", "item.resource.stone", "item.resource.plant_fiber", "item.tool.stone_axe"]:
			var definition = survival.call("get_item_definition", item_id)
			if definition == null:
				failures.append("seed definition unavailable: %s" % item_id)
				print("[PLAYTEST DIAG] missing survival item definition=%s" % item_id)
				continue
			if definition != null:
				var seeded: Dictionary = inventory.call("add_stack", definition, 99) if item_id != "item.tool.stone_axe" else inventory.call("add_instance", definition)
				print("[PLAYTEST DIAG] seed item=%s result=%s" % [item_id, str(seeded)])
				_expect(failures, "seed %s for production input" % item_id, bool(seeded.get("success", false)))
		print("[PLAYTEST DIAG] seeded canonical inventory=%s" % inventory.canonical_json())

	# I is handled by the production InventorySurface and owns input capture.
	await _tap_key(tree, KEY_I)
	var inventory_surface = game.get("inventory_surface")
	_expect(failures, "I opens production inventory surface", inventory_surface != null and bool(inventory_surface.call("is_open")))
	if inventory_surface != null:
		await _tap_key(tree, KEY_I)
		_expect(failures, "I closes production inventory surface", not bool(inventory_surface.call("is_open")))
		await _tap_key(tree, KEY_I)
		_expect(failures, "I reopens production inventory surface", bool(inventory_surface.call("is_open")))

	# Exercise real slot selection/equip via UI focus and prove canonical state changed.
	if survival != null and inventory_surface != null:
		var equipment = survival.call("get_equipment_state")
		var equipment_before: String = equipment.canonical_json() if equipment != null else ""
		var grid = inventory_surface.find_child("GridContainer", true, false)
		var axe_slot := -1
		if grid != null:
			for index in range(inventory.slot_capacity()):
				var record: Dictionary = inventory.state_at(index)
				var slot_definition = inventory.definition_at(index) if inventory.has_method("definition_at") else null
				print("[PLAYTEST DIAG] inventory slot=%d item=%s grid_children=%d capacity=%d" % [index, str(slot_definition.content_id) if slot_definition != null else "<empty>", grid.get_child_count(), inventory.slot_capacity()])
				if slot_definition != null and str(slot_definition.content_id) == "item.tool.stone_axe":
					axe_slot = index
					break
		if axe_slot >= 0 and grid != null and axe_slot < grid.get_child_count():
			var axe_button := grid.get_child(axe_slot) as Button
			var pressed_count: Array[int] = [0]
			axe_button.pressed.connect(func() -> void: pressed_count[0] += 1)
			axe_button.grab_focus()
			print("[PLAYTEST DIAG] axe button focused=%s disabled=%s equipment_before=%s" % [str(axe_button.has_focus()), str(axe_button.disabled), equipment_before])
			await _tap_action(tree, &"ui_accept")
			var equipment_after: String = equipment.canonical_json() if equipment != null else ""
			var selected = equipment.selected_definition() if equipment != null else null
			print("[PLAYTEST DIAG] axe button pressed=%d equipment_after=%s selected=%s" % [pressed_count[0], equipment_after, str(selected.content_id) if selected != null else "<none>"])
			_expect(failures, "inventory Enter selects/equips authored tool", axe_slot >= 0 and equipment_after != equipment_before and equipment.selected_definition() != null)
		else:
			failures.append("inventory Enter could not locate seeded authored tool slot")
		# Release the inventory capture before exercising the next modal surface.
		await _tap_key(tree, KEY_I)
		await _wait_physics(tree, 4)

	# C opens the real crafting screen; its first recipe is activated by Enter.
	# WeaponRuntimeSession binds deferred from Game._ready; allow that production
	# composition to settle before inspecting its authored capabilities.
	await _wait_frames(tree, 4)
	var crafting_inventory_before: String = inventory.canonical_json() if inventory != null else ""
	var crafting_equipment_before: String = survival.call("get_equipment_state").canonical_json() if survival != null else ""
	var crafting_ui = game.get("crafting_ui")
	await _tap_key(tree, KEY_C)
	_expect(failures, "C opens production crafting surface", crafting_ui != null and bool(crafting_ui.call("is_open")))
	if crafting_ui != null and bool(crafting_ui.call("is_open")):
		var recipe_list = crafting_ui.find_child("RecipeList", true, false)
		var weapon_session = game.get_node_or_null("WeaponRuntimeSession")
		print("[PLAYTEST DIAG] crafting capabilities=%d recipe_buttons=%d session_configured=%s" % [weapon_session.call("craft_capabilities").size() if weapon_session != null else -1, recipe_list.get_child_count() if recipe_list != null else -1, str(weapon_session.call("is_configured")) if weapon_session != null else "<missing>"])
		var axe_recipe_button: Control = null
		if recipe_list != null:
			for child in recipe_list.get_children():
				if child is Control and str((child as Control).tooltip_text) == "recipe.hand.stone_axe":
					axe_recipe_button = child as Control
		if axe_recipe_button != null:
			axe_recipe_button.grab_focus()
			await _tap_key(tree, KEY_ENTER)
			await tree.process_frame
			var weapon_session_after = game.get_node_or_null("WeaponRuntimeSession")
			var craft_result: Dictionary = weapon_session_after.call("last_result") if weapon_session_after != null else {}
			print("[PLAYTEST DIAG] craft last_result=%s" % [str(craft_result)])
			var crafting_inventory_after: String = inventory.canonical_json() if inventory != null else ""
			var crafting_equipment_after: String = survival.call("get_equipment_state").canonical_json() if survival != null else ""
			_expect(failures, "crafting Enter reports successful recipe transaction", bool(craft_result.get("success", false)) and bool(craft_result.get("craft_succeeded", false)))
			_expect(failures, "crafting Enter changes material/equipment state", crafting_inventory_after != crafting_inventory_before or crafting_equipment_after != crafting_equipment_before)
		else:
			failures.append("crafting surface exposed no stone axe recipe button for Enter")
		_expect(failures, "crafting UI remains live after craft/equip input", crafting_ui.has_method("render_snapshot"))
	# CraftingScreen owns C close; Escape is intentionally not its shortcut.
	if crafting_ui != null and bool(crafting_ui.call("is_open")):
		await _tap_key(tree, KEY_C)
	await _wait_physics(tree, 4)

	# A normal left-click harvest request is routed through Player -> Survival.
	# Surface chunk generation and world-object proxy activation are deferred;
	# allow the production streamer enough real frames before searching colliders.
	await _wait_physics(tree, 240)
	var world = game.get("world")
	print("[PLAYTEST DIAG] surface chunks=%s pending=%s generated=%s decorations=%s active_objects=%s pickups=%s" % [
		str(world.call("get_loaded_chunk_count")) if world != null and world.has_method("get_loaded_chunk_count") else "<missing>",
		str(world.call("get_pending_chunk_count")) if world != null and world.has_method("get_pending_chunk_count") else "<missing>",
		str(world.call("get_total_chunks_generated")) if world != null and world.has_method("get_total_chunks_generated") else "<missing>",
		str(world.call("get_current_decoration_counts")) if world != null and world.has_method("get_current_decoration_counts") else "<missing>",
		str(world.call("get_active_world_object_count")) if world != null and world.has_method("get_active_world_object_count") else "<missing>",
		str(world.call("get_current_pickup_counts")) if world != null and world.has_method("get_current_pickup_counts") else "<missing>",
	])
	var tree_body: StaticBody3D = null
	var tree_object_id := ""
	var tree_distance := INF
	for candidate in game.find_children("*", "StaticBody3D", true, false):
		if not candidate.has_meta("world_object_type") or str(candidate.get_meta("world_object_type")) != "tree":
			continue
		var distance: float = player.global_position.distance_to(candidate.global_position)
		if distance < tree_distance:
			tree_body = candidate as StaticBody3D
			tree_distance = distance
			tree_object_id = str(candidate.get_meta("world_object_id"))
	if tree_body != null:
		var target_direction: Vector3 = tree_body.global_position - player.global_position
		target_direction.y = 0.0
		var camera_yaw = player.get("camera_yaw")
		if camera_yaw != null and not target_direction.is_zero_approx():
			camera_yaw.rotation.y = atan2(-target_direction.x, -target_direction.z)
	else:
		failures.append("BLOCKED: no active production tree collider was available for real chopping")
	var wood_before_harvest: int = inventory.quantity_of("item.resource.wood")
	var fiber_before: int = inventory.quantity_of("item.resource.plant_fiber")
	var harvest_requests: Array[int] = [0]
	player.harvest_requested.connect(func(_origin: Vector3, _direction: Vector3, _distance: float) -> void: harvest_requests[0] += 1)
	for _hit in range(3):
		var harvest_interaction := InputEventMouseButton.new()
		harvest_interaction.button_index = MOUSE_BUTTON_LEFT
		harvest_interaction.pressed = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		Input.parse_input_event(harvest_interaction)
		await _wait_physics(tree, 30)
	var gate = app.get_gameplay_input_gate() if app.has_method("get_gameplay_input_gate") else null
	var gameplay_enabled := bool(player.call("gameplay_input_enabled")) if player.has_method("gameplay_input_enabled") else false
	print("[PLAYTEST DIAG] harvest requests=%d mouse_mode=%d gameplay_input_enabled=%s gate_allowed=%s" % [harvest_requests[0], Input.mouse_mode, str(gameplay_enabled), str(gate.call("allows_player_input")) if gate != null else "<missing>"])
	_expect(failures, "left-click resource interaction reaches production harvest path", harvest_requests[0] > 0)
	_expect(failures, "three real tree clicks produce canonical wood", tree_body != null and inventory.quantity_of("item.resource.wood") >= wood_before_harvest + 4)
	if not tree_object_id.is_empty() and world != null and world.has_method("is_world_object_destroyed"):
		_expect(failures, "three real tree clicks destroy the world tree", bool(world.call("is_world_object_destroyed", tree_object_id)))
	await _wait_physics(tree, 120)
	_expect(failures, "real nearby plant-fiber pickup reaches canonical inventory", inventory.quantity_of("item.resource.plant_fiber") > fiber_before)

	# B/G/LMB traverse the production build/workbench/placement input path.
	await _tap_key(tree, KEY_B)
	_expect(failures, "B activates production build tool", player.get("build_tool_active") == true)
	var building_runtime = survival.call("get_building_runtime") if survival != null else null
	var building_before: Dictionary = building_runtime.durable_snapshot() if building_runtime != null else {}
	var wood_before: int = inventory.quantity_of("item.resource.wood") if inventory != null else -1
	var stone_before: int = inventory.quantity_of("item.resource.stone") if inventory != null else -1
	await _tap_key(tree, KEY_G)
	await _wait_physics(tree, 4)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Input.parse_input_event(click)
	await _wait_physics(tree, 30)
	var building_after: Dictionary = building_runtime.durable_snapshot() if building_runtime != null else {}
	var placed: Array = building_after.get("placed_shelters", [])
	print("[PLAYTEST DIAG] building before=%s after=%s player_build_tool=%s" % [str(building_before), str(building_after), str(player.get("build_tool_active"))])
	_expect(failures, "G uses the live workbench", bool(building_after.get("workbench_used", false)) and not bool(building_before.get("workbench_used", false)))
	_expect(failures, "G/LMB places authored shelter and consumes materials", placed.size() > int(building_before.get("placed_shelters", []).size()) and inventory.quantity_of("item.resource.wood") == wood_before - 4 and inventory.quantity_of("item.resource.stone") == stone_before - 2)

	# Durable save/continue uses the application boundary and the production snapshot.
	if app.has_method("save_current_game"):
		var save_result: Dictionary = app.call("save_current_game")
		if not bool(save_result.get("success", false)):
			failures.append("SAVE BLOCKED: save_current_game diagnostics=%s" % [save_result.get("diagnostics", [])])
		_expect(failures, "production save returns success", bool(save_result.get("success", false)))
		if bool(save_result.get("success", false)):
			if not app.has_method("show_title") or not app.has_method("continue_game"):
				failures.append("SAVE BLOCKED: successful save has no mandatory title/continue route")
			else:
				_expect(failures, "production title route is reachable after save", bool(app.call("show_title")))
				await tree.process_frame
				_expect(failures, "production continue route restores after save", bool(app.call("continue_game")))
	else:
		failures.append("SAVE BLOCKED: AppRoot does not expose mandatory save_current_game")

	app.queue_free()
	await tree.process_frame
	_cleanup_save_slot(save_slot_path)
	return failures


static func _cleanup_save_slot(slot_path: String) -> void:
	for path in [slot_path, slot_path + SAVE_CANDIDATE_SUFFIX, slot_path + SAVE_BACKUP_SUFFIX]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


static func _wait_frames(tree: SceneTree, count: int) -> void:
	for _index in range(count):
		await tree.process_frame


static func _wait_physics(tree: SceneTree, count: int) -> void:
	for _index in range(count):
		await tree.physics_frame

static func _send_key(tree: SceneTree, physical_key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = physical_key
	event.keycode = physical_key
	event.key_label = physical_key
	event.unicode = physical_key
	event.pressed = pressed
	Input.parse_input_event(event)

static func _tap_key(tree: SceneTree, physical_key: Key) -> void:
	_send_key(tree, physical_key, true)
	await tree.process_frame
	_send_key(tree, physical_key, false)
	await tree.process_frame


static func _tap_action(tree: SceneTree, action: StringName) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	Input.parse_input_event(press)
	await tree.process_frame
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)
	await tree.process_frame

static func _expect(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)
