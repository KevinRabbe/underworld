extends RefCounted
class_name UnderworldDeterministicRng

const SeedDeriver := preload("res://worldgen/random/seed_deriver.gd")

const MASK_32: int = 0xFFFFFFFF
const TWO_POW_32: int = 4294967296
const UNIT_DENOMINATOR: float = 4294967296.0

var _s0: int = 0
var _s1: int = 0
var _s2: int = 0
var _s3: int = 0


func _init(state_words: Array = []) -> void:
	if state_words.size() >= 4:
		_s0 = int(state_words[0]) & MASK_32
		_s1 = int(state_words[1]) & MASK_32
		_s2 = int(state_words[2]) & MASK_32
		_s3 = int(state_words[3]) & MASK_32

	if _s0 == 0 and _s1 == 0 and _s2 == 0 and _s3 == 0:
		_s0 = 0x6D2B79F5


static func from_context(
	world_seed: int,
	stable_address,
	domain,
	subkey: String = ""
):
	return UnderworldDeterministicRng.new(
		SeedDeriver.derive_state_words(world_seed, stable_address, domain, subkey)
	)


func next_u32() -> int:
	# xoshiro128** 1.1. All state is kept as explicit unsigned 32-bit values
	# represented inside Godot's signed 64-bit integer type.
	var result: int = (_rotl32((_s1 * 5) & MASK_32, 7) * 9) & MASK_32
	var t: int = (_s1 << 9) & MASK_32

	_s2 = (_s2 ^ _s0) & MASK_32
	_s3 = (_s3 ^ _s1) & MASK_32
	_s1 = (_s1 ^ _s2) & MASK_32
	_s0 = (_s0 ^ _s3) & MASK_32
	_s2 = (_s2 ^ t) & MASK_32
	_s3 = _rotl32(_s3, 11)

	return result


func unit_float() -> float:
	return float(next_u32()) / UNIT_DENOMINATOR


func range_float(minimum: float, maximum: float) -> float:
	return lerpf(minimum, maximum, unit_float())


func range_int(minimum_inclusive: int, maximum_exclusive: int) -> int:
	if maximum_exclusive <= minimum_inclusive:
		return minimum_inclusive

	var span: int = maximum_exclusive - minimum_inclusive
	if span >= TWO_POW_32:
		# Persistent procedural ranges should not need a span beyond one u32.
		# Returning the lower bound is deterministic and exposes misuse in tests.
		return minimum_inclusive

	# Rejection sampling avoids modulo bias.
	var acceptance_limit: int = TWO_POW_32 - (TWO_POW_32 % span)
	var value: int = next_u32()
	while value >= acceptance_limit:
		value = next_u32()
	return minimum_inclusive + (value % span)


func state_words() -> Array[int]:
	return [_s0, _s1, _s2, _s3]


static func _rotl32(value: int, shift: int) -> int:
	var normalized_shift: int = shift & 31
	var normalized: int = value & MASK_32
	if normalized_shift == 0:
		return normalized
	return (
		((normalized << normalized_shift) & MASK_32)
		| (normalized >> (32 - normalized_shift))
	) & MASK_32
