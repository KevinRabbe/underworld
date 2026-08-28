extends "res://worldgen/surface/prototype_surface_settings.gd"
class_name UnderworldWorldSettings

# Runtime world configuration layered on top of deterministic surface-generation
# inputs. The legacy class name is retained temporarily because existing runtime
# terrain code still uses it as a type annotation; ownership is now world-only.

@export_group("Surface Streaming")
@export var load_radius: int = 2
@export var unload_radius: int = 3
@export var collision_radius: int = 1
@export var max_chunks_generated_per_frame: int = 1

@export_group("World Object Physics")
@export_range(8.0, 64.0, 1.0) var world_object_physics_radius: float = 28.0
@export_range(0.0, 16.0, 1.0) var world_object_release_margin: float = 6.0
@export_range(0.05, 1.0, 0.05) var world_object_update_interval: float = 0.15
@export_range(0.2, 2.0, 0.05) var tree_collider_radius: float = 0.70
@export_range(1.0, 8.0, 0.1) var tree_collider_height: float = 4.3
