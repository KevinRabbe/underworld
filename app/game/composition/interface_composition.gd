extends RefCounted

const GameplayHudScript := preload("res://presentation/ui/hud/gameplay_hud.gd")
const DebugHudScript := preload("res://presentation/ui/debug/debug_hud.gd")


static func bind_gameplay_audio(root: Node) -> Dictionary:
	var binding = root.get_node_or_null("GameplayAudio")
	if binding == null or not binding.has_method("bind_game"):
		return {"success": true, "binding": binding, "diagnostics": []}
	var failures: Array[String] = binding.bind_game(root)
	return {
		"success": failures.is_empty(),
		"binding": binding,
		"diagnostics": failures,
	}


static func compose_gameplay_hud(
	root: Node,
	player,
	survival,
	parry_callback: Callable
) -> Dictionary:
	var gameplay_hud = GameplayHudScript.new()
	gameplay_hud.name = "GameplayHUD"
	root.add_child(gameplay_hud)
	var failures: Array[String] = gameplay_hud.configure(
		player,
		survival.get_inventory_state(),
		survival.get_equipment_state()
	)
	survival.harvest_result.connect(gameplay_hud.present_feedback)
	player.parry_succeeded.connect(parry_callback)
	return {
		"success": failures.is_empty(),
		"gameplay_hud": gameplay_hud,
		"diagnostics": failures,
	}


static func compose_debug_hud(
	root: Node,
	enabled: bool,
	world,
	player,
	world_settings,
	survival,
	combat_resolver,
	encounter_controller,
	underworld_runtime
) -> Dictionary:
	if not enabled:
		return {"success": true, "debug_hud": null, "diagnostics": []}
	var debug_hud = DebugHudScript.new()
	debug_hud.name = "DebugHUD"
	debug_hud.configure(
		world,
		player,
		world_settings,
		survival,
		combat_resolver,
		encounter_controller,
		underworld_runtime
	)
	root.add_child(debug_hud)
	return {"success": true, "debug_hud": debug_hud, "diagnostics": []}
