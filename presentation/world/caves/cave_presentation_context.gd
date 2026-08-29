extends RefCounted
class_name UnderworldCavePresentationContext

const KIND_PRECEDENCE: Array[String] = ["entrance", "reserved_site", "chamber", "tunnel"]


static func from_cell_plan(plan, biome_id: String = "") -> Dictionary:
	if plan == null:
		return default_context(biome_id)
	var source_kinds: Array[String] = []
	var tags: Array[String] = []
	var bounds := AABB()
	var has_bounds := false
	for fragment in plan.fragments:
		if fragment == null:
			continue
		var source_kind: String = str(fragment.source_kind)
		if not source_kinds.has(source_kind):
			source_kinds.append(source_kind)
		if not has_bounds:
			bounds = fragment.cell_bounds
			has_bounds = true
		var fragment_tags = fragment.metadata.get("tags", [])
		if fragment_tags is Array:
			for raw_tag in fragment_tags:
				var tag := str(raw_tag)
				if not tag.is_empty() and not tags.has(tag):
					tags.append(tag)
	source_kinds.sort()
	tags.sort()

	var volume_kind := "default"
	if not plan.entrance_opening_metadata.is_empty():
		volume_kind = "entrance"
	elif not plan.reserved_site_metadata.is_empty():
		volume_kind = "reserved_site"
	else:
		for candidate in KIND_PRECEDENCE:
			if source_kinds.has(candidate):
				volume_kind = candidate
				break

	var depth := 0.0
	if has_bounds:
		depth = maxf(0.0, -bounds.get_center().y)
	return {
		"volume_kind": volume_kind,
		"source_kinds": source_kinds,
		"depth": depth,
		"biome_id": biome_id,
		"tags": tags,
		"world_bounds": bounds if has_bounds else AABB(),
	}


static func default_context(biome_id: String = "") -> Dictionary:
	return {
		"volume_kind": "default",
		"source_kinds": [],
		"depth": 0.0,
		"biome_id": biome_id,
		"tags": [],
		"world_bounds": AABB(),
	}
