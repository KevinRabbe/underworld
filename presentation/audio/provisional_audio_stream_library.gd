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
	var surface := _tone_stream(110.0, AMBIENCE_SAMPLE_COUNT, true)
	var cave := _tone_stream(82.0, AMBIENCE_SAMPLE_COUNT, true)
	for candidate in clone.cues:
		if candidate == null or not candidate is CueDefinition or candidate.stream != null:
			continue
		if candidate.playback_space == CueDefinition.PLAYBACK_AMBIENCE:
			candidate.stream = cave if candidate.cue_id == "audio_cue.ambience.cave" else surface
		else:
			candidate.stream = _tone_stream(
				_one_shot_frequency(candidate.cue_id),
				ONE_SHOT_SAMPLE_COUNT,
				false
			)
	return clone


static func _one_shot_frequency(cue_id: String) -> float:
	match cue_id:
		"audio_cue.player.death":
			return 180.0
		"audio_cue.player.respawn":
			return 620.0
		"audio_cue.player.damage":
			return 240.0
		"audio_cue.player.attack.light":
			return 520.0
		"audio_cue.player.attack.heavy":
			return 300.0
		"audio_cue.player.parry.success":
			return 760.0
		"audio_cue.craft.success":
			return 680.0
		"audio_cue.equipment.changed":
			return 560.0
		"audio_cue.inventory.pickup":
			return 720.0
		"audio_cue.loot.available":
			return 420.0
		"audio_cue.loot.collected":
			return 650.0
		"audio_cue.enemy.burrower.attack":
			return 205.0
		"audio_cue.enemy.burrower.hit":
			return 255.0
		"audio_cue.enemy.burrower.death":
			return 145.0
		"audio_cue.harvest.impact":
			return 340.0
		"audio_cue.harvest.complete":
			return 590.0
		"audio_cue.resource.mine.impact":
			return 280.0
		"audio_cue.resource.depleted":
			return 160.0
		"audio_cue.entrance.transition":
			return 480.0
		_:
			return 440.0


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
