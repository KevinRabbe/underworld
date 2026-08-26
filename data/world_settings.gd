extends Resource
class_name UnderworldWorldSettings

@export var world_seed: int = 12345
@export var chunk_size: float = 128.0
@export var vertices_per_side: int = 65
@export var load_radius: int = 2
@export var unload_radius: int = 3
@export var collision_radius: int = 1
@export var max_chunks_generated_per_frame: int = 1

@export_group("Terrain")
@export var macro_frequency: float = 0.0018
@export var macro_amplitude: float = 28.0
@export var detail_frequency: float = 0.013
@export var detail_amplitude: float = 5.0
