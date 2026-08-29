extends Resource
class_name UnderworldAudioCueCatalog

const CueDefinition := preload("res://presentation/audio/audio_cue_definition.gd")

const AMBIENCE_NONE := "none"
const AMBIENCE_SURFACE := "surface"
const AMBIENCE_CAVE := "cave"
const AMBIENCE_ROLES: Array[String] = [AMBIENCE_NONE, AMBIENCE_SURFACE, AMBIENCE_CAVE]

const CUE_IDS: Array[String] = [
	"audio_cue.ambience.cave",
	"audio_cue.ambience.surface",
	"audio_cue.craft.success",
	"audio_cue.enemy.burrower.attack",
	"audio_cue.enemy.burrower.death",
	"audio_cue.enemy.burrower.hit",
	"audio_cue.entrance.transition",
	"audio_cue.equipment.changed",
	"audio_cue.harvest.complete",
	"audio_cue.harvest.impact",
	"audio_cue.inventory.pickup",
	"audio_cue.loot.available",
	"audio_cue.loot.collected",
	"audio_cue.player.attack.heavy",
	"audio_cue.player.attack.light",
	"audio_cue.player.damage",
	"audio_cue.player.death",
	"audio_cue.player.parry.success",
	"audio_cue.resource.depleted",
	"audio_cue.resource.mine.impact",
]

const _AMBIENCE_CUE_BY_ROLE := {
	AMBIENCE_SURFACE: "audio_cue.ambience.surface",
	AMBIENCE_CAVE: "audio_cue.ambience.cave",
}

@export var cues: Array = []


func validate_catalog() -> Array[String]:
	var failures: Array[String] = []
	var by_id: Dictionary = {}
	for candidate in cues:
		if candidate == null or not candidate is CueDefinition:
			failures.append("audio cue catalog entries must inherit AudioCueDefinition")
			continue
		for failure in candidate.validate_definition():
			failures.append("cue %s: %s" % [candidate.cue_id, failure])
		if not CUE_IDS.has(candidate.cue_id):
			failures.append("audio cue catalog contains unknown vocabulary id: %s" % candidate.cue_id)
		if by_id.has(candidate.cue_id):
			failures.append("duplicate audio cue id: %s" % candidate.cue_id)
		by_id[candidate.cue_id] = candidate
		var is_ambience_id: bool = candidate.cue_id.begins_with("audio_cue.ambience.")
		if is_ambience_id and candidate.playback_space != CueDefinition.PLAYBACK_AMBIENCE:
			failures.append("ambience cue must use ambience playback space: %s" % candidate.cue_id)
		if not is_ambience_id and candidate.playback_space == CueDefinition.PLAYBACK_AMBIENCE:
			failures.append("non-ambience cue cannot use ambience playback space: %s" % candidate.cue_id)
	for expected_id in CUE_IDS:
		if not by_id.has(expected_id):
			failures.append("audio cue catalog is missing required M3 cue: %s" % expected_id)
	failures.sort()
	return failures


func resolve(cue_id: String) -> Dictionary:
	if not CUE_IDS.has(cue_id):
		return {
			"cue_id": cue_id,
			"definition": null,
			"diagnostics": ["unknown audio cue id: %s" % cue_id],
		}
	var failures: Array[String] = validate_catalog()
	if not failures.is_empty():
		return {"cue_id": cue_id, "definition": null, "diagnostics": failures}
	var definition = cue_by_id(cue_id)
	if definition == null:
		return {
			"cue_id": cue_id,
			"definition": null,
			"diagnostics": ["audio cue catalog could not resolve registered cue: %s" % cue_id],
		}
	return {"cue_id": cue_id, "definition": definition, "diagnostics": []}


func cue_by_id(cue_id: String):
	for candidate in cues:
		if candidate != null and candidate is CueDefinition and candidate.cue_id == cue_id:
			return candidate
	return null


func registered_cue_ids() -> Array[String]:
	var result: Array[String] = []
	for candidate in cues:
		if candidate != null and candidate is CueDefinition:
			result.append(candidate.cue_id)
	result.sort()
	return result


func validate_ambience_role(role: String) -> Array[String]:
	if AMBIENCE_ROLES.has(role):
		return []
	return ["unknown audio ambience role: %s" % role]


func ambience_cue_id(role: String) -> String:
	if role == AMBIENCE_NONE:
		return ""
	return str(_AMBIENCE_CUE_BY_ROLE.get(role, ""))


func canonical_descriptor() -> Dictionary:
	var descriptors: Array[Dictionary] = []
	for candidate in cues:
		if candidate != null and candidate is CueDefinition:
			descriptors.append(candidate.semantic_descriptor())
	descriptors.sort_custom(func(a, b): return str(a.get("cue_id", "")) < str(b.get("cue_id", "")))
	return {"cue_ids": supported_cue_ids(), "cues": descriptors}


static func supported_cue_ids() -> Array[String]:
	var result: Array[String] = []
	result.append_array(CUE_IDS)
	result.sort()
	return result
