extends RefCounted

const GameplayStateCodec := preload("res://gameplay/persistence/gameplay_state_codec.gd")
const GameplaySaveCatalog := preload("res://gameplay/persistence/gameplay_save_catalog.gd")


static func build_registry() -> Dictionary:
	return GameplaySaveCatalog.build_registry()


static func validate_pending_loot(pending, content_registry) -> Dictionary:
	return GameplayStateCodec.encode_pending_loot(pending, content_registry)


static func validate_player_vitals(
	current_health: Variant,
	current_stamina: Variant
) -> Dictionary:
	return GameplayStateCodec.encode_player_vitals(current_health, current_stamina)
