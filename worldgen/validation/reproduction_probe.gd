extends RefCounted
class_name UnderworldReproductionProbe

const StableAddress := preload("res://worldgen/identity/stable_address.gd")
const StableId := preload("res://worldgen/identity/stable_id.gd")
const SeedDeriver := preload("res://worldgen/random/seed_deriver.gd")
const SeedDomains := preload("res://worldgen/random/seed_domains.gd")
const GeneratorManifest := preload("res://worldgen/versioning/generator_manifest.gd")
const WorldGenerationContext := preload("res://worldgen/pipeline/world_generation_context.gd")
const CanonicalValue := preload("res://worldgen/validation/canonical_value.gd")


static func build(world_seed: int, region_coord: Vector2i) -> Dictionary:
	var manifest = GeneratorManifest.foundation_default()
	var context = WorldGenerationContext.new(world_seed, manifest)
	var region_address = StableAddress.underground_region(region_coord.x, region_coord.y)
	var region_id: String = StableId.from_address(region_address).value()

	var seed_values: Dictionary = {
		"region_layout": SeedDeriver.derive_u32(
			world_seed,
			region_address,
			SeedDomains.get_domain(SeedDomains.UG_REGION_LAYOUT),
			"probe"
		),
		"network_exists": SeedDeriver.derive_u32(
			world_seed,
			region_address,
			SeedDomains.get_domain(SeedDomains.UG_NETWORK_EXISTS),
			"probe"
		),
		"network_topology": SeedDeriver.derive_u32(
			world_seed,
			region_address,
			SeedDomains.get_domain(SeedDomains.UG_NETWORK_TOPOLOGY),
			"probe"
		),
		"entrance_selection": SeedDeriver.derive_u32(
			world_seed,
			region_address,
			SeedDomains.get_domain(SeedDomains.UG_ENTRANCE_SELECTION),
			"probe"
		),
		"secondary_connectivity": SeedDeriver.derive_u32(
			world_seed,
			region_address,
			SeedDomains.get_domain(SeedDomains.UG_SECONDARY_EXISTS),
			"probe"
		),
	}

	var payload: Dictionary = {
		"world_seed": world_seed,
		"world_id": context.world_id,
		"generator_manifest_id": context.generator_manifest_id,
		"region_coord": region_coord,
		"region_address": region_address.canonical_text(),
		"region_id": region_id,
		"seed_values": seed_values,
	}
	var canonical: String = CanonicalValue.encode(payload)
	return {
		"payload": payload,
		"canonical": canonical,
		"fingerprint": "probe-sha256:" + canonical.sha256_text(),
	}
