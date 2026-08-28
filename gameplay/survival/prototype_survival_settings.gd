extends Resource

@export_group("Loose Pickup Runtime")
@export_range(0.5, 3.0, 0.1) var pickup_collect_radius: float = 1.5
@export_range(0.05, 1.0, 0.05) var pickup_collect_interval: float = 0.15

@export_group("Harvesting")
@export_range(2.0, 8.0, 0.25) var harvest_range: float = 4.5
@export_range(0.10, 1.0, 0.05) var tool_use_cooldown: float = 0.38
@export_range(1, 10, 1) var tree_hits_with_axe: int = 3
@export_range(1, 10, 1) var rock_hits_with_pickaxe: int = 4
@export_range(1, 20, 1) var tree_wood_yield: int = 4
@export_range(1, 20, 1) var rock_stone_yield: int = 3

@export_group("Stone Tool Crafting")
@export_range(0, 20, 1) var stone_axe_wood_cost: int = 4
@export_range(0, 20, 1) var stone_axe_stone_cost: int = 3
@export_range(0, 20, 1) var stone_pickaxe_wood_cost: int = 3
@export_range(0, 20, 1) var stone_pickaxe_stone_cost: int = 4
