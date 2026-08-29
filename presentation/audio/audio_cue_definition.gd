extends Resource
class_name UnderworldAudioCueDefinition

const CUE_PREFIX := "audio_cue."
const PLAYBACK_GLOBAL := "global"
const PLAYBACK_SPATIAL := "spatial"
const PLAYBACK_AMBIENCE := "ambience"
const PLAYBACK_SPACES: Array[String] = [
	PLAYBACK_GLOBAL,
	PLAYBACK_SPATIAL,
	PLAYBACK_AMBIENCE,
]
const _SEMANTIC_CHARS := "abcdefghijklmnopqrstuvwxyz0123456789_."

@export var cue_id: String = ""
@export_enum("global", "spatial", "ambience") var playback_space: String = PLAYBACK_GLOBAL
@export var stream: AudioStream
@export_range(-80.0, 12.0, 0.1) var volume_db: float = 0.0
@export var looping: bool = false


func configure(
	p_cue_id: String,
	p_playback_space: String = PLAYBACK_GLOBAL,
	p_stream: AudioStream = null,
	p_looping: bool = false,
	p_volume_db: float = 0.0
) -> Resource:
	cue_id = p_cue_id
	playback_space = p_playback_space
	stream = p_stream
	looping = p_looping
	volume_db = p_volume_db
	return self


func validate_definition() -> Array[String]:
	var failures: Array[String] = []
	if not is_valid_cue_id(cue_id):
		failures.append("invalid audio cue id: %s" % cue_id)
	if not PLAYBACK_SPACES.has(playback_space):
		failures.append("unsupported audio playback space for %s: %s" % [cue_id, playback_space])
	if not is_finite(volume_db):
		failures.append("audio cue volume must be finite: %s" % cue_id)
	if playback_space == PLAYBACK_AMBIENCE and not looping:
		failures.append("ambience audio cue must be looping: %s" % cue_id)
	if playback_space != PLAYBACK_AMBIENCE and looping:
		failures.append("non-ambience audio cue cannot own looping playback: %s" % cue_id)
	failures.sort()
	return failures


func semantic_descriptor() -> Dictionary:
	return {
		"cue_id": cue_id,
		"playback_space": playback_space,
		"looping": looping,
		"volume_db": volume_db,
	}


static func is_valid_cue_id(value: String) -> bool:
	if (
		value.is_empty()
		or value != value.strip_edges()
		or not value.begins_with(CUE_PREFIX)
		or value.ends_with(".")
		or value.contains("..")
	):
		return false
	for index in range(value.length()):
		if _SEMANTIC_CHARS.find(value.substr(index, 1)) < 0:
			return false
	return true
