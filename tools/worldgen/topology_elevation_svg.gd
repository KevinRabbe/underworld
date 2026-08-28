extends RefCounted
class_name UnderworldTopologyElevationSvg

const CELL_SIZE: float = 250.0
const CELL_PADDING: float = 22.0
const OUTER_MARGIN: float = 34.0
const HEADER_HEIGHT: float = 86.0
const FOOTER_HEIGHT: float = 64.0
const NETWORK_COLORS: Array[String] = [
	"#2f6f9f",
	"#9a5b2f",
	"#5c7f3b",
	"#7b4f92",
	"#9b7133",
	"#3f7f78",
]


static func render(atlas: Dictionary, horizontal_axis: String = "x") -> String:
	if horizontal_axis != "x" and horizontal_axis != "z":
		return ""

	var grid_size: Array = atlas.get("grid_size", [1, 1])
	var columns: int = maxi(int(grid_size[0]), 1)
	var rows: int = maxi(int(grid_size[1]), 1)
	var width: float = OUTER_MARGIN * 2.0 + float(columns) * CELL_SIZE
	var height: float = HEADER_HEIGHT + float(rows) * CELL_SIZE + FOOTER_HEIGHT
	var regions: Array = atlas.get("regions", [])
	var center: Array = atlas.get("center_region", [0, 0])
	var totals: Dictionary = atlas.get("totals", {})
	var axis_label: String = "X" if horizontal_axis == "x" else "Z"

	var parts := PackedStringArray()
	parts.append("<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
	parts.append("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%s\" height=\"%s\" viewBox=\"0 0 %s %s\">" % [
		_num(width), _num(height), _num(width), _num(height),
	])
	parts.append("<rect x=\"0\" y=\"0\" width=\"100%%\" height=\"100%%\" fill=\"#101419\"/>")
	parts.append("<text x=\"%s\" y=\"30\" fill=\"#f2f4f7\" font-family=\"monospace\" font-size=\"18\">Underworld topology elevation atlas — %s / depth</text>" % [
		_num(OUTER_MARGIN), axis_label,
	])
	parts.append("<text x=\"%s\" y=\"51\" fill=\"#aab4c0\" font-family=\"monospace\" font-size=\"11\">seed=%s center=(%s,%s) radius=%s regions=%s nodes=%s edges=%s</text>" % [
		_num(OUTER_MARGIN),
		_xml(str(atlas.get("world_seed", 0))),
		_xml(str(center[0])),
		_xml(str(center[1])),
		_xml(str(atlas.get("radius", 0))),
		_xml(str(totals.get("region_count", 0))),
		_xml(str(totals.get("node_count", 0))),
		_xml(str(totals.get("edge_count", 0))),
	])
	parts.append("<text x=\"%s\" y=\"70\" fill=\"#778491\" font-family=\"monospace\" font-size=\"9\">horizontal=%s · vertical=world Y · translucent bands are geometric depth thirds · dashed edge=vertical transition</text>" % [
		_num(OUTER_MARGIN), axis_label,
	])

	for index in range(regions.size()):
		var row: int = index / columns
		var column: int = index % columns
		_append_region(parts, regions[index], column, row, horizontal_axis)

	var footer_y: float = HEADER_HEIGHT + float(rows) * CELL_SIZE + 30.0
	parts.append("<circle cx=\"%s\" cy=\"%s\" r=\"5\" fill=\"#dce9ca\"/><text x=\"%s\" y=\"%s\" fill=\"#b7c0ca\" font-family=\"monospace\" font-size=\"10\">shallow-dominant node</text>" % [
		_num(OUTER_MARGIN), _num(footer_y), _num(OUTER_MARGIN + 12.0), _num(footer_y + 3.0),
	])
	parts.append("<circle cx=\"%s\" cy=\"%s\" r=\"5\" fill=\"#cfdfef\"/><text x=\"%s\" y=\"%s\" fill=\"#b7c0ca\" font-family=\"monospace\" font-size=\"10\">mid-dominant</text>" % [
		_num(OUTER_MARGIN + 180.0), _num(footer_y), _num(OUTER_MARGIN + 192.0), _num(footer_y + 3.0),
	])
	parts.append("<circle cx=\"%s\" cy=\"%s\" r=\"5\" fill=\"#dccfea\"/><text x=\"%s\" y=\"%s\" fill=\"#b7c0ca\" font-family=\"monospace\" font-size=\"10\">deep-dominant</text>" % [
		_num(OUTER_MARGIN + 300.0), _num(footer_y), _num(OUTER_MARGIN + 312.0), _num(footer_y + 3.0),
	])
	parts.append("</svg>")
	return "\n".join(parts) + "\n"


static func _append_region(
	parts: PackedStringArray,
	snapshot: Dictionary,
	column: int,
	row: int,
	horizontal_axis: String
) -> void:
	var region: Dictionary = snapshot.get("region", {})
	var coord: Array = region.get("coord", [0, 0])
	var bounds: Dictionary = region.get("world_bounds", {})
	var bounds_position: Array = bounds.get("position", [0.0, -1.0, 0.0])
	var bounds_size: Array = bounds.get("size", [1.0, 1.0, 1.0])
	var horizontal_index: int = 0 if horizontal_axis == "x" else 2
	var horizontal_min: float = float(bounds_position[horizontal_index])
	var horizontal_size: float = maxf(float(bounds_size[horizontal_index]), 1.0)
	var min_y: float = float(bounds_position[1])
	var size_y: float = maxf(float(bounds_size[1]), 1.0)
	var origin_x: float = OUTER_MARGIN + float(column) * CELL_SIZE
	var origin_y: float = HEADER_HEIGHT + float(row) * CELL_SIZE
	var frame_x: float = origin_x + 2.0
	var frame_y: float = origin_y + 2.0
	var frame_size: float = CELL_SIZE - 4.0
	var usable: float = CELL_SIZE - CELL_PADDING * 2.0
	var nodes: Array = snapshot.get("nodes", [])
	var edges: Array = snapshot.get("edges", [])
	var networks: Array = snapshot.get("networks", [])

	parts.append("<g class=\"elevation-region-cell\" data-region=\"%s,%s\" data-axis=\"%s\">" % [
		_xml(str(coord[0])), _xml(str(coord[1])), horizontal_axis,
	])
	parts.append("<rect class=\"elevation-region-frame\" x=\"%s\" y=\"%s\" width=\"%s\" height=\"%s\" fill=\"#171d24\" stroke=\"#596675\" stroke-width=\"1.5\"/>" % [
		_num(frame_x), _num(frame_y), _num(frame_size), _num(frame_size),
	])

	var band_height: float = usable / 3.0
	parts.append("<rect class=\"depth-band depth-shallow\" x=\"%s\" y=\"%s\" width=\"%s\" height=\"%s\" fill=\"#dce9ca\" opacity=\"0.045\"/>" % [
		_num(origin_x + CELL_PADDING), _num(origin_y + CELL_PADDING), _num(usable), _num(band_height),
	])
	parts.append("<rect class=\"depth-band depth-mid\" x=\"%s\" y=\"%s\" width=\"%s\" height=\"%s\" fill=\"#cfdfef\" opacity=\"0.045\"/>" % [
		_num(origin_x + CELL_PADDING), _num(origin_y + CELL_PADDING + band_height), _num(usable), _num(band_height),
	])
	parts.append("<rect class=\"depth-band depth-deep\" x=\"%s\" y=\"%s\" width=\"%s\" height=\"%s\" fill=\"#dccfea\" opacity=\"0.045\"/>" % [
		_num(origin_x + CELL_PADDING), _num(origin_y + CELL_PADDING + band_height * 2.0), _num(usable), _num(band_height),
	])
	parts.append("<line class=\"surface-plane\" x1=\"%s\" y1=\"%s\" x2=\"%s\" y2=\"%s\" stroke=\"#8995a2\" stroke-width=\"1\" opacity=\"0.6\"/>" % [
		_num(origin_x + CELL_PADDING), _num(origin_y + CELL_PADDING), _num(origin_x + CELL_PADDING + usable), _num(origin_y + CELL_PADDING),
	])
	parts.append("<text x=\"%s\" y=\"%s\" fill=\"#d9e0e8\" font-family=\"monospace\" font-size=\"10\">region (%s,%s) · %s/Y · n=%s e=%s</text>" % [
		_num(origin_x + 10.0),
		_num(origin_y + 15.0),
		_xml(str(coord[0])),
		_xml(str(coord[1])),
		("X" if horizontal_axis == "x" else "Z"),
		_xml(str(nodes.size())),
		_xml(str(edges.size())),
	])
	parts.append("<text x=\"%s\" y=\"%s\" fill=\"#697684\" font-family=\"monospace\" font-size=\"7\">top %sm</text>" % [
		_num(origin_x + 5.0), _num(origin_y + CELL_PADDING + 3.0), _num(min_y + size_y),
	])
	parts.append("<text x=\"%s\" y=\"%s\" fill=\"#697684\" font-family=\"monospace\" font-size=\"7\">bottom %sm</text>" % [
		_num(origin_x + 5.0), _num(origin_y + CELL_PADDING + usable), _num(min_y),
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
		var a_pos: Vector2 = _project(a.get("world_position", [0.0, 0.0, 0.0]), horizontal_index, horizontal_min, horizontal_size, min_y, size_y, origin_x, origin_y)
		var b_pos: Vector2 = _project(b.get("world_position", [0.0, 0.0, 0.0]), horizontal_index, horizontal_min, horizontal_size, min_y, size_y, origin_x, origin_y)
		var stroke: String = str(network_color.get(str(a.get("owning_network_id", "")), "#99a4af"))
		var is_vertical: bool = str(edge.get("connection_class", "")) == "vertical_transition"
		var dashed: String = " stroke-dasharray=\"5 4\"" if is_vertical else ""
		var width: float = 2.3 if is_vertical else 1.6
		parts.append("<line class=\"elevation-edge%s\" x1=\"%s\" y1=\"%s\" x2=\"%s\" y2=\"%s\" stroke=\"%s\" stroke-width=\"%s\" opacity=\"0.82\"%s><title>%s</title></line>" % [
			" vertical-transition" if is_vertical else "",
			_num(a_pos.x), _num(a_pos.y), _num(b_pos.x), _num(b_pos.y), stroke, _num(width), dashed,
			_xml(str(edge.get("stable_id", ""))),
		])

	for node in nodes:
		var position: Array = node.get("world_position", [0.0, 0.0, 0.0])
		var projected: Vector2 = _project(position, horizontal_index, horizontal_min, horizontal_size, min_y, size_y, origin_x, origin_y)
		var profile: Array = node.get("profile_blend", [1.0, 0.0, 0.0])
		var semantic: String = str(node.get("semantic_type", "node"))
		var radius: float = 3.5
		if semantic == "junction":
			radius = 4.8
		elif semantic == "terminal":
			radius = 2.8
		var stroke: String = str(network_color.get(str(node.get("owning_network_id", "")), "#d3d8de"))
		parts.append("<circle class=\"elevation-node\" cx=\"%s\" cy=\"%s\" r=\"%s\" fill=\"%s\" stroke=\"%s\" stroke-width=\"1.2\"><title>%s | world=(%s,%s,%s) | %s</title></circle>" % [
			_num(projected.x),
			_num(projected.y),
			_num(radius),
			_profile_fill(profile),
			stroke,
			_xml(str(node.get("stable_id", ""))),
			_num(float(position[0])),
			_num(float(position[1])),
			_num(float(position[2])),
			_xml(semantic),
		])

	parts.append("<text x=\"%s\" y=\"%s\" fill=\"#687583\" font-family=\"monospace\" font-size=\"7\">%s</text>" % [
		_num(origin_x + 8.0),
		_num(origin_y + CELL_SIZE - 8.0),
		_xml(_short_fingerprint(str(snapshot.get("topology_fingerprint", "")))),
	])
	parts.append("</g>")


static func _project(
	position: Array,
	horizontal_index: int,
	horizontal_min: float,
	horizontal_size: float,
	min_y: float,
	size_y: float,
	origin_x: float,
	origin_y: float
) -> Vector2:
	var usable: float = CELL_SIZE - CELL_PADDING * 2.0
	var horizontal: float = clampf((float(position[horizontal_index]) - horizontal_min) / horizontal_size, 0.0, 1.0)
	var vertical: float = clampf((float(position[1]) - min_y) / size_y, 0.0, 1.0)
	return Vector2(
		origin_x + CELL_PADDING + horizontal * usable,
		origin_y + CELL_PADDING + (1.0 - vertical) * usable
	)


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
