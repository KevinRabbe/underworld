extends RefCounted

const CatalogScript := preload("res://presentation/world/caves/cave_presentation_catalog.gd")
const ContextBuilder := preload("res://presentation/world/caves/cave_presentation_context.gd")
const Realizer := preload("res://presentation/world/caves/cave_presentation_realizer.gd")
const Controller := preload("res://presentation/world/caves/cave_presentation_controller.gd")
const RuntimeController := preload("res://worldgen/runtime/underworld_cave_runtime_controller.gd")
const CellAddress := preload("res://worldgen/geometry/geometry_cell_address.gd")
const Fragment := preload("res://worldgen/geometry/geometry_cell_fragment.gd")
const CellPlan := preload("res://worldgen/geometry/geometry_cell_plan.gd")
const CaveMeshData := preload("res://worldgen/geometry/cave_mesh_data.gd")
const MeshBoundary := preload("res://worldgen/geometry/cave_mesh_realization_boundary.gd")

const CATALOG_PATH := "res://content/presentation/caves/prototype_cave_presentation_catalog.tres"


static func run() -> Array[String]:
	var failures: Array[String] = []
	var catalog = ResourceLoader.load(CATALOG_PATH)
	if catalog == null or not catalog is CatalogScript:
		failures.append("prototype cave presentation catalog did not load as CavePresentationCatalog")
		return failures
	for failure in catalog.validate_catalog():
		failures.append("catalog validation: %s" % failure)
	if not failures.is_empty():
		return failures

	_test_authored_profile_resolution(catalog, failures)
	_test_source_identity_is_not_visual_identity(catalog, failures)
	_test_runtime_handoff_is_value_safe(catalog, failures)
	_test_double_sided_material_and_disposable_realization(catalog, failures)
	_test_controller_rebuild_without_plan(catalog, failures)
	return failures


static func _test_authored_profile_resolution(catalog, failures: Array[String]) -> void:
	var shallow_chamber := ContextBuilder.from_runtime_snapshot(_snapshot(_plan("chamber", "stable-a", -16.0)), "")
	var chamber_result: Dictionary = catalog.resolve(shallow_chamber)
	if str(chamber_result.get("profile_id", "")) != "presentation.cave.chamber":
		failures.append("shallow chamber did not resolve authored chamber presentation profile")

	var tunnel_result: Dictionary = catalog.resolve(ContextBuilder.from_runtime_snapshot(_snapshot(_plan("tunnel", "stable-t", -16.0)), ""))
	if str(tunnel_result.get("profile_id", "")) != "presentation.cave.tunnel":
		failures.append("tunnel did not resolve authored tunnel presentation profile")

	var entrance_plan = _plan("chamber", "stable-e", -64.0, true, false)
	var entrance_result: Dictionary = catalog.resolve(ContextBuilder.from_runtime_snapshot(_snapshot(entrance_plan), ""))
	if str(entrance_result.get("profile_id", "")) != "presentation.cave.entrance":
		failures.append("entrance presentation did not override deep/chamber presentation")

	var reserved_plan = _plan("chamber", "stable-r", -24.0, false, true)
	var reserved_result: Dictionary = catalog.resolve(ContextBuilder.from_runtime_snapshot(_snapshot(reserved_plan), ""))
	if str(reserved_result.get("profile_id", "")) != "presentation.cave.reserved_site":
		failures.append("reserved-site volume did not resolve authored presentation profile")

	var deep_result: Dictionary = catalog.resolve(ContextBuilder.from_runtime_snapshot(_snapshot(_plan("chamber", "stable-d", -80.0)), ""))
	if str(deep_result.get("profile_id", "")) != "presentation.cave.deep":
		failures.append("deep cave context did not select authored depth variation")

	var basalt_result: Dictionary = catalog.resolve(ContextBuilder.from_runtime_snapshot(_snapshot(_plan("chamber", "stable-b", -16.0)), "basalt"))
	if str(basalt_result.get("profile_id", "")) != "presentation.cave.biome.basalt":
		failures.append("biome context did not select authored basalt presentation variation")


static func _test_source_identity_is_not_visual_identity(catalog, failures: Array[String]) -> void:
	var first_snapshot: Dictionary = _snapshot(_plan("chamber", "stable-source-alpha", -16.0))
	var second_snapshot: Dictionary = _snapshot(_plan("chamber", "stable-source-beta", -16.0))
	if first_snapshot != second_snapshot:
		failures.append("runtime semantic snapshot leaked source descriptor identity")
	for forbidden_key in ["stable_id", "stable_address", "source_descriptor_id", "fragment_id", "source_fingerprint", "provenance_fingerprint"]:
		if first_snapshot.has(forbidden_key):
			failures.append("runtime semantic snapshot exposed authoritative identity key: %s" % forbidden_key)
	var first_context: Dictionary = ContextBuilder.from_runtime_snapshot(first_snapshot, "")
	var second_context: Dictionary = ContextBuilder.from_runtime_snapshot(second_snapshot, "")
	if first_context != second_context:
		failures.append("presentation context changed when only source descriptor identity changed")
	var first_profile: String = str(catalog.resolve(first_context).get("profile_id", ""))
	var second_profile: String = str(catalog.resolve(second_context).get("profile_id", ""))
	if first_profile != second_profile:
		failures.append("changing source StableId/descriptor identity changed cave presentation profile")


static func _test_runtime_handoff_is_value_safe(catalog, failures: Array[String]) -> void:
	var plan = _plan("entrance", "stable-runtime-handoff", -16.0, true, false)
	var snapshot: Dictionary = _snapshot(plan)
	if snapshot.is_empty():
		failures.append("runtime semantic snapshot was empty for a populated cell plan")
		return
	if not snapshot.is_read_only():
		failures.append("runtime semantic snapshot was not immutable/read-only")
	var source_kinds = snapshot.get("source_kinds", [])
	var tags = snapshot.get("tags", [])
	if not source_kinds is Array or not source_kinds.is_read_only():
		failures.append("runtime semantic snapshot source kinds were not read-only values")
	if not tags is Array or not tags.is_read_only():
		failures.append("runtime semantic snapshot tags were not read-only values")
	if not _value_tree_is_serialization_safe(snapshot):
		failures.append("runtime semantic snapshot retained Object/RefCounted/Node/RID/callable authority")

	var runtime = RuntimeController.new()
	runtime.configure("world:presentation", "manifest:presentation")
	var mesh_data = _mesh_data()
	runtime.streamer.demand_cell(mesh_data.cell_address, "presentation:test", ["render"], "source:test", "provenance:test")
	if not runtime.accept_mesh_data(mesh_data, null, snapshot):
		failures.append("runtime controller rejected cave mesh with compact semantic snapshot")
		runtime.free()
		return
	var key: String = mesh_data.cell_address.canonical_text()
	var render_node = runtime.render_nodes.get(key, null)
	if render_node == null:
		failures.append("runtime controller did not expose accepted render node")
		runtime.free()
		return
	if render_node.has_meta("source_cell_plan"):
		failures.append("render node still retained the authoritative GeometryCellPlan")
	var stored_snapshot: Dictionary = render_node.get_meta("cell_semantic_snapshot", {})
	if stored_snapshot.is_empty() or not stored_snapshot.is_read_only():
		failures.append("render node did not retain an immutable compact semantic snapshot")
	if not _value_tree_is_serialization_safe(stored_snapshot):
		failures.append("render-node semantic handoff contained non-value runtime authority")

	# Drop the authoritative plan and runtime node graph. The retained semantic
	# value snapshot must still be sufficient to rebuild presentation elsewhere.
	plan = null
	runtime.free()
	var controller = Controller.new()
	var configure_failures: Array[String] = controller.configure(null, catalog)
	if not configure_failures.is_empty():
		failures.append("presentation controller rejected valid catalog after plan release: %s" % [configure_failures])
		controller.free()
		return
	var rebuilt_node := MeshInstance3D.new()
	rebuilt_node.mesh = ArrayMesh.new()
	var rebuilt: Dictionary = controller.apply_to_render_node(rebuilt_node, stored_snapshot)
	if str(rebuilt.get("profile_id", "")) != "presentation.cave.entrance":
		failures.append("presentation could not rebuild from semantic snapshot after GeometryCellPlan release")
	rebuilt_node.free()
	controller.free()


static func _test_double_sided_material_and_disposable_realization(catalog, failures: Array[String]) -> void:
	var mesh_data = _mesh_data()
	var original_output_fingerprint: String = mesh_data.output_fingerprint
	var realized_mesh: Dictionary = MeshBoundary.realize_main_thread(mesh_data, null, mesh_data.input_fingerprint)
	if not bool(realized_mesh.get("success", false)):
		failures.append("test cave mesh failed accepted realization boundary")
		return
	var mesh_node := MeshInstance3D.new()
	mesh_node.mesh = realized_mesh.get("mesh")
	var original_mesh = mesh_node.mesh
	var chamber_profile = catalog.profile_by_id("presentation.cave.chamber")
	var first: Dictionary = Realizer.realize(mesh_node, chamber_profile, ContextBuilder.default_context())
	if not first.get("diagnostics", []).is_empty():
		failures.append("valid cave presentation realization failed: %s" % [first.get("diagnostics", [])])
		return
	var material = first.get("material", null)
	if material == null or not material is StandardMaterial3D:
		failures.append("cave presentation did not create StandardMaterial3D")
	elif material.cull_mode != BaseMaterial3D.CULL_DISABLED:
		failures.append("cave presentation material did not disable culling for exterior/backside readability")
	if mesh_data.output_fingerprint != original_output_fingerprint:
		failures.append("presentation material changed deterministic cave mesh fingerprint")
	if mesh_node.mesh != original_mesh:
		failures.append("presentation realization replaced authoritative cave mesh geometry")

	var first_attachment = first.get("attachment", null)
	var first_attachment_id: int = first_attachment.get_instance_id() if first_attachment != null else 0
	var entrance_profile = catalog.profile_by_id("presentation.cave.entrance")
	var second: Dictionary = Realizer.realize(mesh_node, entrance_profile, {"volume_kind": "entrance", "world_bounds": AABB(Vector3.ZERO, Vector3(32, 32, 32))})
	if str(second.get("profile_id", "")) != "presentation.cave.entrance":
		failures.append("re-realization did not switch disposable presentation profile")
	var second_attachment = second.get("attachment", null)
	if second_attachment == null or second_attachment.get_instance_id() == first_attachment_id:
		failures.append("presentation re-realization did not rebuild disposable attachment")
	elif second_attachment.has_meta("stable_id") or second_attachment.has_meta("stable_address"):
		failures.append("presentation attachment incorrectly owns durable world identity")
	if mesh_data.output_fingerprint != original_output_fingerprint or mesh_node.mesh != original_mesh:
		failures.append("presentation rebuild changed deterministic cave geometry identity")
	mesh_node.free()


static func _test_controller_rebuild_without_plan(catalog, failures: Array[String]) -> void:
	var controller = Controller.new()
	var configure_failures: Array[String] = controller.configure(null, catalog)
	if not configure_failures.is_empty():
		failures.append("presentation controller rejected valid catalog: %s" % [configure_failures])
		controller.free()
		return
	var plan = _plan("entrance", "stable-controller-a", -16.0, true, false)
	var snapshot: Dictionary = _snapshot(plan)
	plan = null
	var first_node := MeshInstance3D.new()
	first_node.mesh = ArrayMesh.new()
	var first: Dictionary = controller.apply_to_render_node(first_node, snapshot)
	if str(first.get("profile_id", "")) != "presentation.cave.entrance":
		failures.append("presentation controller did not resolve entrance profile from semantic snapshot")
	first_node.free()

	var second_node := MeshInstance3D.new()
	second_node.mesh = ArrayMesh.new()
	var second: Dictionary = controller.apply_to_render_node(second_node, snapshot)
	if str(second.get("profile_id", "")) != "presentation.cave.entrance":
		failures.append("presentation could not rebuild after disposable render-node recreation")
	var attachment = second.get("attachment", null)
	if attachment == null or not bool(attachment.get_meta("presentation_only", false)):
		failures.append("rebuilt cave presentation attachment was not marked presentation-only")
	second_node.free()
	controller.free()


static func _snapshot(plan) -> Dictionary:
	return RuntimeController.build_cell_semantic_snapshot(plan)


static func _value_tree_is_serialization_safe(value) -> bool:
	var value_type: int = typeof(value)
	if value_type == TYPE_OBJECT or value_type == TYPE_RID or value_type == TYPE_CALLABLE or value_type == TYPE_SIGNAL:
		return false
	if value_type == TYPE_DICTIONARY:
		for key in value.keys():
			if not _value_tree_is_serialization_safe(key) or not _value_tree_is_serialization_safe(value[key]):
				return false
	elif value_type == TYPE_ARRAY:
		for entry in value:
			if not _value_tree_is_serialization_safe(entry):
				return false
	return true


static func _plan(
	source_kind: String,
	source_descriptor_id: String,
	center_y: float,
	has_entrance: bool = false,
	has_reserved_site: bool = false
):
	var address = CellAddress.new(Vector3i(0, int(floor(center_y / 32.0)), 0))
	var bounds := AABB(Vector3(0.0, center_y - 16.0, 0.0), Vector3(32.0, 32.0, 32.0))
	var fragment = Fragment.new(
		"fragment.test",
		source_descriptor_id,
		source_kind,
		address,
		bounds,
		bounds,
		true,
		{},
		{},
		"source-fingerprint",
		{"tags": ["readable"]}
	)
	var entrance_metadata: Array = [{"entrance_id": "entrance.test"}] if has_entrance else []
	var reserved_metadata: Array = [{"site_id": "site.test"}] if has_reserved_site else []
	return CellPlan.new(address, [fragment], entrance_metadata, reserved_metadata, "geometry-source", "finalization-source", {}, [])


static func _mesh_data():
	var address = CellAddress.new(Vector3i.ZERO)
	return CaveMeshData.new(
		address,
		AABB(Vector3.ZERO, Vector3.ONE),
		PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.FORWARD]),
		PackedInt32Array([0, 1, 2]),
		PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP]),
		PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.UP]),
		["descriptor.test"],
		["fragment.test"],
		"mesh-input:test"
	)
