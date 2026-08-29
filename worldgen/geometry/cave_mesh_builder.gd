extends RefCounted
class_name UnderworldCaveMeshBuilder

const Mesher := preload("res://worldgen/geometry/cave_voxel_mesher_cached.gd")


static func prepare(request):
	return Mesher.build(request)


static func build(request):
	return Mesher.build(request)
