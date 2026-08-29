extends Resource
class_name UnderworldCavePresentationProfile

const PROFILE_PREFIX := "presentation.cave."
const VOLUME_KINDS: Array[String] = ["*", "default", "chamber", "tunnel", "entrance", "reserved_site"]
const _SEMANTIC_CHARS := "abcdefghijklmnopqrstuvwxyz0123456789_."

@export var profile_id: String = ""
@export var volume_kind: String = "*"
@export var biome_id: String = ""
@export var min_depth: float = 0.0
@export var max_depth: float = 1000000.0
@export var priority: int = 0
@export var albedo_color: Color = Color(0.24, 0.22, 0.20, 1.0)
@export_range(0.0, 1.0, 0.01) var roughness: float = 0.92
@export_range(0.0, 1.0, 0.01) var metallic: float = 0.0
@export var emission_color: Color = Color(0.0, 0.0, 0.0, 1.0)
@export_range(0.0, 4.0, 0.01) var emission_energy: float = 0.0
@export var local_light_color: Color = Color(0.72, 0.64, 0.52, 1.0)
@export_range(0.0, 8.0, 0.01) var local_light_energy: float = 0.0
@export_range(0.1, 64.0, 0.1) var local_light_range: float = 12.0
@export var ambience_id: String = ""
@export var fog_color: Color = Color(0.12, 0.11, 0.10, 1.0)
@export_range(0.0, 1.0, 0.001) var fog_density: float = 0.0
@export var dressing_hooks: Array[String] = []


func validate_profile() -> Array[String]:
	var failures: Array[String] = []
	if not is_valid_profile_id(profile_id):
		failures.append("invalid cave presentation profile id: %s" % profile_id)
	if not VOLUME_KINDS.has(volume_kind):
		failures.append("unsupported cave presentation volume kind: %s" % volume_kind)
	if not biome_id.is_empty() and not _is_semantic_token(biome_id):
		failures.append("cave presentation biome id must be one lowercase semantic token: %s" % biome_id)
	if min_depth < 0.0 or max_depth < min_depth:
		failures.append("cave presentation depth range is invalid for %s" % profile_id)
	if local_light_energy > 0.0 and local_light_range <= 0.0:
		failures.append("cave presentation local light requires positive range: %s" % profile_id)
	var seen_hooks: Dictionary = {}
	for hook in dressing_hooks:
		if hook.is_empty() or hook != hook.strip_edges():
			failures.append("cave presentation dressing hook must be non-empty and trimmed: %s" % hook)
		elif seen_hooks.has(hook):
			failures.append("duplicate cave presentation dressing hook: %s" % hook)
		seen_hooks[hook] = true
	failures.sort()
	return failures


func matches(context: Dictionary) -> bool:
	var context_kind: String = str(context.get("volume_kind", "default"))
	if volume_kind != "*" and volume_kind != context_kind:
		return false
	var context_biome: String = str(context.get("biome_id", ""))
	if not biome_id.is_empty() and biome_id != context_biome:
		return false
	var depth: float = float(context.get("depth", 0.0))
	return depth >= min_depth and depth <= max_depth


func specificity() -> int:
	var score := 0
	if volume_kind != "*":
		score += 2
	if not biome_id.is_empty():
		score += 1
	if min_depth > 0.0 or max_depth < 1000000.0:
		score += 1
	return score


func canonical_descriptor() -> Dictionary:
	var hooks: Array[String] = []
	hooks.append_array(dressing_hooks)
	hooks.sort()
	return {
		"profile_id": profile_id,
		"volume_kind": volume_kind,
		"biome_id": biome_id,
		"min_depth": min_depth,
		"max_depth": max_depth,
		"priority": priority,
		"albedo_color": albedo_color,
		"roughness": roughness,
		"metallic": metallic,
		"emission_color": emission_color,
		"emission_energy": emission_energy,
		"local_light_color": local_light_color,
		"local_light_energy": local_light_energy,
		"local_light_range": local_light_range,
		"ambience_id": ambience_id,
		"fog_color": fog_color,
		"fog_density": fog_density,
		"dressing_hooks": hooks,
	}


static func is_valid_profile_id(value: String) -> bool:
	if not value.begins_with(PROFILE_PREFIX) or value.ends_with(".") or value.contains(".."):
		return false
	for index in range(value.length()):
		if _SEMANTIC_CHARS.find(value.substr(index, 1)) < 0:
			return false
	return true


static func _is_semantic_token(value: String) -> bool:
	if value.is_empty() or value != value.strip_edges():
		return false
	for index in range(value.length()):
		var character := value.substr(index, 1)
		if "abcdefghijklmnopqrstuvwxyz0123456789_".find(character) < 0:
			return false
	return "abcdefghijklmnopqrstuvwxyz".find(value.substr(0, 1)) >= 0
