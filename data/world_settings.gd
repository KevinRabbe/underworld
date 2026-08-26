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
# Slightly larger forest patches make clearings read as regions instead of
# tiny holes inside otherwise uniform tree cover.
@export var forest_frequency: float = 0.0028
@export var rock_frequency: float = 0.0055
@export var shore_band: float = 2.5

@export_group("Prototype Decoration")
# Use a finer candidate grid but a lower probability. This reduces the visible
# one-tree-per-cell rhythm while keeping dense forest counts in roughly the
# same range as the previous pass.
@export_range(2, 12, 1) var decoration_vertex_step: int = 3
@export_range(0.0, 1.0, 0.01) var tree_threshold: float = 0.40
@export_range(0.0, 1.0, 0.01) var tree_density: float = 0.38
@export_range(0.0, 1.0, 0.01) var rock_threshold: float = 0.55
@export_range(0.0, 1.0, 0.01) var rock_density: float = 0.30

@export_group("Prototype Water")
@export var water_plane_size: float = 8192.0
