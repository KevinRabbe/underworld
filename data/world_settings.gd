extends "res://worldgen/surface/prototype_surface_settings.gd"
class_name UnderworldWorldSettings

# Temporary prototype runtime aggregate.
#
# Deterministic surface-generation values are inherited from
# UnderworldPrototypeSurfaceSettings. This file now owns only live streaming,
# interaction/gameplay, physics and presentation configuration and remains under
# the legacy data/ root until those runtime responsibilities are split by domain.

@export_group("Surface Streaming")
@export var load_radius: int = 2
@export var unload_radius: int = 3
@export var collision_radius: int = 1
@export var max_chunks_generated_per_frame: int = 1

@export_group("Loose Pickup Runtime")
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
