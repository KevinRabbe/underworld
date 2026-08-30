extends "res://gameplay/survival/prototype_survival_controller.gd"

const IntegratedItemContainerState := preload("res://gameplay/items/inventory/item_container_state.gd")
const IntegratedEquipmentHotbarState := preload("res://gameplay/items/equipment/equipment_hotbar_state.gd")
const IntegratedSurfaceHarvestInventoryService := preload("res://gameplay/survival/surface_harvest_inventory_service.gd")


func configure_integrated(
	world_node,
	survival_settings,
	seed: int,
	inventory_slot_capacity: int = DEFAULT_INVENTORY_SLOTS,
	inventory_max_weight: float = UNLIMITED_WEIGHT
) -> void:
	# Base configure is now itself clean semantic-only startup: SAVE-001 removed
	# prototype-v2 file authority at source rather than hiding it behind overrides.
	configure(
		world_node,
		survival_settings,
		seed,
		inventory_slot_capacity,
		inventory_max_weight
	)


func activate_restored_state(
	inventory_state,
	equipment_state
) -> Array[String]:
	var failures: Array[String] = []
	if inventory_state == null or not inventory_state is IntegratedItemContainerState:
		failures.append("integrated survival restore requires ItemContainerState")
	else:
		for diagnostic in inventory_state.validate_container():
			failures.append("restored inventory: %s" % diagnostic)
	if equipment_state == null or not equipment_state is IntegratedEquipmentHotbarState:
		failures.append("integrated survival restore requires EquipmentHotbarState")
	else:
		for diagnostic in equipment_state.validate_state():
			failures.append("restored equipment: %s" % diagnostic)
	if not failures.is_empty():
		failures.sort()
		return failures

	_inventory = inventory_state
	_equipment = equipment_state
	_harvest_inventory = IntegratedSurfaceHarvestInventoryService.new().configure(
		_inventory,
		_equipment,
		_definitions.values()
	)
	if _harvest_inventory == null:
		return ["integrated survival could not rebuild harvest/inventory adapter"]
	_sync_legacy_mirrors()
	if player != null:
		equipped_tool_changed.emit(equipped_tool)
	return []
