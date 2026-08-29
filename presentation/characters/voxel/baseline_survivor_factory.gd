extends RefCounted
class_name UnderworldBaselineVoxelSurvivorFactory

const PaletteScript := preload("res://presentation/characters/voxel/voxel_character_palette_definition.gd")
const ModuleScript := preload("res://presentation/characters/voxel/voxel_character_module_definition.gd")
const CharacterScript := preload("res://presentation/characters/voxel/voxel_character_definition.gd")

const SKIN := 0
const CLOTH := 1
const LEATHER := 2
const METAL := 3
const HAIR := 4
const ACCENT := 5
const FACE := 6
const CANVAS_LIGHT := 7
const TROUSER := 8


static func build() -> Resource:
	var palette = PaletteScript.new().configure("palette.character.earth_teal", [
		_entry("skin", Color("c39570"), 0.78, 0.0),
		_entry("cloth", Color("716655"), 0.92, 0.0),
		_entry("leather", Color("503a2b"), 0.76, 0.0),
		_entry("metal", Color("858b8e"), 0.38, 0.62),
		_entry("hair", Color("392820"), 0.88, 0.0),
		_entry("accent", Color("2e7180"), 0.82, 0.0),
		_entry("face", Color("171717"), 0.72, 0.0),
		_entry("canvas_light", Color("9a896a"), 0.94, 0.0),
		_entry("trouser", Color("343835"), 0.90, 0.0),
	])
	var modules: Array[Resource] = [
		_module("body", &"body_base", [
			_part("pelvis", "rig_role.pelvis", _box(Vector3i(-2,-1,-1), Vector3i(1,1,1), TROUSER), Vector3i.ZERO),
			_part("spine", "rig_role.spine.lower", _box(Vector3i(-2,-1,-1), Vector3i(1,6,1), CANVAS_LIGHT), Vector3i(0,1,0)),
			_part("chest", "rig_role.chest", _box(Vector3i(-3,-1,-1), Vector3i(2,3,1), CANVAS_LIGHT), Vector3i(0,0,0)),
		]),
		_module("head", &"head_hair", [
			_part("head_skin", "rig_role.head", _head_cells(), Vector3i(0,1,0)),
			_part("hair", "rig_role.head", _hair_cells(), Vector3i(0,1,0)),
			_part("face", "rig_role.head", _face_cells(), Vector3i(0,1,0)),
		]),
		_module("jacket", &"torso_outfit", [
			_part("jacket_front", "rig_role.chest", _jacket_front_cells(), Vector3i.ZERO),
			_part("shoulder_l", "rig_role.clavicle.left", _box(Vector3i(-2,-1,-1), Vector3i(1,1,1), CLOTH), Vector3i.ZERO),
			_part("shoulder_r", "rig_role.clavicle.right", _box(Vector3i(-1,-1,-1), Vector3i(2,1,1), CLOTH), Vector3i.ZERO),
			_part("neck_connector", "rig_role.neck", _box(Vector3i(-1,-2,-1), Vector3i(0,0,1), CLOTH), Vector3i.ZERO),
			_part("upperarm_l", "rig_role.upper_arm.left", _box(Vector3i(-5,-1,-1), Vector3i(0,1,1), CLOTH), Vector3i(-1,0,0)),
			_part("forearm_l", "rig_role.forearm.left", _box(Vector3i(-5,-1,-1), Vector3i(0,0,1), LEATHER), Vector3i(-1,0,0)),
			_part("upperarm_r", "rig_role.upper_arm.right", _box(Vector3i(0,-1,-1), Vector3i(5,1,1), CLOTH), Vector3i(1,0,0)),
			_part("forearm_r", "rig_role.forearm.right", _box(Vector3i(0,-1,-1), Vector3i(5,0,1), LEATHER), Vector3i(1,0,0)),
			_part("scarf", "rig_role.neck", _box(Vector3i(-2,-1,-2), Vector3i(1,1,1), ACCENT), Vector3i(0,0,0)),
			_part("belt", "rig_role.pelvis", _box(Vector3i(-3,1,-2), Vector3i(2,2,1), LEATHER), Vector3i(0,0,0)),
			_part("pack_straps", "rig_role.chest", _pack_strap_cells(), Vector3i.ZERO),
		]),
		_module("trousers", &"leg_outfit", [
			_part("thigh_l", "rig_role.thigh.left", _box(Vector3i(-1,-8,-1), Vector3i(1,0,1), TROUSER), Vector3i(0,-1,0)),
			_part("calf_l", "rig_role.calf.left", _box(Vector3i(-1,-7,-1), Vector3i(1,0,1), TROUSER), Vector3i(0,-1,0)),
			_part("thigh_r", "rig_role.thigh.right", _box(Vector3i(-1,-8,-1), Vector3i(1,0,1), TROUSER), Vector3i(0,-1,0)),
			_part("calf_r", "rig_role.calf.right", _box(Vector3i(-1,-7,-1), Vector3i(1,0,1), TROUSER), Vector3i(0,-1,0)),
			_part("knee_l", "rig_role.calf.left", _box(Vector3i(-1,-1,-2), Vector3i(1,1,-2), LEATHER), Vector3i.ZERO),
			_part("knee_r", "rig_role.calf.right", _box(Vector3i(-1,-1,-2), Vector3i(1,1,-2), LEATHER), Vector3i.ZERO),
		]),
		_module("gloves", &"hands", [
			_part("hand_l", "rig_role.hand.left", _box(Vector3i(-2,-1,-1), Vector3i(0,1,1), LEATHER), Vector3i(-1,0,0)),
			_mirrored_part("hand_r", "rig_role.hand.right", "hand_l", Vector3i(1,0,0)),
		]),
		_module("boots", &"feet", [
			_part("foot_l", "rig_role.foot.left", _box(Vector3i(-1,-1,-1), Vector3i(1,1,4), LEATHER), Vector3i(0,0,0)),
			_part("foot_r", "rig_role.foot.right", _box(Vector3i(-1,-1,-1), Vector3i(1,1,4), LEATHER), Vector3i(0,0,0)),
		]),
		_module("pouch", &"back_accessory", [
			_part("hip_pouch", "rig_role.pelvis", _box(Vector3i(3,-1,1), Vector3i(5,2,2), LEATHER), Vector3i.ZERO),
			_part("expedition_pack", "rig_role.chest", _box(Vector3i(-3,-2,2), Vector3i(2,3,4), CLOTH), Vector3i.ZERO),
			_part("pack_roll", "rig_role.chest", _box(Vector3i(-3,3,2), Vector3i(2,4,4), LEATHER), Vector3i.ZERO),
		]),
		_module("tools", &"held_item", [
			_tool_part("axe_handle", "stone_axe", _box(Vector3i(0,-7,0), Vector3i(0,4,0), LEATHER), Vector3i.ZERO),
			_tool_part("axe_head", "stone_axe", _box(Vector3i(-3,3,0), Vector3i(3,5,1), METAL), Vector3i.ZERO),
			_tool_part("pickaxe_handle", "stone_pickaxe", _box(Vector3i(0,-7,0), Vector3i(0,4,0), LEATHER), Vector3i.ZERO),
			_tool_part("pickaxe_head", "stone_pickaxe", _pickaxe_head_cells(), Vector3i.ZERO),
		]),
	]
	var character := CharacterScript.new()
	character.presentation_id = "character.voxel.grounded_survivor"
	character.rig_profile_id = "rig_profile.humanoid.prototype"
	character.voxel_size = 0.05
	character.presentation_scale = 1.0
	character.presentation_bounds = AABB(Vector3(-0.45, 0.0, -0.30), Vector3(0.90, 1.80, 0.60))
	character.palette = palette
	character.modules = modules
	return character


static func _entry(slot: String, color: Color, roughness: float, metallic: float) -> Dictionary:
	return {"slot": slot, "color": color, "roughness": roughness, "metallic": metallic, "emission": 0.0}


static func _module(suffix: String, slot: StringName, parts: Array[Dictionary]) -> Resource:
	return ModuleScript.new().configure("module.survivor.%s" % suffix, slot, parts)


static func _part(id_value: String, rig_role: String, cells: Array[Dictionary], pivot: Vector3i) -> Dictionary:
	return {"part_id": id_value, "rig_role": rig_role, "pivot": pivot, "attachment_offset": Vector3.ZERO, "cells": cells}


static func _tool_part(id_value: String, variant_id: String, cells: Array[Dictionary], pivot: Vector3i) -> Dictionary:
	var part := _part(id_value, "rig_role.socket.hand.right", cells, pivot)
	part["variant_id"] = variant_id
	return part


static func _mirrored_part(id_value: String, rig_role: String, mirror_source: String, pivot: Vector3i) -> Dictionary:
	return {"part_id": id_value, "rig_role": rig_role, "pivot": pivot, "attachment_offset": Vector3.ZERO, "mirror_source": mirror_source, "cells": []}


static func _box(minimum: Vector3i, maximum: Vector3i, palette_index: int) -> Array[Dictionary]:
	var cells: Array[Dictionary] = []
	for z in range(minimum.z, maximum.z + 1):
		for y in range(minimum.y, maximum.y + 1):
			for x in range(minimum.x, maximum.x + 1):
				cells.append({"position": Vector3i(x,y,z), "palette_index": palette_index})
	return cells


static func _head_cells() -> Array[Dictionary]:
	var cells: Array[Dictionary] = []
	for z in range(-2, 2):
		for y in range(0, 5):
			for x in range(-2, 2):
				var corner_cut := y == 4 and (x == -2 or x == 1) and (z == -2 or z == 1)
				if not corner_cut:
					cells.append({"position": Vector3i(x,y,z), "palette_index": SKIN})
	return cells


static func _hair_cells() -> Array[Dictionary]:
	var cells := _box(Vector3i(-2,4,-2), Vector3i(1,5,1), HAIR)
	cells.append_array(_box(Vector3i(-2,1,1), Vector3i(1,3,2), HAIR))
	cells.append_array(_box(Vector3i(-3,2,-1), Vector3i(-3,4,1), HAIR))
	return cells


static func _face_cells() -> Array[Dictionary]:
	return [
		{"position": Vector3i(-1,3,-3), "palette_index": FACE},
		{"position": Vector3i(1,3,-3), "palette_index": FACE},
		{"position": Vector3i(0,2,-3), "palette_index": SKIN},
	]


static func _jacket_front_cells() -> Array[Dictionary]:
	var cells := _box(Vector3i(-4,-1,-2), Vector3i(-2,3,-2), CLOTH)
	cells.append_array(_box(Vector3i(1,-1,-2), Vector3i(3,3,-2), CLOTH))
	cells.append_array(_box(Vector3i(-1,-1,-2), Vector3i(0,0,-2), LEATHER))
	return cells


static func _pack_strap_cells() -> Array[Dictionary]:
	var cells := _box(Vector3i(-3,-1,-3), Vector3i(-3,3,-3), LEATHER)
	cells.append_array(_box(Vector3i(2,-1,-3), Vector3i(2,3,-3), LEATHER))
	return cells


static func _pickaxe_head_cells() -> Array[Dictionary]:
	var cells: Array[Dictionary] = []
	for x in range(-5, 6):
		var y: int = 4 - absi(x) / 3
		cells.append({"position": Vector3i(x, y, 0), "palette_index": METAL})
		cells.append({"position": Vector3i(x, y, 1), "palette_index": METAL})
	return cells
