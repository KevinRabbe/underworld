extends RefCounted
class_name UnderworldSeedDeriver

## Seed schema v1
##
## Project-owned byte contract + FNV-1a 32-bit mixer. We deliberately derive
## separate 32-bit lanes rather than relying on mutable engine RNG state.
## The exact outputs are frozen by tests before world generation uses them.

const SEED_SCHEMA_VERSION: int = 1
const FNV_OFFSET_BASIS_32: int = 2166136261
const FNV_PRIME_32: int = 16777619
const MASK_32: int = 0xFFFFFFFF
const UNIT_DENOMINATOR: float = 4294967296.0
const MAGIC: String = "UW-SEED"


static func derive_u32(
	world_seed: int,
	stable_address,
	domain,
	subkey: String = ""
) -> int:
	return _derive_lane_u32(world_seed, stable_address, domain, subkey, 0)


static func derive_state_words(
	world_seed: int,
	stable_address,
	domain,
	subkey: String = ""
) -> Array[int]:
	var words: Array[int] = []
	for lane in range(1, 5):
		words.append(_derive_lane_u32(world_seed, stable_address, domain, subkey, lane))

	# xoshiro128** has one forbidden all-zero state. Make that state impossible
	# in a deterministic, explicit way without consuming another random stream.
	if words[0] == 0 and words[1] == 0 and words[2] == 0 and words[3] == 0:
		words[0] = 0x6D2B79F5
	return words


static func random_unit(
	world_seed: int,
	stable_address,
	domain,
	subkey: String = ""
) -> float:
	return float(derive_u32(world_seed, stable_address, domain, subkey)) / UNIT_DENOMINATOR


static func _derive_lane_u32(
	world_seed: int,
	stable_address,
	domain,
	subkey: String,
	lane: int
) -> int:
	if stable_address == null or domain == null:
		return 0
	if not _is_ascii(subkey):
		return 0

	var hash_value: int = FNV_OFFSET_BASIS_32
	hash_value = _feed_ascii_string(hash_value, MAGIC)
	hash_value = _feed_u32(hash_value, SEED_SCHEMA_VERSION)
	hash_value = _feed_i64(hash_value, world_seed)
	hash_value = _feed_u32(hash_value, domain.domain_id)
	hash_value = _feed_u32(hash_value, domain.revision)
	hash_value = _feed_ascii_string(hash_value, stable_address.canonical_text())
	hash_value = _feed_ascii_string(hash_value, subkey)
	hash_value = _feed_u32(hash_value, lane)
	return hash_value & MASK_32


static func _feed_ascii_string(hash_value: int, value: String) -> int:
	if not _is_ascii(value):
		return 0
	var result: int = _feed_u32(hash_value, value.length())
	for index in range(value.length()):
		result = _feed_byte(result, value.unicode_at(index))
	return result


static func _feed_i64(hash_value: int, value: int) -> int:
	var result: int = hash_value
	for shift in range(0, 64, 8):
		result = _feed_byte(result, (value >> shift) & 0xFF)
	return result


static func _feed_u32(hash_value: int, value: int) -> int:
	var result: int = hash_value
	var normalized: int = value & MASK_32
	for shift in range(0, 32, 8):
		result = _feed_byte(result, (normalized >> shift) & 0xFF)
	return result


static func _feed_byte(hash_value: int, byte_value: int) -> int:
	var mixed: int = (hash_value ^ (byte_value & 0xFF)) & MASK_32
	# 32-bit product remains safely below signed 64-bit overflow before masking.
	return (mixed * FNV_PRIME_32) & MASK_32


static func _is_ascii(value: String) -> bool:
	for index in range(value.length()):
		if value.unicode_at(index) > 127:
			return false
	return true
