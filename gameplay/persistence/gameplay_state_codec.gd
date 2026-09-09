extends RefCounted

const InventoryEquipmentCodec := preload("res://gameplay/persistence/codecs/inventory_equipment_codec.gd")
const PlayerVitalsCodec := preload("res://gameplay/persistence/codecs/player_vitals_codec.gd")
const PendingLootCodec := preload("res://gameplay/persistence/codecs/pending_loot_codec.gd")

const INVENTORY_SCHEMA := InventoryEquipmentCodec.INVENTORY_SCHEMA
const EQUIPMENT_SCHEMA := InventoryEquipmentCodec.EQUIPMENT_SCHEMA
const PENDING_LOOT_SCHEMA := PendingLootCodec.PENDING_LOOT_SCHEMA
const PLAYER_VITALS_SCHEMA := PlayerVitalsCodec.PLAYER_VITALS_SCHEMA
const ITEM_FAMILY := "item"
const LOOT_PROFILE_FAMILY := "loot_profile"

const INVENTORY_ROOT_KEYS := ["schema", "slot_capacity", "max_weight", "slots"]
const INVENTORY_RECORD_KEYS := ["slot", "kind", "state", "definition_contract"]
const EQUIPMENT_ROOT_KEYS := ["schema", "selected_hotbar", "selected_slot_key", "slots"]
const EQUIPMENT_RECORD_KEYS := ["slot_key", "kind", "state", "definition_contract"]
const PENDING_LOOT_ROOT_KEYS := ["schema", "occurrence_id", "profile_id", "rewards", "consumed"]
const PENDING_LOOT_REWARD_KEYS := ["item_id", "quantity", "definition_contract"]
const PLAYER_VITALS_ROOT_KEYS := ["schema", "current_health", "current_stamina"]


static func encode_inventory(container, content_registry) -> Dictionary:
	return InventoryEquipmentCodec.encode_inventory(container, content_registry)


static func decode_inventory(snapshot: Variant, content_registry) -> Dictionary:
	return InventoryEquipmentCodec.decode_inventory(snapshot, content_registry)


static func encode_equipment(equipment, content_registry) -> Dictionary:
	return InventoryEquipmentCodec.encode_equipment(equipment, content_registry)


static func decode_equipment(
	snapshot: Variant,
	content_registry,
	current_rules: Array,
	current_hotbar_bindings: Dictionary
) -> Dictionary:
	return InventoryEquipmentCodec.decode_equipment(
		snapshot,
		content_registry,
		current_rules,
		current_hotbar_bindings
	)


static func encode_player_vitals(current_health: Variant, current_stamina: Variant) -> Dictionary:
	return PlayerVitalsCodec.encode(current_health, current_stamina)


static func decode_player_vitals(snapshot: Variant) -> Dictionary:
	return PlayerVitalsCodec.decode(snapshot)


static func encode_pending_loot(pending, content_registry) -> Dictionary:
	return PendingLootCodec.encode(pending, content_registry)


static func decode_pending_loot(snapshot: Variant, content_registry) -> Dictionary:
	return PendingLootCodec.decode(snapshot, content_registry)
