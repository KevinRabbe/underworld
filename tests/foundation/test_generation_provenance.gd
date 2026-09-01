extends RefCounted

const Context := preload("res://worldgen/pipeline/world_generation_context.gd")
const Manifest := preload("res://worldgen/versioning/generator_manifest.gd")
const MacroGenerator := preload("res://worldgen/underworld/macro_region_generator.gd")
const TopologyGenerator := preload("res://worldgen/underworld/primary_topology_generator.gd")
const SurfaceSampler := preload("res://worldgen/surface/deterministic_surface_sampler.gd")
const GeometryProbe := preload("res://worldgen/validation/cave_geometry_reproduction_probe.gd")
const Provenance := preload("res://worldgen/pipeline/generation_provenance.gd")
const GeometryTests := preload("res://tests/geometry/test_cave_geometry.gd")
const HookResult := preload("res://worldgen/underworld/special_location_hook_result.gd")
const RegionFinalizer := preload("res://worldgen/underworld/region_finalizer.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_coherent_pipeline(failures)
	_test_mixed_seed_and_manifest_rejection(failures)
	_test_invalid_ancestry(failures)
	_test_mutation_and_required_ancestry(failures)
	_test_authoritative_exact_parent_boundary(failures)
	return failures


static func _test_coherent_pipeline(failures: Array[String]) -> void:
	var built: Dictionary = GeometryProbe._build_inputs(424242, Vector2i(-2, 3))
	_expect_true(failures, "coherent provenance pipeline succeeds", bool(built.get("success", false)))
	if not bool(built.get("success", false)):
		return
	var context = built["context"]
	var stages: Array = [
		built["macro"], built["topology"], built["entrances"], built["connectivity"],
		built["hooks"], built["finalized"],
	]
	for stage in stages:
		_expect_true(failures, "pipeline result carries provenance", stage.provenance != null)
		if stage.provenance != null:
			_expect_true(failures, "pipeline provenance validates", context.validate_provenance(stage.provenance).is_empty())
	var geometry = preload("res://worldgen/underworld/cave_geometry_generator.gd").generate(
		context, built["macro"], built["finalized"], built["neighbor_views"]
	)
	_expect_true(failures, "geometry provenance pipeline succeeds", geometry.success)
	if geometry.success:
		_expect_true(failures, "geometry result carries provenance", geometry.data.provenance != null)


static func _test_mixed_seed_and_manifest_rejection(failures: Array[String]) -> void:
	var region := Vector2i(0, 0)
	var context_a = Context.new(10101)
	var context_b = Context.new(20202)
	var sampler_a := SurfaceSampler.new(10101)
	var macro_a = MacroGenerator.generate(context_a, region)
	var macro_b = MacroGenerator.generate(context_b, region)
	var topology_a = TopologyGenerator.generate(context_a, macro_a.data, sampler_a)
	var mixed_seed = TopologyGenerator.generate(context_b, macro_a.data, SurfaceSampler.new(20202))
	_expect_true(failures, "mixed-seed macro input is rejected", not mixed_seed.success)
	var alternate_manifest = Manifest.new({"macro_region": 2})
	var context_manifest = Context.new(10101, alternate_manifest)
	var mixed_manifest = TopologyGenerator.generate(context_manifest, macro_a.data, sampler_a)
	_expect_true(failures, "manifest-mismatch macro input is rejected", not mixed_manifest.success)
	_expect_true(failures, "same seed remains distinct by world id", macro_a.data.provenance.world_id != macro_b.data.provenance.world_id)
	_expect_true(failures, "coherent topology still succeeds", topology_a.success)


static func _test_invalid_ancestry(failures: Array[String]) -> void:
	var invalid := Provenance.new("world1", "manifest1", "macro_region", 1, "region", "address", ["dup", "dup"])
	_expect_true(failures, "duplicate ancestry is rejected", not invalid.validate().is_empty())
	_expect_true(failures, "invalid ancestry has no usable fingerprint", invalid.fingerprint.is_empty())


static func _test_mutation_and_required_ancestry(failures: Array[String]) -> void:
	var context := Context.new(77)
	var provenance = context.make_provenance("macro_region", "region", "address", ["parent:a"])
	var original: String = provenance.fingerprint
	provenance.world_id = "world:mutated"
	_expect_true(failures, "mutated provenance is rejected", not provenance.validate().is_empty())
	_expect_true(failures, "provenance fingerprint remains original", provenance.fingerprint == original)
	_expect_true(failures, "required ancestry rejects substituted parent", not provenance.requires_sources(["parent:b"]).is_empty())
	var legitimate = context.make_provenance("stage", "region", "address", ["parent:a", "parent:b"])
	var extra_parent = context.make_provenance("stage", "region", "address", ["parent:a", "parent:b", "unrelated:valid"])
	_expect_true(
		failures,
		"exact ancestry accepts canonicalized legitimate parent set",
		legitimate.validate_exact_sources(["parent:b", "parent:a"]).is_empty()
	)
	_expect_true(
		failures,
		"exact ancestry rejects unrelated extra parent",
		not extra_parent.validate_exact_sources(["parent:a", "parent:b"]).is_empty()
	)
	var pinned_world_id: String = context.world_id
	context.world_id = "world:wrong"
	_expect_true(
		failures,
		"context world id is immutable after construction",
		context.world_id == pinned_world_id
	)
	_expect_true(
		failures,
		"immutable context remains valid after rejected mutation",
		context.validate().is_empty()
	)


static func _test_authoritative_exact_parent_boundary(failures: Array[String]) -> void:
	var built: Dictionary = GeometryTests._build(314159, Vector2i(0, 0), false)
	_expect_true(failures, "exact-parent boundary fixture succeeds", bool(built.get("success", false)))
	if not bool(built.get("success", false)):
		return
	var context = built["context"]
	var region_plan = built["macro"]
	var hook = built["hooks"]
	var extra = context.make_provenance(
		"special_location_hooks",
		region_plan.stable_id,
		region_plan.stable_address.canonical_text(),
		[region_plan.provenance.fingerprint, built["connectivity"].provenance.fingerprint, "unrelated:valid"]
	)
	var substituted = HookResult.new(hook.bundle, hook.candidate_metadata, hook.hook_metrics, hook.fingerprint, extra)
	var rejected = RegionFinalizer.generate(
		context, region_plan, built["entrances"], built["connectivity"], substituted
	)
	_expect_true(failures, "authoritative hook boundary rejects extra parent", not rejected.success)


static func _expect_true(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)
