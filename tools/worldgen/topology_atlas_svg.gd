extends RefCounted
class_name UnderworldTopologyAtlasSvg

const CELL_SIZE: float = 250.0
const CELL_PADDING: float = 18.0
const OUTER_MARGIN: float = 34.0
const HEADER_HEIGHT: float = 82.0
const FOOTER_HEIGHT: float = 58.0
const NETWORK_COLORS: Array[String] = [
	"#2f6f9f",
	"#9a5b2f",
	"#5c7f3b",
	"#7b4f92",
	"#9b7133",
	"#3f7f78",
]


static func render(atlas: Dictionary) -> String:
	var grid_size: Array = atlas.get("grid_size", [1, 1])
	var columns: int = maxi(int(grid_size[0]), 1)
	var rows: int = maxi(int(grid_size[1]), 1)
	var width: float = OUTER_MARGIN * 2.0 + float(columns) * CELL_SIZE
	var height: float = HEADER_HEIGHT + float(rows) * CELL_SIZE + FOOTER_HEIGHT
	var regions: Array = atlas.get("regions", [])
	var center: Array = atlas.get("center_region", [0, 0])
	var totals: Dictionary = atlas.get("totals", {})

	var parts := PackedStringArray()
	parts.append("<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
	parts.append("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%s\" height=\"%s\" viewBox=\"0 0 %s %s\">" % [
		_num(width), _num(height), _num(width), _num(height),
	])
	parts.append("<rect x=\"0\" y=\"0\" width=\"100%%\" height=\"100%%\" fill=\"#101419\"/>")
	parts.append("<text x=\"%s\" y=\"30\" fill=\"#f2f4f7\" font-family=\"monospace\" font-size=\"18\">Underworld topology atlas</text>" % _num(OUTER_MARGIN))
	parts.append("<text x=\"%s\" y=\"51\" fill=\"#aab4c0\" font-family=\"monospace\" font-size=\"11\">seed=%s center=(%s,%s) radius=%s regions=%s nodes=%s edges=%s boundaries=%s</text>" % [
		_num(OUTER_MARGIN),
		_xml(str(atlas.get("world_seed", 0))),
		_xml(str(center[0])),
		_xml(str(center[1])),
		_xml(str(atlas.get("radius", 0))),
		_xml(str(totals.get("region_count", 0))),
		_xml(str(totals.get("node_count", 0))),
		_xml(str(totals.get("edge_count", 0))),
		_xml(str(totals.get("boundary_candidate_count", 0))),
	])
	parts.append("<text x=\"%s\" y=\"69\" fill=\"#778491\" font-family=\"monospace\" font-size=\"9\">node fill: shallow / mid / deep · dashed tunnel: vertical transition · cyan tick: boundary candidate</text>" % _num(OUTER_MARGIN))

	for index in range(regions.size()):
		var row: int = index / columns
		var column: int = index % columns
		_append_region(parts, regions[index], column, row)

	var footer_y: float = HEADER_HEIGHT + float(rows) * CELL_SIZE + 28.0
	parts.append("<circle cx=\"%s\" cy=\"%s\" r=\"5\" fill=\"#dce9ca\"/><text x=\"%s\" y=\"%s\" fill=\"#b7c0ca\" font-family=\"monospace\" font-size=\"10\">shallow</text>" % [
		_num(OUTER_MARGIN), _num(footer_y), _num(OUTER_MARGIN + 12.0), _num(footer_y + 3.0),
	])
	parts.append("<circle cx=\"%s\" cy=\"%s\" r=\"5\" fill=\"#cfdfef\"/><text x=\"%s\" y=\"%s\" fill=\"#b7c0ca\" font-family=\"monospace\" font-size=\"10\">mid</text>" % [
		_num(OUTER_MARGIN + 92.0), _num(footer_y), _num(OUTER_MARGIN + 104.0), _num(footer_y + 3.0),
	])
	parts.append("<circle cx=\"%s\" cy=\"%s\" r=\"5\" fill=\"#dccfea\"/><text x=\"%s\" y=\"%s\" fill=\"#b7c0ca\" font-family=\"monospace\" font-size=\"10\">deep</text>" % [
		_num(OUTER_MARGIN + 158.0), _num(footer_y), _num(OUTER_MARGIN + 170.0), _num(footer_y + 3.0),
	])
	parts.append("</svg>")
	return "\n".join(parts) + "\n"


static func _append_region(parts: PackedStringArray, snapshot: Dictionary, column: int, row: int) -> void:
	var region: Dictionary = snapshot.get("region", {})
	var coord: Array = region.get("coord", [0, 0])
	var bounds: Dictionary = region.get("world_bounds", {})
	var bounds_position: Array = bounds.get("position", [0.0, 0.0, 0.0])
	var bounds_size: Array = bounds.get("size", [1.0, 1.0, 1.0])
	var min_x: float = float(bounds_position[0])
	var min_z: float = float(bounds_position[2])
	var size_x: float = maxf(float(bounds_size[0]), 1.0)
	var size_z: float = maxf(float(bounds_size[2]), 1.0)
	var origin_x: float = OUTER_MARGIN + float(column) * CELL_SIZE
	var origin_y: float = HEADER_HEIGHT + float(row) * CELL_SIZE
	var frame_x: float = origin_x + 2.0
	var frame_y: float = origin_y + 2.0
	var frame_size: float = CELL_SIZE - 4.0
	var nodes: Array = snapshot.get("nodes", [])
	var edges: Array = snapshot.get("edges", [])
	var networks: Array = snapshot.get("networks", [])
	var boundaries: Array = snapshot.get("boundary_candidates", [])

	parts.append("<g class=\"region-cell\" data-region=\"%s,%s\">" % [_xml(str(coord[0])), _xml(str(coord[1]))])
	parts.append("<rect class=\"region-frame\" x=\"%s\" y=\"%s\" width=\"%s\" height=\"%s\" fill=\"#171d24\" stroke=\"#596675\" stroke-width=\"1.5\"/>" % [
		_num(frame_x), _num(frame_y), _num(frame_size), _num(frame_size),
	])
	parts.append("<text x=\"%s\" y=\"%s\" fill=\"#d9e0e8\" font-family=\"monospace\" font-size=\"10\">region (%s,%s) · n=%s e=%s</text>" % [
		_num(origin_x + 10.0),
		_num(origin_y + 15.0),
		_xml(str(coord[0])),
		_xml(str(coord[1])),
		_xml(str(nodes.size())),
		_xml(str(edges.size())),
	])

	var node_lookup: Dictionary = {}
	for node in nodes:
		node_lookup[str(node.get("stable_id", ""))] = node
	var network_color: Dictionary = {}
	for network_index in range(networks.size()):
		var network: Dictionary = networks[network_index]
		network_color[str(network.get("stable_id", ""))] = NETWORK_COLORS[network_index % NETWORK_COLORS.size()]

	for edge in edges:
		var a_id: String = str(edge.get("endpoint_a_node_id", ""))
		var b_id: String = str(edge.get("endpoint_b_node_id", ""))
		if not node_lookup.has(a_id) or not node_lookup.has(b_id):
			continue
		var a: Dictionary = node_lookup[a_id]
		var b: Dictionary = node_lookup[b_id]
		var a_pos: Vector2 = _project(a.get("world_position", [0.0, 0.0, 0.0]), min_x, min_z, size_x, size_z, origin_x, origin_y)
		var b_pos: Vector2 = _project(b.get("world_position", [0.0, 0.0, 0.0]), min_x, min_z, size_x, size_z, origin_x, origin_y)
		var stroke: String = str(network_color.get(str(a.get("owning_network_id", "")), "#99a4af"))
		var dashed: String = " stroke-dasharray=\"5 4\"" if str(edge.get("connection_class", "")) == "vertical_transition" else ""
		parts.append("<line x1=\"%s\" y1=\"%s\" x2=\"%s\" y2=\"%s\" stroke=\"%s\" stroke-width=\"1.7\" opacity=\"0.8\"%s/>" % [
			_num(a_pos.x), _num(a_pos.y), _num(b_pos.x), _num(b_pos.y), stroke, dashed,
		])

	for node in nodes:
		var position: Array = node.get("world_position", [0.0, 0.0, 0.0])
		var projected: Vector2 = _project(position, min_x, min_z, size_x, size_z, origin_x, origin_y)
		var profile: Array = node.get("profile_blend", [1.0, 0.0, 0.0])
		var semantic: String = str(node.get("semantic_type", "node"))
		var radius: float = 3.4
		if semantic == "junction":
			radius = 4.7
		elif semantic == "terminal":
			radius = 2.7
		var stroke: String = str(network_color.get(str(node.get("owning_network_id", "")), "#d3d8de"))
		parts.append("<circle cx=\"%s\" cy=\"%s\" r=\"%s\" fill=\"%s\" stroke=\"%s\" stroke-width=\"1.2\"><title>%s | y=%s | %s</title></circle>" % [
			_num(projected.x),
			_num(projected.y),
			_num(radius),
			_profile_fill(profile),
			stroke,
			_xml(str(node.get("stable_id", ""))),
			_num(float(position[1])),
			_xml(semantic),
		])

	for candidate in boundaries:
		var node_id: String = str(candidate.get("node_id", ""))
		if not node_lookup.has(node_id):
			continue
		var source: Dictionary = node_lookup[node_id]
		var projected: Vector2 = _project(source.get("world_position", [0.0, 0.0, 0.0]), min_x, min_z, size_x, size_z, origin_x, origin_y)
		var delta: Vector2 = _boundary_direction(str(candidate.get("side", ""))) * 8.0
		parts.append("<line class=\"boundary-candidate\" x1=\"%s\" y1=\"%s\" x2=\"%s\" y2=\"%s\" stroke=\"#5bc6d8\" stroke-width=\"2.0\" opacity=\"0.95\"><title>%s</title></line>" % [
			_num(projected.x),
			_num(projected.y),
			_num(projected.x + delta.x),
			_num(projected.y + delta.y),
			_xml(str(candidate.get("address", "boundary candidate"))),
		])

	parts.append("<text x=\"%s\" y=\"%s\" fill=\"#687583\" font-family=\"monospace\" font-size=\"7\">%s</text>" % [
		_num(origin_x + 8.0),
		_num(origin_y + CELL_SIZE - 8.0),
		_xml(_short_fingerprint(str(snapshot.get("topology_fingerprint", "")))),
	])
	parts.append("</g>")


static func _project(position: Array, min_x: float, min_z: float, size_x: float, size_z: float, origin_x: float, origin_y: float) -> Vector2:
	var usable: float = CELL_SIZE - CELL_PADDING * 2.0
	var x: float = origin_x + CELL_PADDING + clampf((float(position[0]) - min_x) / size_x, 0.0, 1.0) * usable
	var z: float = origin_y + CELL_PADDING + clampf((float(position[2]) - min_z) / size_z, 0.0, 1.0) * usable
	return Vector2(x, z)


static func _boundary_direction(side: String) -> Vector2:
	match side:
		"west":
			return Vector2.LEFT
		"east":
			return Vector2.RIGHT
		"north":
			return Vector2.UP
		"south":
			return Vector2.DOWN
		_:
			return Vector2.ZERO


static func _profile_fill(profile: Array) -> String:
	if profile.size() < 3:
		return "#dce9ca"
	var shallow: float = float(profile[0])
	var mid: float = float(profile[1])
	var deep: float = float(profile[2])
	if shallow >= mid and shallow >= deep:
		return "#dce9ca"
	if mid >= deep:
		return "#cfdfef"
	return "#dccfea"


static func _short_fingerprint(value: String) -> String:
	if value.length() <= 22:
		return value
	return value.substr(0, 22) + "…"


static func _xml(value: String) -> String:
	return value.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;").replace("'", "&apos;")


static func _num(value: float) -> String:
	return "%.3f" % value
