extends RefCounted
class_name UndergroundResourceCompositionService

const AssignmentService := preload("res://content/reserved_sites/reserved_site_assignment_service.gd")
const PlacementService := preload("res://content/placement/underground_placement_service.gd")
const Catalog := preload("res://gameplay/resources/runtime/underground_resource_composition_catalog.gd")
const ContentEvidence := preload("res://gameplay/resources/runtime/underground_resource_content_evidence.gd")
const CellObserver := preload("res://gameplay/resources/runtime/underworld_resource_cell_observer.gd")


static func plan_current_cell(controller, address, content_authority: Dictionary) -> Dictionary:
	var snapshot: Dictionary = CellObserver.current_snapshot(controller, address)
	if snapshot.is_empty():
		return _failure(["resource composition requires a current render-ready cell snapshot"])

	var result: Dictionary = plan_snapshot(snapshot, content_authority)
	if not bool(result.get("success", false)):
		return result

	# Assignment/placement planning is deterministic but not authoritative if the
	# streamed cell changed while it ran. Never publish records from an old cell
	# incarnation, source fingerprint or provenance fingerprint.
	if not CellObserver.snapshot_is_current(controller, snapshot):
		return _failure(["resource composition snapshot became stale during planning"])

	result["snapshot"] = snapshot.duplicate(true)
	return result


static func plan_snapshot(snapshot: Dictionary, content_authority: Dictionary) -> Dictionary:
	var failures: Array[String] = []
	if snapshot.is_empty():
		return _failure(["resource composition requires a detached cell snapshot"])

	var region_variant = snapshot.get("region_coord", null)
	if not region_variant is Vector2i:
		failures.append("resource composition snapshot requires Vector2i region_coord")

	for failure in ContentEvidence.verification_failures(content_authority):
		failures.append("content authority: %s" % failure)
	var content_registry = content_authority.get("content_registry", null)

	var sites_variant = snapshot.get("owner_reserved_sites", null)
	if not sites_variant is Array:
		failures.append("resource composition snapshot requires owner_reserved_sites")
		return _failure(failures)

	var hooks: Array = []
	for site_variant in sites_variant:
		if not site_variant is Dictionary:
			failures.append("resource composition owner site must be a Dictionary")
			continue
		var site: Dictionary = site_variant
		if str(site.get("source_kind", "")) != "reserved_site" or not bool(site.get("is_owner", false)):
			failures.append("resource composition received a non-owner reserved-site fragment")
			continue
		var metadata_variant = site.get("metadata", null)
		if not metadata_variant is Dictionary:
			failures.append("resource composition owner site requires detached metadata")
			continue
		var metadata: Dictionary = metadata_variant
		var stable_id_variant = metadata.get("stable_id", null)
		var semantic_category_variant = metadata.get("semantic_category", null)
		var bounds_variant = metadata.get("reserved_bounds", null)
		var profile_variant = metadata.get("profile_blend", null)
		if not stable_id_variant is String or stable_id_variant.is_empty():
			failures.append("resource composition owner site requires metadata stable_id")
			continue
		if not semantic_category_variant is String or semantic_category_variant.is_empty():
			failures.append("resource composition owner site requires metadata semantic_category")
			continue
		if typeof(bounds_variant) != TYPE_AABB:
			failures.append("resource composition owner site requires metadata reserved_bounds")
			continue
		if typeof(profile_variant) != TYPE_VECTOR3:
			failures.append("resource composition owner site requires metadata profile_blend")
			continue
		# Preserve the accepted generated-hook payload as the assignment hook. The
		# source descriptor and clipped cell fragment remain provenance only; they
		# must not replace the generated site's StableId or full reserved bounds.
		hooks.append(metadata.duplicate(true))

	if not failures.is_empty():
		return _failure(failures)
	if hooks.is_empty():
		return _success([], [], [], [])

	var assignment_result: Dictionary = AssignmentService.assign(
		hooks,
		Catalog.reserved_site_definitions(),
		Catalog.RULEBOOK_REVISION
	)
	if not bool(assignment_result.get("success", false)):
		for diagnostic in assignment_result.get("diagnostics", []):
			failures.append("assignment: %s" % str(diagnostic))
		return _failure(failures)

	var assignments: Array = assignment_result.get("assignments", [])
	var candidates: Array = []
	for assignment in assignments:
		# No accepted production depth-band taxonomy exists yet. Keep depth_band
		# neutral and let generated profile_blend own depth-sensitive eligibility.
		var candidate = Catalog.candidate_from_assignment(assignment, region_variant, 0)
		if candidate == null:
			failures.append("resource assignment could not adapt to the resource placement channel")
			continue
		candidates.append(candidate)
	if not failures.is_empty():
		return _failure(failures)

	var placement_result: Dictionary = PlacementService.plan(
		candidates,
		Catalog.placement_policies(),
		content_registry,
		Catalog.RULEBOOK_REVISION
	)
	if not bool(placement_result.get("success", false)):
		for diagnostic in placement_result.get("diagnostics", []):
			failures.append("placement: %s" % str(diagnostic))
		return _failure(failures)

	return _success(
		hooks,
		assignments,
		candidates,
		placement_result.get("placements", [])
	)


static func _success(hooks: Array, assignments: Array, candidates: Array, placements: Array) -> Dictionary:
	return {
		"success": true,
		"hooks": hooks.duplicate(true),
		"assignments": assignments.duplicate(),
		"candidates": candidates.duplicate(),
		"placements": placements.duplicate(),
		"diagnostics": [],
	}


static func _failure(failures: Array) -> Dictionary:
	var diagnostics: Array[String] = []
	for failure in failures:
		diagnostics.append(str(failure))
	diagnostics.sort()
	return {
		"success": false,
		"hooks": [],
		"assignments": [],
		"candidates": [],
		"placements": [],
		"diagnostics": diagnostics,
	}
