extends RefCounted
class_name UnderworldGeneratorManifest

const StableAddress := preload("res://worldgen/identity/stable_address.gd")
const SeedDeriver := preload("res://worldgen/random/seed_deriver.gd")
const SeedDomains := preload("res://worldgen/random/seed_domains.gd")

const MANIFEST_SCHEMA_VERSION: int = 1
const PREFIX: String = "gm1"
const SCRIPT_PATH: String = "res://worldgen/versioning/generator_manifest.gd"

var _manifest_schema_version: int = 0
var _manifest_schema_prefix: String = ""
var _seed_schema_version: int = 0
var _stable_address_schema_version: int = 0
var _surface_contract_revision: int = 0
var _underworld_contract_revision: int = 0
var _provenance_contract_revision: int = 0
var _stage_entries: Array = []
var _profile_entries: Array = []
var _seed_domain_descriptors: Array = []

var manifest_schema_version: int:
	get:
		return _manifest_schema_version
	set(_value):
		pass

var manifest_schema_prefix: String:
	get:
		return _manifest_schema_prefix
	set(_value):
		pass

var seed_schema_version: int:
	get:
		return _seed_schema_version
	set(_value):
		pass

var stable_address_schema_version: int:
	get:
		return _stable_address_schema_version
	set(_value):
		pass

var surface_contract_revision: int:
	get:
		return _surface_contract_revision
	set(_value):
		pass

var underworld_contract_revision: int:
	get:
		return _underworld_contract_revision
	set(_value):
		pass

var provenance_contract_revision: int:
	get:
		return _provenance_contract_revision
	set(_value):
		pass


func _init(
	stage_revisions: Dictionary = {},
	profile_revisions: Dictionary = {},
	surface_revision: int = 1,
	underworld_revision: int = 1,
	provenance_revision: int = 1,
	snapshot_value: Dictionary = {}
) -> void:
	if not snapshot_value.is_empty():
		_apply_snapshot(snapshot_value)
		return

	_manifest_schema_version = MANIFEST_SCHEMA_VERSION
	_manifest_schema_prefix = PREFIX
	_seed_schema_version = SeedDeriver.SEED_SCHEMA_VERSION
	_stable_address_schema_version = StableAddress.SCHEMA_VERSION
	_surface_contract_revision = surface_revision
	_underworld_contract_revision = underworld_revision
	_provenance_contract_revision = provenance_revision
	_stage_entries = _revision_entries_from_dictionary(stage_revisions)
	_profile_entries = _revision_entries_from_dictionary(profile_revisions)
	_seed_domain_descriptors = _capture_current_seed_domains()


func stage_revisions() -> Dictionary:
	return _revision_dictionary(_stage_entries)


func profile_revisions() -> Dictionary:
	return _revision_dictionary(_profile_entries)


func seed_domain_descriptors() -> Array:
	return _seed_domain_descriptors.duplicate(true)


func snapshot() -> Dictionary:
	return {
		"manifest_schema_version": _manifest_schema_version,
		"manifest_schema_prefix": _manifest_schema_prefix,
		"seed_schema_version": _seed_schema_version,
		"stable_address_schema_version": _stable_address_schema_version,
		"surface_contract_revision": _surface_contract_revision,
		"underworld_contract_revision": _underworld_contract_revision,
		"provenance_contract_revision": _provenance_contract_revision,
		"stage_entries": _stage_entries.duplicate(true),
		"profile_entries": _profile_entries.duplicate(true),
		"seed_domain_descriptors": _seed_domain_descriptors.duplicate(true),
	}


func immutable_copy():
	return load(SCRIPT_PATH).new({}, {}, 1, 1, 1, snapshot())


func canonical_text() -> String:
	var result: String = _manifest_schema_prefix
	result = _append(result, "manifest-schema")
	result = _append(result, str(_manifest_schema_version))
	result = _append(result, "seed-schema")
	result = _append(result, str(_seed_schema_version))
	result = _append(result, "stable-address-schema")
	result = _append(result, str(_stable_address_schema_version))
	result = _append(result, "surface-contract")
	result = _append(result, str(_surface_contract_revision))
	result = _append(result, "underworld-contract")
	result = _append(result, str(_underworld_contract_revision))
	result = _append(result, "provenance-contract")
	result = _append(result, str(_provenance_contract_revision))

	var stage_map: Dictionary = stage_revisions()
	var stage_keys: Array = stage_map.keys()
	stage_keys.sort()
	result = _append(result, "stage-count")
	result = _append(result, str(stage_keys.size()))
	for key_variant in stage_keys:
		var key: String = str(key_variant)
		result = _append(result, "stage")
		result = _append(result, key)
		result = _append(result, str(int(stage_map[key])))

	var profile_map: Dictionary = profile_revisions()
	var profile_keys: Array = profile_map.keys()
	profile_keys.sort()
	result = _append(result, "profile-count")
	result = _append(result, str(profile_keys.size()))
	for key_variant in profile_keys:
		var key: String = str(key_variant)
		result = _append(result, "profile")
		result = _append(result, key)
		result = _append(result, str(int(profile_map[key])))

	var domain_keys: Array[String] = []
	var domains_by_key: Dictionary = {}
	for descriptor_variant in _seed_domain_descriptors:
		if typeof(descriptor_variant) != TYPE_DICTIONARY:
			continue
		var descriptor: Dictionary = descriptor_variant
		var sort_key := "%08x@%010d@%s" % [
			int(descriptor.get("domain_id", 0)),
			int(descriptor.get("revision", 0)),
			str(descriptor.get("readable_name", "")),
		]
		domain_keys.append(sort_key)
		domains_by_key[sort_key] = descriptor
	domain_keys.sort()

	result = _append(result, "domain-count")
	result = _append(result, str(domain_keys.size()))
	for sort_key in domain_keys:
		var descriptor: Dictionary = domains_by_key[sort_key]
		result = _append(result, "domain")
		result = _append(result, "%08x" % int(descriptor["domain_id"]))
		result = _append(result, str(int(descriptor["revision"])))
		result = _append(result, str(descriptor["readable_name"]))

	return result


func manifest_id() -> String:
	return "gm-sha256:" + canonical_text().sha256_text()


func validate() -> Array[String]:
	return validate_snapshot(snapshot())


func runtime_compatibility_failures(runtime_support: Dictionary = {}) -> Array[String]:
	var failures: Array[String] = []
	var support: Dictionary = runtime_support.duplicate(true)
	if support.is_empty():
		support = current_runtime_support()

	_compare_exact_support(
		failures,
		"manifest schema version",
		_manifest_schema_version,
		int(support.get("manifest_schema_version", 0))
	)
	_compare_exact_support(
		failures,
		"manifest schema prefix",
		_manifest_schema_prefix,
		str(support.get("manifest_schema_prefix", ""))
	)
	_compare_exact_support(
		failures,
		"seed schema version",
		_seed_schema_version,
		int(support.get("seed_schema_version", 0))
	)
	_compare_exact_support(
		failures,
		"StableAddress schema version",
		_stable_address_schema_version,
		int(support.get("stable_address_schema_version", 0))
	)
	_compare_exact_support(
		failures,
		"surface contract revision",
		_surface_contract_revision,
		int(support.get("surface_contract_revision", 0))
	)
	_compare_exact_support(
		failures,
		"Underworld contract revision",
		_underworld_contract_revision,
		int(support.get("underworld_contract_revision", 0))
	)
	_compare_exact_support(
		failures,
		"provenance contract revision",
		_provenance_contract_revision,
		int(support.get("provenance_contract_revision", 0))
	)

	failures.append_array(
		_compare_required_revision_entries(
			"stage",
			_stage_entries,
			support.get("stage_revisions", {})
		)
	)
	failures.append_array(
		_compare_required_revision_entries(
			"profile",
			_profile_entries,
			support.get("profile_revisions", {})
		)
	)
	failures.append_array(
		_compare_required_domains(
			_seed_domain_descriptors,
			support.get("seed_domain_descriptors", [])
		)
	)
	return failures


static func foundation_default():
	return load(SCRIPT_PATH).new(
		_current_stage_revisions(),
		_current_profile_revisions(),
		2, # Current prototype surface generation contract / legacy-v2 baseline.
		1  # First Underworld deterministic architecture contract.
	)


static func from_snapshot(snapshot_value: Dictionary):
	return load(SCRIPT_PATH).new({}, {}, 1, 1, 1, snapshot_value.duplicate(true))


static func current_runtime_support() -> Dictionary:
	return {
		"manifest_schema_version": MANIFEST_SCHEMA_VERSION,
		"manifest_schema_prefix": PREFIX,
		"seed_schema_version": SeedDeriver.SEED_SCHEMA_VERSION,
		"stable_address_schema_version": StableAddress.SCHEMA_VERSION,
		"surface_contract_revision": 2,
		"underworld_contract_revision": 1,
		"provenance_contract_revision": 1,
		"stage_revisions": _current_stage_revisions(),
		"profile_revisions": _current_profile_revisions(),
		"seed_domain_descriptors": _capture_current_seed_domains(),
	}


static func validate_snapshot(snapshot_value: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	var required_fields: Array[String] = [
		"manifest_schema_version",
		"manifest_schema_prefix",
		"seed_schema_version",
		"stable_address_schema_version",
		"surface_contract_revision",
		"underworld_contract_revision",
		"provenance_contract_revision",
		"stage_entries",
		"profile_entries",
		"seed_domain_descriptors",
	]
	for field in required_fields:
		if not snapshot_value.has(field):
			failures.append("GeneratorManifest snapshot is missing field: " + field)

	if not failures.is_empty():
		return failures

	_validate_positive_int_field(
		failures, snapshot_value, "manifest_schema_version", "manifest schema"
	)
	_validate_non_empty_string_field(
		failures, snapshot_value, "manifest_schema_prefix", "manifest schema prefix"
	)
	_validate_positive_int_field(
		failures, snapshot_value, "seed_schema_version", "seed schema"
	)
	_validate_positive_int_field(
		failures, snapshot_value, "stable_address_schema_version", "StableAddress schema"
	)
	_validate_positive_int_field(
		failures, snapshot_value, "surface_contract_revision", "surface contract revision"
	)
	_validate_positive_int_field(
		failures, snapshot_value, "underworld_contract_revision", "Underworld contract revision"
	)
	_validate_positive_int_field(
		failures, snapshot_value, "provenance_contract_revision", "provenance contract revision"
	)

	failures.append_array(
		_validate_revision_entries("stage", snapshot_value["stage_entries"])
	)
	failures.append_array(
		_validate_revision_entries("profile", snapshot_value["profile_entries"])
	)
	failures.append_array(
		_validate_domain_descriptors(snapshot_value["seed_domain_descriptors"])
	)
	return failures


func _apply_snapshot(snapshot_value: Dictionary) -> void:
	_manifest_schema_version = int(snapshot_value.get("manifest_schema_version", 0))
	_manifest_schema_prefix = str(snapshot_value.get("manifest_schema_prefix", ""))
	_seed_schema_version = int(snapshot_value.get("seed_schema_version", 0))
	_stable_address_schema_version = int(
		snapshot_value.get("stable_address_schema_version", 0)
	)
	_surface_contract_revision = int(snapshot_value.get("surface_contract_revision", 0))
	_underworld_contract_revision = int(
		snapshot_value.get("underworld_contract_revision", 0)
	)
	_provenance_contract_revision = int(
		snapshot_value.get("provenance_contract_revision", 0)
	)
	_stage_entries = _copy_array_field(snapshot_value, "stage_entries")
	_profile_entries = _copy_array_field(snapshot_value, "profile_entries")
	_seed_domain_descriptors = _copy_array_field(
		snapshot_value, "seed_domain_descriptors"
	)


static func _current_stage_revisions() -> Dictionary:
	return {
		"macro_region": 1,
		"primary_topology": 1,
		"entrance_selection": 1,
		"secondary_connectivity": 1,
		"special_location_hooks": 1,
		"region_finalization": 1,
		"geometry_description": 1,
		"gateway.source_site": 1,
		"gateway.destination_site": 1,
		"gateway.link": 1,
	}


static func _current_profile_revisions() -> Dictionary:
	return {
		"depth_grammar": 1,
	}


static func _capture_current_seed_domains() -> Array:
	var descriptors: Array = []
	for domain in SeedDomains.all_domains():
		descriptors.append(
			{
				"domain_id": int(domain.domain_id),
				"revision": int(domain.revision),
				"readable_name": str(domain.readable_name),
			}
		)
	return descriptors


static func _revision_entries_from_dictionary(revisions: Dictionary) -> Array:
	var entries: Array = []
	for key_variant in revisions.keys():
		entries.append(
			{
				"id": str(key_variant),
				"revision": int(revisions[key_variant]),
			}
		)
	return entries


static func _revision_dictionary(entries: Array) -> Dictionary:
	var revisions: Dictionary = {}
	for entry_variant in entries:
		if typeof(entry_variant) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_variant
		revisions[str(entry.get("id", ""))] = int(entry.get("revision", 0))
	return revisions


static func _copy_array_field(source: Dictionary, field: String) -> Array:
	var value = source.get(field, [])
	if typeof(value) != TYPE_ARRAY:
		return []
	return value.duplicate(true)


static func _validate_positive_int_field(
	failures: Array[String],
	source: Dictionary,
	field: String,
	label: String
) -> void:
	var value = source.get(field)
	if typeof(value) != TYPE_INT or int(value) <= 0:
		failures.append("GeneratorManifest %s must be positive" % label)


static func _validate_non_empty_string_field(
	failures: Array[String],
	source: Dictionary,
	field: String,
	label: String
) -> void:
	var value = source.get(field)
	if typeof(value) != TYPE_STRING or str(value).is_empty():
		failures.append("GeneratorManifest %s must be non-empty" % label)


static func _validate_revision_entries(label: String, entries_variant) -> Array[String]:
	var failures: Array[String] = []
	if typeof(entries_variant) != TYPE_ARRAY:
		return ["GeneratorManifest %s entries must be an Array" % label]

	var seen: Dictionary = {}
	for entry_variant in entries_variant:
		if typeof(entry_variant) != TYPE_DICTIONARY:
			failures.append("GeneratorManifest %s entry must be a Dictionary" % label)
			continue
		var entry: Dictionary = entry_variant
		if not entry.has("id") or typeof(entry["id"]) != TYPE_STRING:
			failures.append("GeneratorManifest %s entry requires string id" % label)
			continue
		var key: String = str(entry["id"])
		if key.is_empty():
			failures.append("GeneratorManifest has empty %s revision key" % label)
		if seen.has(key):
			failures.append("GeneratorManifest has duplicate %s revision key: %s" % [label, key])
		seen[key] = true
		if not entry.has("revision") or typeof(entry["revision"]) != TYPE_INT:
			failures.append("GeneratorManifest %s revision must be an integer: %s" % [label, key])
		elif int(entry["revision"]) <= 0:
			failures.append("GeneratorManifest %s revision must be positive: %s" % [label, key])
	return failures


static func _validate_domain_descriptors(descriptors_variant) -> Array[String]:
	var failures: Array[String] = []
	if typeof(descriptors_variant) != TYPE_ARRAY:
		return ["GeneratorManifest seed-domain descriptors must be an Array"]

	var ids: Dictionary = {}
	var names: Dictionary = {}
	for descriptor_variant in descriptors_variant:
		if typeof(descriptor_variant) != TYPE_DICTIONARY:
			failures.append("GeneratorManifest seed-domain descriptor must be a Dictionary")
			continue
		var descriptor: Dictionary = descriptor_variant
		if not descriptor.has("domain_id") or typeof(descriptor["domain_id"]) != TYPE_INT:
			failures.append("GeneratorManifest seed-domain descriptor requires integer domain_id")
			continue
		if not descriptor.has("revision") or typeof(descriptor["revision"]) != TYPE_INT:
			failures.append("GeneratorManifest seed-domain descriptor requires integer revision")
			continue
		if not descriptor.has("readable_name") or typeof(descriptor["readable_name"]) != TYPE_STRING:
			failures.append("GeneratorManifest seed-domain descriptor requires string readable_name")
			continue

		var domain_id: int = int(descriptor["domain_id"])
		var revision: int = int(descriptor["revision"])
		var readable_name: String = str(descriptor["readable_name"])
		if domain_id <= 0:
			failures.append("GeneratorManifest seed-domain ID must be positive")
		if revision <= 0:
			failures.append("GeneratorManifest seed-domain revision must be positive: %08x" % domain_id)
		if readable_name.is_empty():
			failures.append("GeneratorManifest seed-domain readable name must be non-empty")
		if ids.has(domain_id):
			failures.append("GeneratorManifest has duplicate seed-domain ID: %08x" % domain_id)
		ids[domain_id] = true
		if names.has(readable_name):
			failures.append("GeneratorManifest has duplicate seed-domain name: " + readable_name)
		names[readable_name] = true
	return failures


static func _compare_exact_support(
	failures: Array[String],
	label: String,
	required_value,
	supported_value
) -> void:
	if required_value != supported_value:
		failures.append(
			"GeneratorManifest runtime does not support captured %s: required %s got %s"
			% [label, str(required_value), str(supported_value)]
		)


static func _compare_required_revision_entries(
	label: String,
	required_entries: Array,
	supported_variant
) -> Array[String]:
	var failures: Array[String] = []
	if typeof(supported_variant) != TYPE_DICTIONARY:
		return ["GeneratorManifest runtime %s support must be a Dictionary" % label]
	var supported: Dictionary = supported_variant
	for entry_variant in required_entries:
		if typeof(entry_variant) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_variant
		var key: String = str(entry.get("id", ""))
		var revision: int = int(entry.get("revision", 0))
		if not supported.has(key):
			failures.append("GeneratorManifest runtime is missing required %s: %s" % [label, key])
		elif int(supported[key]) != revision:
			failures.append(
				"GeneratorManifest runtime %s revision mismatch for %s: required %d got %d"
				% [label, key, revision, int(supported[key])]
			)
	return failures


static func _compare_required_domains(
	required_descriptors: Array,
	supported_variant
) -> Array[String]:
	var failures: Array[String] = []
	if typeof(supported_variant) != TYPE_ARRAY:
		return ["GeneratorManifest runtime seed-domain support must be an Array"]

	var supported_by_id: Dictionary = {}
	var supported_names: Dictionary = {}
	for descriptor_variant in supported_variant:
		if typeof(descriptor_variant) != TYPE_DICTIONARY:
			failures.append("GeneratorManifest runtime seed-domain support contains malformed descriptor")
			continue
		var descriptor: Dictionary = descriptor_variant
		var domain_id: int = int(descriptor.get("domain_id", 0))
		var readable_name: String = str(descriptor.get("readable_name", ""))
		if supported_by_id.has(domain_id):
			failures.append("GeneratorManifest runtime seed-domain support has duplicate ID: %08x" % domain_id)
		else:
			supported_by_id[domain_id] = descriptor
		if supported_names.has(readable_name):
			failures.append("GeneratorManifest runtime seed-domain support has duplicate name: " + readable_name)
		else:
			supported_names[readable_name] = true

	for descriptor_variant in required_descriptors:
		if typeof(descriptor_variant) != TYPE_DICTIONARY:
			continue
		var required: Dictionary = descriptor_variant
		var domain_id: int = int(required.get("domain_id", 0))
		if not supported_by_id.has(domain_id):
			failures.append("GeneratorManifest runtime is missing required seed-domain: %08x" % domain_id)
			continue
		var supported: Dictionary = supported_by_id[domain_id]
		if int(supported.get("revision", 0)) != int(required.get("revision", 0)):
			failures.append(
				"GeneratorManifest runtime seed-domain revision mismatch: %08x" % domain_id
			)
		if str(supported.get("readable_name", "")) != str(required.get("readable_name", "")):
			failures.append(
				"GeneratorManifest runtime seed-domain name mismatch: %08x" % domain_id
			)
	return failures


static func _append(base: String, value: String) -> String:
	return base + "|%d:%s" % [value.length(), value]
