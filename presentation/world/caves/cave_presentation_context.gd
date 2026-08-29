extends RefCounted
class_name UnderworldCavePresentationContext

const KIND_PRECEDENCE: Array[String] = ["entrance", "reserved_site", "chamber", "tunnel"]


## Converts the compact runtime semantic handoff into presentation-selection
## context. The snapshot must contain values only; presentation never needs the
## authoritative GeometryCellPlan or fragment objects after realization.
static func from_runtime_snapshot(snapshot: Dictionary, biome_id: String = "") -> Dictionary:
	var source_kinds: Array[String] = []
	var raw_source_kinds = snapshot.get("source_kinds", [])
	if raw_source_kinds is Array:
		for raw_kind in raw_source_kinds:
			var source_kind := str(raw_kind)
			if not source_kind.is_empty() and not source_kinds.has(source_kind):
				source_kinds.append(source_kind)
	var tags: Array[String] = []
	var raw_tags = snapshot.get("tags", [])
	if raw_tags is Array:
		for raw_tag in raw_tags:
			var tag := str(raw_tag)
			if not tag.is_empty() and not tags.has(tag):
				tags.append(tag)
	source_kinds.sort()
	tags.sort()

	var volume_kind := "default"
	if bool(snapshot.get("has_entrance", false)):
		volume_kind = "entrance"
	elif bool(snapshot.get("has_reserved_site", false)):
		volume_kind = "reserved_site"
	else:
		for candidate in KIND_PRECEDENCE:
			if source_kinds.has(candidate):
				volume_kind = candidate
				break

	var bounds: AABB = snapshot.get("world_bounds", AABB())
	var depth := 0.0
	if bounds.size.length_squared() > 0.0:
		depth = maxf(0.0, -bounds.get_center().y)
	return {
		"volume_kind": volume_kind,
		"source_kinds": source_kinds,
		"depth": depth,
		"biome_id": biome_id,
		"tags": tags,
		"world_bounds": bounds,
	}


static func default_context(biome_id: String = "") -> Dictionary:
	return from_runtime_snapshot({}, biome_id)
