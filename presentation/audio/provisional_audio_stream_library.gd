extends RefCounted
class_name UnderworldProvisionalAudioStreamLibrary

const CueCatalog := preload("res://presentation/audio/audio_cue_catalog.gd")
const CueDefinition := preload("res://presentation/audio/audio_cue_definition.gd")

const SAMPLE_RATE := 8000
const ONE_SHOT_SAMPLE_COUNT := 960
const AMBIENCE_SAMPLE_COUNT := 1600


static func clone_with_missing_streams(catalog):
	if catalog == null or not catalog is CueCatalog:
		return null
	var clone = catalog.duplicate(true)
	if clone == null or not clone is CueCatalog:
		return null
	var one_shot := _tone_stream(440.0, ONE_SHOT_SAMPLE_COUNT, false)
	var surface := _tone_stream(110.0, AMBIENCE_SAMPLE_COUNT, true)
	var cave := _tone_stream(82.0, AMBIENCE_SAMPLE_COUNT, true)
	for candidate in clone.cues:
		if candidate == null or not candidate is CueDefinition or candidate.stream != null:
			continue
		if candidate.playback_space == CueDefinition.PLAYBACK_AMBIENCE:
			candidate.stream = cave if candidate.cue_id == "audio_cue.ambience.cave" else surface
		else:
			candidate.stream = one_shot
	return clone


static func _tone_stream(frequency_hz: float, sample_count: int, looped: bool) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	var data := PackedByteArray()
	data.resize(maxi(sample_count, 1))
	for index in range(data.size()):
		var phase: float = TAU * frequency_hz * float(index) / float(SAMPLE_RATE)
		var envelope: float = 1.0
		if not looped:
			envelope = 1.0 - float(index) / float(data.size())
		var sample: int = clampi(int(round(128.0 + sin(phase) * 34.0 * envelope)), 0, 255)
		data[index] = sample
	stream.data = data
	if looped:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = data.size()
	else:
		stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	return stream
