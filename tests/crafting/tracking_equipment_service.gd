extends "res://gameplay/items/equipment/equipment_service.gd"

var attempts: int = 0
var reject_equips: bool = false


func equip_from_inventory(
	equipment_state,
	inventory,
	source_slot: int,
	definition,
	target_slot_key: String
) -> Dictionary:
	attempts += 1
	if reject_equips:
		return {
			"success": false,
			"diagnostics": ["injected progression equip rejection"],
			"events": [],
			"transaction_fingerprint": "",
			"operation_count": 0,
		}
	return super.equip_from_inventory(
		equipment_state,
		inventory,
		source_slot,
		definition,
		target_slot_key
	)
