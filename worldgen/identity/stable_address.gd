extends RefCounted
class_name UnderworldStableAddress

## Canonical deterministic semantic address for generated world candidates.
##
## Format is deliberately readable and project-owned:
##   sa1|7:surface|4:tree|4:cell|3:401|3:-73|4:slot|1:0
##
## Each segment is length-prefixed, so nested canonical addresses can be used
## as semantic components without relying on escaping rules.

const SCHEMA_VERSION: int = 1
const SCHEMA_PREFIX: String = "sa1"

var _segments: Array[String] = []


func _init(segments: Array = []) -> void:
	for value in segments:
		_segments.append(str(value))


static func from_segments(segments: Array):
	var normalized: Array[String] = []
	for value in segments:
		var segment: String = str(value)
		if not _is_valid_segment(segment):
			return null
		normalized.append(segment)
	return UnderworldStableAddress.new(normalized)


static func parse(canonical_text: String):
	if canonical_text == SCHEMA_PREFIX:
		return UnderworldStableAddress.new([])
	if not canonical_text.begins_with(SCHEMA_PREFIX + "|"):
		return null

	var cursor: int = SCHEMA_PREFIX.length()
	var parsed_segments: Array[String] = []

	while cursor < canonical_text.length():
		if canonical_text.substr(cursor, 1) != "|":
			return null
		cursor += 1

		var colon: int = canonical_text.find(":", cursor)
		if colon < 0:
			return null

		var length_text: String = canonical_text.substr(cursor, colon - cursor)
		if length_text.is_empty() or not length_text.is_valid_int():
			return null

		var segment_length: int = int(length_text)
		if segment_length <= 0 or str(segment_length) != length_text:
			return null

		var segment_start: int = colon + 1
		if segment_start + segment_length > canonical_text.length():
			return null

		var segment: String = canonical_text.substr(segment_start, segment_length)
		if not _is_valid_segment(segment):
			return null

		parsed_segments.append(segment)
		cursor = segment_start + segment_length

	var address = UnderworldStableAddress.new(parsed_segments)
	# Parser accepts only the one canonical representation.
	if address.canonical_text() != canonical_text:
		return null
	return address


func canonical_text() -> String:
	var result: String = SCHEMA_PREFIX
	for segment in _segments:
		result += "|%d:%s" % [segment.length(), segment]
	return result


func debug_text() -> String:
	return canonical_text()


func segments() -> Array[String]:
	var copy: Array[String] = []
	for segment in _segments:
		copy.append(segment)
	return copy


func child(additional_segments: Array):
	var combined: Array[String] = segments()
	for value in additional_segments:
		var segment: String = str(value)
		if not _is_valid_segment(segment):
			return null
		combined.append(segment)
	return UnderworldStableAddress.new(combined)


func equals(other) -> bool:
	return other != null and canonical_text() == other.canonical_text()


func less_than(other) -> bool:
	if other == null:
		return false
	return canonical_text() < other.canonical_text()


func has_prefix(prefix_segments: Array) -> bool:
	if prefix_segments.size() > _segments.size():
		return false
	for index in range(prefix_segments.size()):
		if _segments[index] != str(prefix_segments[index]):
			return false
	return true


# -----------------------------------------------------------------------------
# Semantic factories. Candidate slots exist before acceptance; none of these
# factories use accepted-array indexes or runtime object order.
# -----------------------------------------------------------------------------

static func surface_candidate(
	candidate_domain: String,
	global_cell_x: int,
	global_cell_z: int,
	slot_key: String
):
	return from_segments([
		"surface",
		"candidate",
		candidate_domain,
		"cell",
		str(global_cell_x),
		str(global_cell_z),
		"slot",
		slot_key,
	])


static func underground_region(region_x: int, region_z: int):
	return from_segments([
		"ug",
		"region",
		str(region_x),
		str(region_z),
	])


static func network(region_address, candidate_slot: int):
	if region_address == null or candidate_slot < 0:
		return null
	return region_address.child(["network", "slot", str(candidate_slot)])


static func node(network_address, lineage_slots: Array = []):
	if network_address == null:
		return null
	var additions: Array[String] = ["node", "root"]
	for slot_variant in lineage_slots:
		var slot: int = int(slot_variant)
		if slot < 0:
			return null
		additions.append("slot")
		additions.append(str(slot))
	return network_address.child(additions)


static func primary_edge(
	network_address,
	endpoint_a,
	endpoint_b,
	candidate_slot: int
):
	if network_address == null or endpoint_a == null or endpoint_b == null or candidate_slot < 0:
		return null
	var endpoints: Array[String] = _canonical_endpoint_pair(endpoint_a, endpoint_b)
	return network_address.child([
		"edge",
		"primary",
		"a",
		endpoints[0],
		"b",
		endpoints[1],
		"slot",
		str(candidate_slot),
	])


static func entrance(region_address, candidate_slot: int):
	if region_address == null or candidate_slot < 0:
		return null
	return region_address.child(["entrance", "slot", str(candidate_slot)])


static func secondary_connector(
	owner_region_address,
	endpoint_a,
	endpoint_b,
	connector_class: String,
	candidate_slot: int
):
	if (
		owner_region_address == null
		or endpoint_a == null
		or endpoint_b == null
		or candidate_slot < 0
	):
		return null
	var endpoints: Array[String] = _canonical_endpoint_pair(endpoint_a, endpoint_b)
	return owner_region_address.child([
		"secondary-edge",
		connector_class,
		"a",
		endpoints[0],
		"b",
		endpoints[1],
		"slot",
		str(candidate_slot),
	])


static func special_location(parent_address, kind: String, candidate_slot: int):
	if parent_address == null or candidate_slot < 0:
		return null
	return parent_address.child([
		"special",
		kind,
		"slot",
		str(candidate_slot),
	])


static func generated_child(parent_address, kind: String, candidate_slot: int):
	if parent_address == null or candidate_slot < 0:
		return null
	return parent_address.child([
		"child",
		kind,
		"slot",
		str(candidate_slot),
	])


static func canonical_owner(address_a, address_b):
	if address_a == null:
		return address_b
	if address_b == null:
		return address_a
	if address_a.canonical_text() <= address_b.canonical_text():
		return address_a
	return address_b


static func _canonical_endpoint_pair(endpoint_a, endpoint_b) -> Array[String]:
	var a: String = endpoint_a.canonical_text()
	var b: String = endpoint_b.canonical_text()
	if a <= b:
		return [a, b]
	return [b, a]


static func _is_valid_segment(segment: String) -> bool:
	if segment.is_empty():
		return false
	# Procedural semantic tokens are intentionally ASCII-only. This avoids
	# Unicode normalization becoming part of persistent identity semantics.
	for index in range(segment.length()):
		var codepoint: int = segment.unicode_at(index)
		if codepoint < 33 or codepoint > 126:
			return false
	return true
