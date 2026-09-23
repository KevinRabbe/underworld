extends Node

const WorldGenerationContext := preload("res://worldgen/pipeline/world_generation_context.gd")
const WorldDomainSessionState := preload("res://gameplay/world_session/world_domain_session_state.gd")
const IntegratedGameSaveContract := preload("res://gameplay/persistence/integrated_game_save_contract.gd")
const SlotFixtures := preload("res://tests/persistence/test_game_save_slot_service.gd")

var prepared_mode: StringName = &""
var prepared_candidate: Dictionary = {}
var prepared_profile: Dictionary = {}
var gameplay_input_gate: Node = null

func configure_gameplay_input_gate(gate: Node) -> bool:
	if is_inside_tree() or gate == null or not is_instance_valid(gate):
		return false
	gameplay_input_gate = gate
	return true

func prepare_new_game(profile: Dictionary = {}) -> bool:
	if is_inside_tree() or gameplay_input_gate == null:
		return false
	prepared_mode = &"new"
	prepared_candidate.clear()
	prepared_profile = profile.duplicate(true)
	return true

func prepare_continue(candidate: Dictionary) -> bool:
	if is_inside_tree() or gameplay_input_gate == null:
		return false
	prepared_mode = &"continue"
	prepared_candidate = candidate.duplicate(true)
	# The production route passes only the validated candidate to CONTINUE.
	# Preserve its world seed so a subsequent SAVE remains bound to the same
	# generated world instead of falling back to the fixture seed.
	prepared_profile = {"world": {"world_seed": int(candidate.get("world_seed", 217217))}}
	return true

func build_save_request() -> Dictionary:
	var failures: Array[String] = []
	var fixture: Dictionary = SlotFixtures._fixture(failures)
	if not failures.is_empty() or fixture.is_empty():
		return {"success": false, "diagnostics": failures}
	var request: Dictionary = fixture["request"].duplicate(true)
	var profile_world: Variant = prepared_profile.get("world", null)
	if profile_world is Dictionary:
		var seed := int(profile_world.get("world_seed", 217217))
		var marker := 11.0 if seed == 4242 else 22.0
		var recaptured := IntegratedGameSaveContract.capture_v2_request({
			"world_context": WorldGenerationContext.new(seed),
			"world_session_state": WorldDomainSessionState.new(WorldDomainSessionState.DOMAIN_OVERWORLD, {}),
			"delta_store": fixture["delta_store"],
			"inventory_state": fixture["inventory"],
			"equipment_state": fixture["equipment"],
			"pending_loot_states": [],
			"resume_position": Vector3(marker, 32.0, -11.5),
			"current_health": 83,
			"current_stamina": 47.25,
		})
		return recaptured
	return {"success": true, "request": request}
