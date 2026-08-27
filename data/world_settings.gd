extends Resource
class_name UnderworldWorldSettings

@export var world_seed: int = 12345
@export var chunk_size: float = 128.0
@export var vertices_per_side: int = 65
@export var load_radius: int = 2
@export var unload_radius: int = 3
@export var collision_radius: int = 1
@export var max_chunks_generated_per_frame: int = 1

@export_group("World Shape")
@export var sea_level: float = 0.0
@export var base_height: float = 8.0
@export var continental_frequency: float = 0.00055
@export var continental_amplitude: float = 18.0
@export var rolling_frequency: float = 0.0026
@export var rolling_amplitude: float = 6.0
@export var flatland_frequency: float = 0.00145
@export var flatland_strength: float = 0.90
@export var ridge_frequency: float = 0.00135
@export var ridge_region_frequency: float = 0.00075
@export var ridge_amplitude: float = 22.0
@export var valley_frequency: float = 0.00115
@export var valley_depth: float = 10.0
@export var detail_frequency: float = 0.012
@export var detail_amplitude: float = 1.2

@export_group("Environment Masks")
@export var moisture_frequency: float = 0.0022
@export var forest_frequency: float = 0.0028
@export var rock_frequency: float = 0.0055
@export var shore_band: float = 2.5

@export_group("Prototype Decoration")
@export_range(2, 12, 1) var decoration_vertex_step: int = 3
@export_range(0.0, 1.0, 0.01) var tree_threshold: float = 0.40
@export_range(0.0, 1.0, 0.01) var tree_density: float = 0.38
@export_range(0.0, 1.0, 0.01) var rock_threshold: float = 0.55
@export_range(0.0, 1.0, 0.01) var rock_density: float = 0.30

@export_group("Loose Pickups")
# Pickup density is intentionally frozen for v0.05 because collected pickup
# persistence currently uses deterministic array indices. The next migration
# moves pickups to stable cell IDs before density is retuned.
@export_range(2, 12, 1) var pickup_vertex_step: int = 5
@export_range(0.0, 1.0, 0.01) var branch_pickup_density: float = 0.16
@export_range(0.0, 1.0, 0.01) var loose_stone_pickup_density: float = 0.13
@export_range(0.5, 3.0, 0.1) var pickup_collect_radius: float = 1.5

@export_group("World Object Physics")
@export_range(8.0, 64.0, 1.0) var world_object_physics_radius: float = 28.0
@export_range(0.0, 16.0, 1.0) var world_object_release_margin: float = 6.0
@export_range(0.05, 1.0, 0.05) var world_object_update_interval: float = 0.15
@export_range(0.2, 2.0, 0.05) var tree_collider_radius: float = 0.70
@export_range(1.0, 8.0, 0.1) var tree_collider_height: float = 4.3

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

@export_group("Prototype Water")
@export var water_plane_size: float = 8192.0
