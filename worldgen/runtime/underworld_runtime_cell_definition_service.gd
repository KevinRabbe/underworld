extends RefCounted
class_name UnderworldRuntimeCellDefinitionService

const StageResult := preload("res://worldgen/pipeline/generation_stage_result.gd")
const WorldContext := preload("res://worldgen/pipeline/world_generation_context.gd")
const SurfaceSampler := preload("res://worldgen/surface/deterministic_surface_sampler.gd")
const MacroGenerator := preload("res://worldgen/underworld/macro_region_generator.gd")
const TopologyGenerator := preload("res://worldgen/underworld/primary_topology_generator.gd")
const EntranceGenerator := preload("res://worldgen/underworld/entrance_generator.gd")
const ConnectivityGenerator := preload("res://worldgen/underworld/secondary_connectivity_generator.gd")
const HookGenerator := preload("res://worldgen/underworld/special_location_hook_generator.gd")
const RegionFinalizer := preload("res://worldgen/underworld/region_finalizer.gd")
const GeometryGenerator := preload("res://worldgen/underworld/cave_geometry_generator.gd")
const PartitionConfig := preload("res://worldgen/geometry/geometry_cell_partition_config.gd")
const PartitionRequest := preload("res://worldgen/geometry/geometry_cell_partition_request.gd")
const Partitioner := preload("res://worldgen/geometry/geometry_cell_partitioner.gd")
const Address := preload("res://worldgen/geometry/geometry_cell_address.gd")

const REGION_SIZE: float = 512.0
const UNDERWORLD_MIN_Y: float = -384.0
const UNDERWORLD_MAX_Y: float = 0.0
const NEIGHBOR_OFFSETS: Array[Vector2i] = [
	Vector2i(-1, 0),
	Vector2i(1, 0),
	Vector2i(0, -1),
	Vector2i(0, 1),
]

var world_seed: int = 0
var context
var surface_sampler
var cell_config
var _base_regions: Dictionary = {}
var _regions: Dictionary = {}
var _cells: Dictionary = {}


func configure(world_seed_value: int, context_value = null) -> Array[String]:
	world_seed = world_seed_value
	var failures: Array[String] = []
	if context_value == null:
		context = WorldContext.new(world_seed)
	elif context_value is WorldContext:
		context = context_value
	else:
		context = null
		failures.append("Runtime cell definition context must be WorldGenerationContext")

	surface_sampler = SurfaceSampler.new(world_seed)
	cell_config = PartitionConfig.new()
	_base_regions.clear()
	_regions.clear()
	_cells.clear()
	if context != null:
		failures.append_array(context.validate())
		if int(context.world_seed) != world_seed:
			failures.append("Runtime cell definition world seed does not match supplied context")
	failures.append_array(cell_config.validate())
	return failures


func region_definition(region: Vector2i):
	if context == null or surface_sampler == null or cell_config == null:
		return StageResult.fail(
			"runtime_region_definition",
			["Runtime cell definition service is not configured"]
		)
	var key := _region_key(region)
	if _regions.has(key):
		var cached: Dictionary = _regions[key]
		return StageResult.ok(
			"runtime_region_definition",
			cached,
			str(cached.get("fingerprint", ""))
		)

	var base_result = _base_region(region)
	if not base_result.success:
		return StageResult.fail("runtime_region_definition", base_result.diagnostics)
	var base: Dictionary = base_result.data
	var macro = base["macro"]
	var topology = base["topology"]

	var entrances = EntranceGenerator.generate(context, macro, topology, surface_sampler)
	if not entrances.success:
		return StageResult.fail("runtime_region_definition", entrances.diagnostics)

	var neighbor_views: Array = []
	for offset in NEIGHBOR_OFFSETS:
		var neighbor_result = _base_region(region + offset)
		if not neighbor_result.success:
			return StageResult.fail("runtime_region_definition", neighbor_result.diagnostics)
		var neighbor: Dictionary = neighbor_result.data
		neighbor_views.append({
			"region_plan": neighbor["macro"],
			"primary_topology": neighbor["topology"],
		})

	var connectivity = ConnectivityGenerator.generate(
		context,
		macro,
		topology,
		entrances.data,
		neighbor_views
	)
	if not connectivity.success:
		return StageResult.fail("runtime_region_definition", connectivity.diagnostics)
	var hooks = HookGenerator.generate(context, macro, connectivity.data)
	if not hooks.success:
		return StageResult.fail("runtime_region_definition", hooks.diagnostics)
	var finalized = RegionFinalizer.generate(
		context,
		macro,
		entrances.data,
		connectivity.data,
		hooks.data
	)
	if not finalized.success:
		return StageResult.fail("runtime_region_definition", finalized.diagnostics)
	var geometry = GeometryGenerator.generate(
		context,
		macro,
		finalized.data,
		neighbor_views
	)
	if not geometry.success:
		return StageResult.fail("runtime_region_definition", geometry.diagnostics)
	var expected_sources: Array[String] = GeometryGenerator.expected_provenance_sources(
		macro,
		finalized.data,
		neighbor_views
	)
	if expected_sources.is_empty():
		return StageResult.fail(
			"runtime_region_definition",
			["Runtime region definition has no geometry provenance ancestry"]
		)

	var definition: Dictionary = {
		"region": region,
		"macro": macro,
		"topology": topology,
		"entrances": entrances.data,
		"entrance_fingerprint": entrances.fingerprint,
		"connectivity": connectivity.data,
		"hooks": hooks.data,
		"finalized": finalized.data,
		"geometry": geometry.data,
		"geometry_fingerprint": geometry.fingerprint,
		"neighbor_views": neighbor_views.duplicate(),
		"expected_geometry_sources": expected_sources.duplicate(),
		"fingerprint": "%s:%s:%s" % [
			base["fingerprint"],
			finalized.fingerprint,
			geometry.fingerprint,
		],
	}
	definition.make_read_only()
	_regions[key] = definition
	return StageResult.ok(
		"runtime_region_definition",
		definition,
		str(definition["fingerprint"])
	)


func cell_definition(address):
	if address == null or not (address is Address):
		return StageResult.fail(
			"runtime_cell_definition",
			["Runtime cell definition requires GeometryCellAddress"]
		)
	if not _address_is_definition_supported(address):
		return StageResult.fail(
			"runtime_cell_definition",
			[
				"Runtime cell address is outside the supported Underworld/entrance-transition envelope: "
				+ address.canonical_text()
			]
		)
	var key: String = address.canonical_text()
	if _cells.has(key):
		var cached: Dictionary = _cells[key]
		return StageResult.ok(
			"runtime_cell_definition",
			cached,
			str(cached.get("source_fingerprint", ""))
		)

	var region: Vector2i = region_for_address(address)
	var region_result = region_definition(region)
	if not region_result.success:
		return StageResult.fail("runtime_cell_definition", region_result.diagnostics)
	var region_data: Dictionary = region_result.data
	var request := PartitionRequest.new(
		region_data["geometry"],
		region_data["finalized"],
		cell_config,
		[address],
		context,
		region_data["expected_geometry_sources"]
	)
	var partition = Partitioner.generate(request)
	if not partition.success:
		return StageResult.fail("runtime_cell_definition", partition.diagnostics)
	if partition.data.plans.size() != 1:
		return StageResult.fail(
			"runtime_cell_definition",
			["Canonical one-cell partition did not return exactly one plan for " + key]
		)
	var plan = partition.data.plans[0]
	if plan == null or plan.cell_address.canonical_text() != key:
		return StageResult.fail(
			"runtime_cell_definition",
			["Canonical one-cell partition returned the wrong address for " + key]
		)
	if partition.provenance == null or str(partition.provenance.fingerprint).is_empty():
		return StageResult.fail(
			"runtime_cell_definition",
			["Canonical one-cell partition has no provenance for " + key]
		)

	var definition: Dictionary = {
		"cell_address": address,
		"region": region,
		"cell_plan": plan,
		"partition_result": partition.data,
		"provenance": partition.provenance,
		"source_fingerprint": plan.fingerprint,
		"provenance_fingerprint": partition.provenance.fingerprint,
		"region_fingerprint": region_data["fingerprint"],
	}
	definition.make_read_only()
	_cells[key] = definition
	return StageResult.ok(
		"runtime_cell_definition",
		definition,
		plan.fingerprint,
		partition.provenance
	)


func prune_to_addresses(addresses: Array) -> void:
	var keep_cells: Dictionary = {}
	var keep_regions: Dictionary = {}
	var keep_bases: Dictionary = {}
	for address in addresses:
		if (
			address == null
			or not (address is Address)
			or not _address_is_definition_supported(address)
		):
			continue
		keep_cells[address.canonical_text()] = true
		var region := region_for_address(address)
		keep_regions[_region_key(region)] = true
		keep_bases[_region_key(region)] = true
		for offset in NEIGHBOR_OFFSETS:
			keep_bases[_region_key(region + offset)] = true
	for key in _cells.keys().duplicate():
		if not keep_cells.has(str(key)):
			_cells.erase(key)
	for key in _regions.keys().duplicate():
		if not keep_regions.has(str(key)):
			_regions.erase(key)
	for key in _base_regions.keys().duplicate():
		if not keep_bases.has(str(key)):
			_base_regions.erase(key)


func cached_cell_count() -> int:
	return _cells.size()


func cached_region_count() -> int:
	return _regions.size()


func region_for_address(address) -> Vector2i:
	var cell_size: Vector3 = (
		cell_config.cell_size if cell_config != null else Vector3(32, 32, 32)
	)
	var world_x: float = float(address.coordinate.x) * cell_size.x
	var world_z: float = float(address.coordinate.z) * cell_size.z
	return Vector2i(
		floori(world_x / REGION_SIZE),
		floori(world_z / REGION_SIZE)
	)


func _base_region(region: Vector2i):
	var key := _region_key(region)
	if _base_regions.has(key):
		var cached: Dictionary = _base_regions[key]
		return StageResult.ok(
			"runtime_region_base",
			cached,
			str(cached.get("fingerprint", ""))
		)
	var macro_stage = MacroGenerator.generate(context, region)
	if not macro_stage.success:
		return StageResult.fail("runtime_region_base", macro_stage.diagnostics)
	var topology_stage = TopologyGenerator.generate(
		context,
		macro_stage.data,
		surface_sampler
	)
	if not topology_stage.success:
		return StageResult.fail("runtime_region_base", topology_stage.diagnostics)
	var data: Dictionary = {
		"region": region,
		"macro": macro_stage.data,
		"topology": topology_stage.data,
		"fingerprint": "%s:%s" % [
			macro_stage.fingerprint,
			topology_stage.fingerprint,
		],
	}
	data.make_read_only()
	_base_regions[key] = data
	return StageResult.ok(
		"runtime_region_base",
		data,
		str(data["fingerprint"])
	)


## Canonical definitions must cover the accepted surface->cave handoff volume.
## A handoff opening can overlap the y=0 cell, whose bounds are [0, cell_size.y),
## while ordinary observer streaming remains restricted by the controller to
## cells whose minimum Y is strictly below zero. This therefore admits exactly
## one transition layer above the underground volume, not general surface cells.
func _address_is_definition_supported(address) -> bool:
	var cell_size: Vector3 = (
		cell_config.cell_size if cell_config != null else Vector3(32, 32, 32)
	)
	var minimum_y: float = float(address.coordinate.y) * cell_size.y
	var maximum_y: float = minimum_y + cell_size.y
	return minimum_y <= UNDERWORLD_MAX_Y and maximum_y > UNDERWORLD_MIN_Y


static func _region_key(region: Vector2i) -> String:
	return "%d:%d" % [region.x, region.y]
