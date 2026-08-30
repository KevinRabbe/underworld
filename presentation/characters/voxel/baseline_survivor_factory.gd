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
const CANVAS_DARK := 9
const LEATHER_LIGHT := 10
const SOLE := 11
const PRESENTATION_VOXEL_SIZE := 0.032142857
const DETAIL_SCALE := 1.555555556 # 36 authored voxels -> 56-voxel presentation


static func build() -> Resource:
	var palette = PaletteScript.new().configure("palette.character.earth_teal", [
		_entry("skin", Color("c39570"), 0.78, 0.0),
		_entry("cloth", Color("716655"), 0.92, 0.0),
		_entry("leather", Color("503a2b"), 0.76, 0.0),
		_entry("metal", Color("858b8e"), 0.38, 0.62),
		_entry("hair", Color("4a3326"), 0.88, 0.0),
		_entry("accent", Color("2e7180"), 0.82, 0.0),
		_entry("face", Color("4a392d"), 0.72, 0.0),
		_entry("canvas_light", Color("9a896a"), 0.94, 0.0),
		_entry("trouser", Color("343835"), 0.90, 0.0),
		_entry("canvas_dark", Color("5b5445"), 0.95, 0.0),
		_entry("leather_light", Color("75543a"), 0.80, 0.0),
		_entry("sole", Color("252523"), 0.98, 0.0),
	])
	var modules: Array[Resource] = [
		_module("body", &"body_base", [
			_part("pelvis", "rig_role.pelvis", _box(Vector3i(-2,-1,-1), Vector3i(2,1,1), TROUSER), Vector3i.ZERO),
			_part("spine", "rig_role.spine.lower", _box(Vector3i(-2,-1,-1), Vector3i(2,6,1), CANVAS_LIGHT), Vector3i(0,1,0)),
			_part("chest", "rig_role.chest", _box(Vector3i(-3,-1,-1), Vector3i(3,3,1), CANVAS_LIGHT), Vector3i(0,0,0)),
		]),
		_module("head", &"head_hair", [
			_part("head_skin", "rig_role.head", _head_cells(), Vector3i(0,1,0)),
			_part("hair", "rig_role.head", _hair_cells(), Vector3i(0,1,0)),
			_part("face", "rig_role.head", _face_cells(), Vector3i(0,1,0)),
		]),
		_module("jacket", &"torso_outfit", [
			_part("jacket_front", "rig_role.chest", _jacket_front_cells(), Vector3i.ZERO),
			_part("jacket_trim", "rig_role.chest", _jacket_trim_cells(), Vector3i.ZERO),
			_part("jacket_lower", "rig_role.spine.lower", _jacket_lower_cells(), Vector3i(0,1,0)),
			_part("shoulder_l", "rig_role.clavicle.left", _box(Vector3i(-2,-1,-1), Vector3i(1,1,1), CLOTH), Vector3i.ZERO),
			_part("shoulder_r", "rig_role.clavicle.right", _box(Vector3i(-1,-1,-1), Vector3i(2,1,1), CLOTH), Vector3i.ZERO),
			_part("neck_connector", "rig_role.neck", _box(Vector3i(-1,-2,-1), Vector3i(0,0,1), CLOTH), Vector3i.ZERO),
			_part("upperarm_l", "rig_role.upper_arm.left", _upper_arm_cells(true), Vector3i(-1,0,0)),
			_part("forearm_l", "rig_role.forearm.left", _box(Vector3i(-5,-1,-1), Vector3i(0,0,1), LEATHER), Vector3i(-1,0,0)),
			_part("upperarm_r", "rig_role.upper_arm.right", _upper_arm_cells(false), Vector3i(1,0,0)),
			_part("forearm_r", "rig_role.forearm.right", _box(Vector3i(0,-1,-1), Vector3i(5,0,1), LEATHER), Vector3i(1,0,0)),
			_part("scarf", "rig_role.neck", _box(Vector3i(-2,-1,-2), Vector3i(1,1,1), ACCENT), Vector3i(0,0,0)),
			_part("belt", "rig_role.pelvis", _box(Vector3i(-3,1,-2), Vector3i(2,2,1), LEATHER), Vector3i(0,0,0)),
			_part("belt_buckle", "rig_role.pelvis", _box(Vector3i(0,1,-3), Vector3i(1,2,-3), METAL), Vector3i.ZERO),
			_part("pack_straps", "rig_role.chest", _pack_strap_cells(), Vector3i.ZERO),
		]),
		_module("trousers", &"leg_outfit", [
			_part("thigh_l", "rig_role.thigh.left", _box(Vector3i(-1,-8,-1), Vector3i(1,0,1), TROUSER), Vector3i(0,-1,0)),
			_part("calf_l", "rig_role.calf.left", _box(Vector3i(-1,-2,-1), Vector3i(1,0,1), TROUSER), Vector3i(0,-1,0)),
			_part("thigh_r", "rig_role.thigh.right", _box(Vector3i(-1,-8,-1), Vector3i(1,0,1), TROUSER), Vector3i(0,-1,0)),
			_part("calf_r", "rig_role.calf.right", _box(Vector3i(-1,-2,-1), Vector3i(1,0,1), TROUSER), Vector3i(0,-1,0)),
			_part("knee_l", "rig_role.calf.left", _box(Vector3i(-1,-1,-2), Vector3i(1,1,-2), LEATHER), Vector3i.ZERO),
			_part("knee_r", "rig_role.calf.right", _box(Vector3i(-1,-1,-2), Vector3i(1,1,-2), LEATHER), Vector3i.ZERO),
			_part("boot_shaft_l", "rig_role.calf.left", _box(Vector3i(-1,-7,-1), Vector3i(1,-3,1), LEATHER), Vector3i(0,-1,0)),
			_part("boot_shaft_r", "rig_role.calf.right", _box(Vector3i(-1,-7,-1), Vector3i(1,-3,1), LEATHER), Vector3i(0,-1,0)),
		]),
		_module("gloves", &"hands", [
			_part("hand_l", "rig_role.hand.left", _box(Vector3i(-2,-1,-1), Vector3i(0,1,1), LEATHER), Vector3i(-1,0,0)),
			_mirrored_part("hand_r", "rig_role.hand.right", "hand_l", Vector3i(1,0,0)),
		]),
		_module("boots", &"feet", [
			_part("foot_l", "rig_role.foot.left", _boot_cells(), Vector3i(0,0,0)),
			_part("foot_r", "rig_role.foot.right", _boot_cells(), Vector3i(0,0,0)),
		]),
		_module("pouch", &"back_accessory", [
			_part("hip_pouch", "rig_role.pelvis", _box(Vector3i(3,-1,1), Vector3i(5,2,2), LEATHER), Vector3i.ZERO),
			_part("expedition_pack", "rig_role.chest", _expedition_pack_cells(), Vector3i.ZERO),
			_part("pack_roll", "rig_role.chest", _pack_roll_cells(), Vector3i.ZERO),
			_part("pack_buckles", "rig_role.chest", _pack_buckle_cells(), Vector3i.ZERO),
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
	# The gameplay body remains 1.8 m tall, while the authored presentation
	# grid is raised from the original 36 voxels to approximately 56.  This is
	# presentation-only; rig, sockets, collision, and action dimensions stay
	# in metres and are deliberately unchanged.
	character.voxel_size = PRESENTATION_VOXEL_SIZE
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
	return {"part_id": id_value, "rig_role": rig_role, "pivot": _scale_grid(pivot), "attachment_offset": Vector3.ZERO, "cells": _scale_cells(cells)}


static func _tool_part(id_value: String, variant_id: String, cells: Array[Dictionary], pivot: Vector3i) -> Dictionary:
	var part := _part(id_value, "rig_role.socket.hand.right", cells, pivot)
	part["variant_id"] = variant_id
	return part


static func _scale_grid(value: Vector3i) -> Vector3i:
	return Vector3i(floori(float(value.x) * DETAIL_SCALE), floori(float(value.y) * DETAIL_SCALE), floori(float(value.z) * DETAIL_SCALE))


static func _scale_cells(cells: Array[Dictionary]) -> Array[Dictionary]:
	var scaled: Array[Dictionary] = []
	var occupied: Dictionary = {}
	for cell_value in cells:
		var cell: Dictionary = cell_value
		if not cell.get("position", null) is Vector3i:
			continue
		var source: Vector3i = cell["position"]
		# Expand each source voxel over the complete half-open interval it
		# occupies. Scaling only its centre creates 1-cell holes and spikes
		# whenever the scale factor is non-integral (the defect seen in the first
		# 56-voxel preview).
		var minimum := _scale_grid(source)
		var maximum := Vector3i(
			ceili(float(source.x + 1) * DETAIL_SCALE) - 1,
			ceili(float(source.y + 1) * DETAIL_SCALE) - 1,
			ceili(float(source.z + 1) * DETAIL_SCALE) - 1
		)
		for z in range(minimum.z, maximum.z + 1):
			for y in range(minimum.y, maximum.y + 1):
				for x in range(minimum.x, maximum.x + 1):
					var position := Vector3i(x, y, z)
					var key := "%d,%d,%d" % [x, y, z]
					if occupied.has(key):
						continue
					occupied[key] = true
					scaled.append({"position": position, "palette_index": int(cell.get("palette_index", -1))})
	return scaled


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
		for y in range(0, 6):
			for x in range(-2, 3):
				var corner_cut := y == 5 and (x == -2 or x == 2) and (z == -2 or z == 1)
				var face_inlay := z == -2 and ((y == 3 and x in [-1, 1]) or (y == 1 and x == 0))
				if not corner_cut and not face_inlay:
					cells.append({"position": Vector3i(x,y,z), "palette_index": SKIN})
	# Small ears break the box silhouette without changing the semantic head rig.
	cells.append({"position": Vector3i(-3,2,-1), "palette_index": SKIN})
	cells.append({"position": Vector3i(3,2,-1), "palette_index": SKIN})
	return cells


static func _hair_cells() -> Array[Dictionary]:
	var cells: Array[Dictionary] = []
	for z in range(-2, 2):
		for y in range(4, 6):
			for x in range(-2, 3):
				if not (y == 5 and abs(x) == 2):
					cells.append({"position": Vector3i(x,y,z), "palette_index": HAIR})
	# Short back and side layers keep the head readable from the rear without
	# creating the previous solid helmet slab.
	cells.append_array(_box(Vector3i(-2,1,1), Vector3i(2,3,2), HAIR))
	cells.append_array(_box(Vector3i(-3,2,0), Vector3i(-3,4,1), HAIR))
	cells.append_array(_box(Vector3i(3,2,0), Vector3i(3,4,1), HAIR))
	cells.append_array(_box(Vector3i(-2,4,-3), Vector3i(0,5,-3), HAIR))
	return cells


static func _face_cells() -> Array[Dictionary]:
	return [
		{"position": Vector3i(-1,3,-2), "palette_index": FACE},
		{"position": Vector3i(1,3,-2), "palette_index": FACE},
		{"position": Vector3i(0,1,-2), "palette_index": FACE},
	]


static func _jacket_front_cells() -> Array[Dictionary]:
	var cells := _box(Vector3i(-4,-1,-2), Vector3i(-2,3,-2), CLOTH)
	cells.append_array(_box(Vector3i(1,-1,-2), Vector3i(3,3,-2), CLOTH))
	cells.append_array(_box(Vector3i(-1,-1,-2), Vector3i(0,0,-2), LEATHER))
	return cells


static func _jacket_trim_cells() -> Array[Dictionary]:
	return [
		{"position": Vector3i(-2,3,-3), "palette_index": CANVAS_LIGHT},
		{"position": Vector3i(-1,2,-3), "palette_index": CANVAS_LIGHT},
		{"position": Vector3i(1,2,-3), "palette_index": CANVAS_LIGHT},
		{"position": Vector3i(2,3,-3), "palette_index": CANVAS_LIGHT},
		{"position": Vector3i(0,1,-3), "palette_index": LEATHER_LIGHT},
		{"position": Vector3i(0,-1,-3), "palette_index": METAL},
	]


static func _upper_arm_cells(left: bool) -> Array[Dictionary]:
	var minimum_x: int = -5 if left else 0
	var maximum_x: int = 0 if left else 5
	var cells: Array[Dictionary] = []
	for z in range(-1, 2):
		for y in range(-1, 2):
			for x in range(minimum_x, maximum_x + 1):
				var distance_from_shoulder: int = -x if left else x
				var palette_index: int = ACCENT if left and distance_from_shoulder in [2, 3] else CLOTH
				cells.append({"position": Vector3i(x,y,z), "palette_index": palette_index})
	return cells


static func _boot_cells() -> Array[Dictionary]:
	var cells: Array[Dictionary] = []
	# Character forward is -Z. Keep the toe box and sole pointed toward the
	# authored face instead of extending behind the heel.
	for z in range(-4, 2):
		for y in range(-1, 2):
			for x in range(-1, 2):
				var palette_index: int = SOLE if y == -1 else (LEATHER_LIGHT if z <= -2 else LEATHER)
				cells.append({"position": Vector3i(x,y,z), "palette_index": palette_index})
	return cells


static func _expedition_pack_cells() -> Array[Dictionary]:
	var cells: Array[Dictionary] = []
	for z in range(2, 5):
		for y in range(-7, 3):
			for x in range(-3, 3):
				if (y in [-7, 2]) and x in [-3, 2]:
					continue
				var palette_index: int = CANVAS_DARK
				if y in [-5, 0] or x in [-3, 2]:
					palette_index = LEATHER
				cells.append({"position": Vector3i(x,y,z), "palette_index": palette_index})
	return cells


static func _pack_roll_cells() -> Array[Dictionary]:
	var cells: Array[Dictionary] = []
	for z in range(2, 5):
		for y in range(2, 5):
			for x in range(-3, 3):
				if y in [2, 4] and z in [2, 4]:
					continue
				var palette_index: int = LEATHER_LIGHT if x in [-3, 2] else CANVAS_LIGHT
				cells.append({"position": Vector3i(x,y,z), "palette_index": palette_index})
	return cells


static func _pack_buckle_cells() -> Array[Dictionary]:
	return [
		{"position": Vector3i(-2,-4,5), "palette_index": METAL},
		{"position": Vector3i(1,-4,5), "palette_index": METAL},
		{"position": Vector3i(-2,1,5), "palette_index": METAL},
		{"position": Vector3i(1,1,5), "palette_index": METAL},
	]


static func _jacket_lower_cells() -> Array[Dictionary]:
	var cells := _box(Vector3i(-3,-1,-2), Vector3i(-2,6,-2), CLOTH)
	cells.append_array(_box(Vector3i(1,-1,-2), Vector3i(2,6,-2), CLOTH))
	cells.append_array(_box(Vector3i(-3,-1,-1), Vector3i(-3,6,1), CLOTH))
	cells.append_array(_box(Vector3i(2,-1,-1), Vector3i(2,6,1), CLOTH))
	cells.append_array(_box(Vector3i(-2,-1,2), Vector3i(1,6,2), CLOTH))
	return cells


static func _pack_strap_cells() -> Array[Dictionary]:
	var cells := _box(Vector3i(-3,-7,-3), Vector3i(-3,3,-3), LEATHER)
	cells.append_array(_box(Vector3i(2,-7,-3), Vector3i(2,3,-3), LEATHER))
	return cells


static func _pickaxe_head_cells() -> Array[Dictionary]:
	var cells: Array[Dictionary] = []
	for x in range(-5, 6):
		var y: int = 4 - absi(x) / 3
		cells.append({"position": Vector3i(x, y, 0), "palette_index": METAL})
		cells.append({"position": Vector3i(x, y, 1), "palette_index": METAL})
	return cells
