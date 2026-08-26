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
@export var base_height: float = 6.0
@export var continental_frequency: float = 0.00065
@export var continental_amplitude: float = 14.0
@export var rolling_frequency: float = 0.0028
@export var rolling_amplitude: float = 6.0
@export var flatland_frequency: float = 0.0017
@export var flatland_strength: float = 0.82
@export var ridge_frequency: float = 0.00155
@export var ridge_region_frequency: float = 0.00085
@export var ridge_amplitude: float = 15.0
@export var valley_frequency: float = 0.00125
@export var valley_depth: float = 9.0
@export var detail_frequency: float = 0.012
@export var detail_amplitude: float = 1.4

@export_group("Environment Masks")
@export var moisture_frequency: float = 0.0022
@export var forest_frequency: float = 0.0036
@export var rock_frequency: float = 0.0055
@export var shore_band: float = 2.5

@export_group("Prototype Water")
@export var water_plane_size: float = 8192.0
