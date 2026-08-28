extends RefCounted

const StableAddress := preload("res://worldgen/identity/stable_address.gd")
const WorldGenerationContext := preload("res://worldgen/pipeline/world_generation_context.gd")
const GenerationStageResult := preload("res://worldgen/pipeline/generation_stage_result.gd")
const WorldDefinitionService := preload("res://worldgen/services/world_definition_service.gd")
const WorldDeltaStore := preload("res://worldgen/persistence/world_delta_store.gd")
const SampleGraphFixture := preload("res://tests/foundation/sample_graph_fixture.gd")
const ReservedSiteAssignmentTests := preload("res://tests/content/test_reserved_site_assignment.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []

	var context = WorldGenerationContext.new(12345)
	failures.append_array(context.validate())

	var service = WorldDefinitionService.new()
	failures.append_array(service.configure(context))
	var region_address = StableAddress.underground_region(0, 0)
	var request_a: Dictionary = service.make_region_request(0, 0, 10)
	var request_b: Dictionary = service.make_region_request(0, 0, 10)
	if request_a != request_b:
		failures.append("WorldDefinitionService region request is not deterministic")
	if service.has_region(region_address):
		failures.append("WorldDefinitionService reports uncached region as ready")

	var bundle = SampleGraphFixture.build()
	failures.append_array(service.store_finalized_region(bundle))
	if not service.has_region(region_address):
		failures.append("WorldDefinitionService did not expose stored finalized region")
	if service.get_region_if_ready(region_address) != bundle:
		failures.append("WorldDefinitionService returned wrong stored region bundle")
	if service.cached_region_count() != 1:
		failures.append("WorldDefinitionService cache count mismatch")
	if not service.evict_region(region_address):
		failures.append("WorldDefinitionService failed to evict cached region")
	if service.has_region(region_address):
		failures.append("WorldDefinitionService retained evicted region")

	var stage_ok = GenerationStageResult.ok("foundation-probe", {"value": 7}, "abc")
	if not stage_ok.success or stage_ok.stage_name != "foundation-probe" or stage_ok.fingerprint != "abc":
		failures.append("GenerationStageResult success boundary is invalid")
	var stage_fail = GenerationStageResult.fail("foundation-probe", ["expected failure"])
	if stage_fail.success or stage_fail.diagnostics.size() != 1:
		failures.append("GenerationStageResult failure boundary is invalid")

	var first_node = bundle.nodes[0]
	var destroyed_id: String = first_node.stable_id
	var delta_store = WorldDeltaStore.new()
	if not delta_store.mark_generated_object_destroyed(destroyed_id):
		failures.append("WorldDeltaStore rejected valid generated StableId")
	if not delta_store.is_generated_object_destroyed(destroyed_id):
		failures.append("WorldDeltaStore lost destroyed-object delta")
	if delta_store.mark_generated_object_destroyed("not-a-stable-id"):
		failures.append("WorldDeltaStore accepted invalid generated StableId")
	if not delta_store.set_object_state(destroyed_id, {"hits": 2}):
		failures.append("WorldDeltaStore rejected valid object-state delta")
	if int(delta_store.get_object_state(destroyed_id).get("hits", -1)) != 2:
		failures.append("WorldDeltaStore object state round-trip failed")

	var snapshot: Dictionary = delta_store.snapshot()
	var reloaded = WorldDeltaStore.new()
	failures.append_array(reloaded.load_modern_delta_payload(snapshot))
	if not reloaded.is_generated_object_destroyed(destroyed_id):
		failures.append("WorldDeltaStore snapshot reload lost destroyed delta")
	if int(reloaded.get_object_state(destroyed_id).get("hits", -1)) != 2:
		failures.append("WorldDeltaStore snapshot reload lost object state")

	failures.append_array(ReservedSiteAssignmentTests.run())
	return failures
