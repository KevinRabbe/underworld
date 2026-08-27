extends RefCounted
class_name UnderworldGeneratorManifest

const StableAddress := preload("res://worldgen/identity/stable_address.gd")
const SeedDeriver := preload("res://worldgen/random/seed_deriver.gd")
const SeedDomains := preload("res://worldgen/random/seed_domains.gd")

const MANIFEST_SCHEMA_VERSION: int = 1
const PREFIX: String = "gm1"

var seed_schema_version: int
var stable_address_schema_version: int
var surface_contract_revision: int
var underworld_contract_revision: int
var _stage_revisions: Dictionary = {}
var _profile_revisions: Dictionary = {}


func _init(
	stage_revisions: Dictionary = {},
	profile_revisions: Dictionary = {},
	surface_revision: int = 1,
	underworld_revision: int = 1
) -> void:
	seed_schema_version = SeedDeriver.SEED_SCHEMA_VERSION
	stable_address_schema_version = StableAddress.SCHEMA_VERSION
	surface_contract_revision = surface_revision
	underworld_contract_revision = underworld_revision

	for key in stage_revisions.keys():
		_stage_revisions[str(key)] = int(stage_revisions[key])
	for key in profile_revisions.keys():
		_profile_revisions[str(key)] = int(profile_revisions[key])


func stage_revisions() -> Dictionary:
	return _stage_revisions.duplicate(true)


func profile_revisions() -> Dictionary:
	return _profile_revisions.duplicate(true)


func canonical_text() -> String:
	var result: String = PREFIX
	result = _append(result, "manifest-schema")
	result = _append(result, str(MANIFEST_SCHEMA_VERSION))
	result = _append(result, "seed-schema")
	result = _append(result, str(seed_schema_version))
	result = _append(result, "stable-address-schema")
	result = _append(result, str(stable_address_schema_version))
	result = _append(result, "surface-contract")
	result = _append(result, str(surface_contract_revision))
	result = _append(result, "underworld-contract")
	result = _append(result, str(underworld_contract_revision))

	var stage_keys: Array = _stage_revisions.keys()
	stage_keys.sort()
	result = _append(result, "stage-count")
	result = _append(result, str(stage_keys.size()))
	for key_variant in stage_keys:
		var key: String = str(key_variant)
		result = _append(result, "stage")
		result = _append(result, key)
		result = _append(result, str(int(_stage_revisions[key])))

	var profile_keys: Array = _profile_revisions.keys()
	profile_keys.sort()
	result = _append(result, "profile-count")
	result = _append(result, str(profile_keys.size()))
	for key_variant in profile_keys:
		var key: String = str(key_variant)
		result = _append(result, "profile")
		result = _append(result, key)
		result = _append(result, str(int(_profile_revisions[key])))

	var domain_ids: Array[int] = []
	for domain in SeedDomains.all_domains():
		domain_ids.append(domain.domain_id)
	domain_ids.sort()

	result = _append(result, "domain-count")
	result = _append(result, str(domain_ids.size()))
	for domain_id in domain_ids:
		var domain = SeedDomains.get_domain(domain_id)
		result = _append(result, "domain")
		result = _append(result, "%08x" % domain.domain_id)
		result = _append(result, str(domain.revision))
		result = _append(result, domain.readable_name)

	return result


func manifest_id() -> String:
	return "gm-sha256:" + canonical_text().sha256_text()


func validate() -> Array[String]:
	var failures: Array[String] = []
	if seed_schema_version <= 0:
		failures.append("GeneratorManifest seed schema must be positive")
	if stable_address_schema_version <= 0:
		failures.append("GeneratorManifest StableAddress schema must be positive")
	if surface_contract_revision <= 0:
		failures.append("GeneratorManifest surface contract revision must be positive")
	if underworld_contract_revision <= 0:
		failures.append("GeneratorManifest Underworld contract revision must be positive")

	failures.append_array(_validate_revision_map("stage", _stage_revisions))
	failures.append_array(_validate_revision_map("profile", _profile_revisions))
	failures.append_array(SeedDomains.validate_registry())
	return failures


static func foundation_default():
	return UnderworldGeneratorManifest.new(
		{
			"macro_region": 1,
			"primary_topology": 1,
			"entrance_selection": 1,
			"secondary_connectivity": 1,
			"special_location_hooks": 1,
			"region_finalization": 1,
			"geometry_description": 1,
		},
		{
			"depth_grammar": 1,
		},
		2, # Current prototype surface generation contract / legacy-v2 baseline.
		1  # First Underworld deterministic architecture contract.
	)


static func _validate_revision_map(label: String, revisions: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	for key_variant in revisions.keys():
		var key: String = str(key_variant)
		if key.is_empty():
			failures.append("GeneratorManifest has empty %s revision key" % label)
		if int(revisions[key_variant]) <= 0:
			failures.append(
				"GeneratorManifest %s revision must be positive: %s" % [label, key]
			)
	return failures


static func _append(base: String, value: String) -> String:
	return base + "|%d:%s" % [value.length(), value]
