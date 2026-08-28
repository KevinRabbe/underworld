extends RefCounted
class_name UnderworldTopologySnapshotSvg

const CANVAS_SIZE: float = 920.0
const MARGIN: float = 70.0
const NETWORK_COLORS: Array[String] = [
	"#2f6f9f",
	"#9a5b2f",
	"#5c7f3b",
	"#7b4f92",
	"#9b7133",
	"#3f7f78",
]


static func render(snapshot: Dictionary) -> String:
	var region: Dictionary = snapshot.get("region", {})
	var bounds: Dictionary = region.get("world_bounds", {})
	var bounds_position: Array = bounds.get("position", [0.0, 0.0, 0.0])
	var bounds_size: Array = bounds.get("size", [1.0, 1.0, 1.0])
	var min_x: float = float(bounds_position[0])
	var min_z: float = float(bounds_position[2])
	var size_x: float = maxf(float(bounds_size[0]), 1.0)
	var size_z: float = maxf(float(bounds_size[2]), 1.0)

	var nodes: Array = snapshot.get("nodes", [])
	var edges: Array = snapshot.get("edges", [])
	var networks: Array = snapshot.get("networks", [])
	var node_lookup: Dictionary = {}
	for node in nodes:
		node_lookup[str(node.get("stable_id", ""))] = node

	var network_color: Dictionary = {}
	for index in range(networks.size()):
		var network: Dictionary = networks[index]
		network_color[str(network.get("stable_id", ""))] = NETWORK_COLORS[index % NETWORK_COLORS.size()]

	var parts: PackedStringArray = PackedStringArray()
	parts.append("<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
	parts.append("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"920\" height=\"1040\" viewBox=\"0 0 920 1040\">")
	parts.append("<rect x=\"0\" y=\"0\" width=\"920\" height=\"1040\" fill=\"#11151a\"/>")
	parts.append("<text x=\"70\" y=\"34\" fill=\"#f2f4f7\" font-family=\"monospace\" font-size=\"18\">Underworld topology snapshot</text>")
	parts.append("<text x=\"70\" y=\"55\" fill=\"#aab4c0\" font-family=\"monospace\" font-size=\"12\">seed=%s region=(%s,%s)</text>" % [
		str(snapshot.get("world_seed", 0)),
		str(region.get("coord", [0, 0])[0]),
		str(region.get("coord", [0, 0])[1]),
	])
	parts.append("<rect x=\"70\" y=\"70\" width=\"780\" height=\"780\" fill=\"#171d24\" stroke=\"#687483\" stroke-width=\"2\"/>")

	for edge in edges:
		var a_id: String = str(edge.get("endpoint_a_node_id", ""))
		var b_id: String = str(edge.get("endpoint_b_node_id", ""))
		if not node_lookup.has(a_id) or not node_lookup.has(b_id):
			continue
		var a: Dictionary = node_lookup[a_id]
		var b: Dictionary = node_lookup[b_id]
		var a_pos: Vector2 = _project(a.get("world_position", [0.0, 0.0, 0.0]), min_x, min_z, size_x, size_z)
		var b_pos: Vector2 = _project(b.get("world_position", [0.0, 0.0, 0.0]), min_x, min_z, size_x, size_z)
		var color: String = str(network_color.get(str(a.get("owning_network_id", "")), "#9ca7b3"))
		var dashed: String = " stroke-dasharray=\"7 5\"" if str(edge.get("connection_class", "")) == "vertical_transition" else ""
		parts.append("<line x1=\"%s\" y1=\"%s\" x2=\"%s\" y2=\"%s\" stroke=\"%s\" stroke-width=\"2.4\" opacity=\"0.82\"%s/>" % [
			_num(a_pos.x), _num(a_pos.y), _num(b_pos.x), _num(b_pos.y), color, dashed,
		])

	for node in nodes:
		var position: Array = node.get("world_position", [0.0, 0.0, 0.0])
		var projected: Vector2 = _project(position, min_x, min_z, size_x, size_z)
		var profile: Array = node.get("profile_blend", [1.0, 0.0, 0.0])
		var fill: String = _profile_fill(profile)
		var network_id: String = str(node.get("owning_network_id", ""))
		var color: String = str(network_color.get(network_id, "#d3d8de"))
		var semantic: String = str(node.get("semantic_type", "node"))
		var radius: float = 6.5
		if semantic == "junction":
			radius = 8.5
		elif semantic == "terminal":
			radius = 5.0
		parts.append("<circle cx=\"%s\" cy=\"%s\" r=\"%s\" fill=\"%s\" stroke=\"%s\" stroke-width=\"2\"/>" % [
			_num(projected.x), _num(projected.y), _num(radius), fill, color,
		])
		parts.append("<title>%s | y=%s | %s</title>" % [
			_xml(str(node.get("stable_id", ""))),
			_num(float(position[1])),
			_xml(semantic),
		])

	var legend_y: float = 888.0
	parts.append("<text x=\"70\" y=\"878\" fill=\"#f2f4f7\" font-family=\"monospace\" font-size=\"13\">Networks</text>")
	for index in range(networks.size()):
		var network: Dictionary = networks[index]
		var color: String = NETWORK_COLORS[index % NETWORK_COLORS.size()]
		var y: float = legend_y + float(index) * 22.0
		parts.append("<line x1=\"70\" y1=\"%s\" x2=\"96\" y2=\"%s\" stroke=\"%s\" stroke-width=\"4\"/>" % [_num(y), _num(y), color])
		parts.append("<text x=\"105\" y=\"%s\" fill=\"#cbd3dc\" font-family=\"monospace\" font-size=\"11\">%s</text>" % [
			_num(y + 4.0), _xml(_short_id(str(network.get("stable_id", "")))),
		])

	parts.append("<text x=\"520\" y=\"878\" fill=\"#f2f4f7\" font-family=\"monospace\" font-size=\"13\">Depth profile</text>")
	parts.append(_legend_dot(520.0, 900.0, "#dce9ca", "shallow"))
	parts.append(_legend_dot(520.0, 924.0, "#cfdfef", "mid"))
	parts.append(_legend_dot(520.0, 948.0, "#dccfea", "deep"))
	parts.append("<text x=\"520\" y=\"980\" fill=\"#8f9ba8\" font-family=\"monospace\" font-size=\"10\">dashed edge = vertical transition</text>")
	parts.append("<text x=\"70\" y=\"1015\" fill=\"#788491\" font-family=\"monospace\" font-size=\"10\">topology=%s</text>" % _xml(str(snapshot.get("topology_fingerprint", ""))))
	parts.append("</svg>")
	return "\n".join(parts) + "\n"


static func _project(position: Array, min_x: float, min_z: float, size_x: float, size_z: float) -> Vector2:
	var usable: float = CANVAS_SIZE - MARGIN * 2.0
	var x: float = MARGIN + clampf((float(position[0]) - min_x) / size_x, 0.0, 1.0) * usable
	var z: float = MARGIN + clampf((float(position[2]) - min_z) / size_z, 0.0, 1.0) * usable
	return Vector2(x, z)


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


static func _legend_dot(x: float, y: float, fill: String, label: String) -> String:
	return "<circle cx=\"%s\" cy=\"%s\" r=\"6\" fill=\"%s\"/><text x=\"534\" y=\"%s\" fill=\"#cbd3dc\" font-family=\"monospace\" font-size=\"11\">%s</text>" % [
		_num(x), _num(y), fill, _num(y + 4.0), _xml(label),
	]


static func _short_id(value: String) -> String:
	if value.length() <= 26:
		return value
	return value.substr(0, 12) + "…" + value.substr(value.length() - 10)


static func _xml(value: String) -> String:
	return value.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;").replace("'", "&apos;")


static func _num(value: float) -> String:
	return "%.3f" % value
