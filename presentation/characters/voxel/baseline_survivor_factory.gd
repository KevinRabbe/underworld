extends RefCounted
class_name UnderworldBaselineVoxelSurvivorFactory

const PaletteScript := preload("res://presentation/characters/voxel/voxel_character_palette_definition.gd")
const ModuleScript := preload("res://presentation/characters/voxel/voxel_character_module_definition.gd")
const CharacterScript := preload("res://presentation/characters/voxel/voxel_character_definition.gd")
const SliceProfileScript := preload("res://presentation/characters/voxel/voxel_character_slice_profile.gd")

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
		_module("body", &"body_base", _slice_body_parts()),
		_module("head", &"head_hair", _slice_head_parts()),
		_module("jacket", &"torso_outfit", [
			_slice_overlay_part("jacket_front", "rig_role.chest", 34, 46, 42, CLOTH, -1),
			_slice_overlay_part("jacket_trim", "rig_role.chest", 39, 44, 42, CANVAS_LIGHT, -2),
			_slice_overlay_part("jacket_lower", "rig_role.spine.lower", 28, 38, 33, CANVAS_LIGHT, -1),
			_raw_part("shoulder_l", "rig_role.clavicle.left", _arm_cells(true, 3, CLOTH), Vector3i.ZERO),
			_raw_part("shoulder_r", "rig_role.clavicle.right", _arm_cells(false, 3, CLOTH), Vector3i.ZERO),
			_part("neck_connector", "rig_role.neck", _box(Vector3i(-1,-2,-1), Vector3i(0,0,1), CLOTH), Vector3i.ZERO),
			_raw_part("upperarm_l", "rig_role.upper_arm.left", _arm_cells(true, 6, CLOTH), Vector3i.ZERO),
			_raw_part("forearm_l", "rig_role.forearm.left", _arm_cells(true, 6, LEATHER), Vector3i.ZERO),
			_raw_part("upperarm_r", "rig_role.upper_arm.right", _arm_cells(false, 6, CLOTH), Vector3i.ZERO),
			_raw_part("forearm_r", "rig_role.forearm.right", _arm_cells(false, 6, LEATHER), Vector3i.ZERO),
			_part("scarf", "rig_role.neck", _box(Vector3i(-2,-1,-2), Vector3i(1,1,1), ACCENT), Vector3i(0,0,0)),
			_part("belt", "rig_role.pelvis", _box(Vector3i(-3,1,-2), Vector3i(2,2,1), LEATHER), Vector3i(0,0,0)),
			_part("belt_buckle", "rig_role.pelvis", _box(Vector3i(0,1,-3), Vector3i(1,2,-3), METAL), Vector3i.ZERO),
			_part("pack_straps", "rig_role.chest", _pack_strap_cells(), Vector3i.ZERO),
		]),
		_module("trousers", &"leg_outfit", [
			_slice_limb_part("thigh_l", "rig_role.thigh.left", 14, 25, 24, true, TROUSER),
			_slice_limb_part("calf_l", "rig_role.calf.left", 5, 15, 14, true, TROUSER),
			_slice_limb_part("thigh_r", "rig_role.thigh.right", 14, 25, 24, false, TROUSER),
			_slice_limb_part("calf_r", "rig_role.calf.right", 5, 15, 14, false, TROUSER),
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
			_raw_part("foot_l", "rig_role.foot.left", _foot_slice_cells(), Vector3i.ZERO),
			_raw_part("foot_r", "rig_role.foot.right", _foot_slice_cells(), Vector3i.ZERO),
		]),
		_module("pouch", &"back_accessory", [
			_slice_overlay_part("hip_pouch", "rig_role.pelvis", 24, 31, 28, LEATHER, 3),
			_slice_overlay_part("expedition_pack", "rig_role.chest", 34, 45, 42, CANVAS_DARK, 4),
			_slice_overlay_part("pack_roll", "rig_role.chest", 42, 47, 44, LEATHER_LIGHT, 5),
			_slice_overlay_part("pack_buckles", "rig_role.chest", 36, 43, 40, METAL, 5),
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
	character.slice_profile = _baseline_slice_profile()
	return character


static func build_variant(variant_id: String) -> Resource:
	var character = build()
	if variant_id == "work":
		character.palette.entries[CLOTH]["color"] = Color("6b6252")
		character.palette.entries[CANVAS_LIGHT]["color"] = Color("aa956f")
	elif variant_id == "light_armor":
		character.palette.entries[CLOTH]["color"] = Color("4f5960")
		character.palette.entries[METAL]["color"] = Color("a7b1b3")
		character.palette.entries[METAL]["roughness"] = 0.30
	return character


static func _baseline_slice_profile() -> Resource:
	var rows: Array[Dictionary] = []
	for y in range(56):
		var width := _slice_width(y)
		var depth := _slice_depth(y)
		var lines: Array[String] = []
		for z in range(depth):
			lines.append("#".repeat(width))
		rows.append({"y": y, "layers": [{"layer_id": "body", "priority": 0, "palette_index": _slice_palette(y), "semantic": _slice_semantic(y), "mask": lines}]})
	return SliceProfileScript.new().configure("character.voxel.grounded_survivor.slices", rows, PRESENTATION_VOXEL_SIZE)


static func _slice_body_parts() -> Array[Dictionary]:
	var profile = _baseline_slice_profile()
	var all_cells: Array[Dictionary] = profile.resolved_cells()
	var parts: Array[Dictionary] = []
	# Bands are expressed in one global 56-row profile, then converted to the
	# local coordinates of the existing pelvis/spine/chest bones. This keeps the
	# authored rows contiguous while preserving the semantic animation rig.
	parts.append(_slice_part("pelvis", "rig_role.pelvis", all_cells, 22, 31, 28))
	parts.append(_slice_part("spine", "rig_role.spine.lower", all_cells, 29, 39, 33))
	parts.append(_slice_part("chest", "rig_role.chest", all_cells, 37, 47, 42))
	return parts


static func _slice_head_parts() -> Array[Dictionary]:
	var profile = _baseline_slice_profile()
	var all_cells: Array[Dictionary] = profile.resolved_cells()
	var parts: Array[Dictionary] = []
	parts.append(_slice_part("head_skin", "rig_role.head", all_cells, 43, 55, 49))
	# Front-facing features are a thin explicit overlay one grid unit beyond the
	# skin surface. Hair is kept on the crown and rear, so it cannot z-fight with
	# the face when rows are replaced.
	var face_cells: Array[Dictionary] = []
	for cell in [Vector3i(-2, 3, -5), Vector3i(2, 3, -5), Vector3i(0, 0, -5)]:
		face_cells.append({"position": cell, "palette_index": FACE})
	var hair_cells: Array[Dictionary] = []
	for z in range(-4, 4):
		for y in range(5, 8):
			for x in range(-4, 5):
				if y == 7 and abs(x) > 2:
					continue
				hair_cells.append({"position": Vector3i(x, y, z), "palette_index": HAIR})
	for z in range(2, 5):
		for y in range(0, 5):
			for x in range(-4, 5):
				hair_cells.append({"position": Vector3i(x, y, z), "palette_index": HAIR})
	parts.append(_raw_part("face", "rig_role.head", face_cells, Vector3i.ZERO))
	parts.append(_raw_part("hair", "rig_role.head", hair_cells, Vector3i.ZERO))
	return parts


static func _slice_part(id_value: String, rig_role: String, all_cells: Array[Dictionary], minimum_y: int, maximum_y: int, anchor_y: int) -> Dictionary:
	var cells: Array[Dictionary] = []
	for cell_value in all_cells:
		var source: Dictionary = cell_value
		var position: Vector3i = source["position"]
		if position.y < minimum_y or position.y > maximum_y:
			continue
		var row_width := _slice_width(position.y)
		var row_depth := _slice_depth(position.y)
		var local_position := Vector3i(position.x - floori(float(row_width) * 0.5), position.y - anchor_y, position.z - floori(float(row_depth) * 0.5))
		cells.append({"position": local_position, "palette_index": int(source.get("palette_index", CANVAS_LIGHT))})
	return _raw_part(id_value, rig_role, cells, Vector3i.ZERO)


static func _slice_overlay_part(id_value: String, rig_role: String, minimum_y: int, maximum_y: int, anchor_y: int, palette_index: int, depth_offset: int) -> Dictionary:
	var profile = _baseline_slice_profile()
	var cells: Array[Dictionary] = []
	for cell_value in profile.resolved_cells():
		var source: Dictionary = cell_value
		var position: Vector3i = source["position"]
		if position.y < minimum_y or position.y > maximum_y:
			continue
		var row_width := _slice_width(position.y)
		var row_depth := _slice_depth(position.y)
		var local_position := Vector3i(position.x - floori(float(row_width) * 0.5), position.y - anchor_y, position.z - floori(float(row_depth) * 0.5) + depth_offset)
		cells.append({"position": local_position, "palette_index": palette_index})
	return _raw_part(id_value, rig_role, cells, Vector3i.ZERO)


static func _slice_limb_part(id_value: String, rig_role: String, minimum_y: int, maximum_y: int, anchor_y: int, left: bool, palette_index: int) -> Dictionary:
	var profile = _baseline_slice_profile()
	var cells: Array[Dictionary] = []
	for cell_value in profile.resolved_cells():
		var source: Dictionary = cell_value
		var position: Vector3i = source["position"]
		if position.y < minimum_y or position.y > maximum_y:
			continue
		var row_width := _slice_width(position.y)
		var row_depth := _slice_depth(position.y)
		var centered_x := position.x - floori(float(row_width) * 0.5)
		if left and centered_x >= 0: continue
		if not left and centered_x < 0: continue
		var local_x := centered_x + (2 if left else -2)
		var local_position := Vector3i(local_x, position.y - anchor_y, position.z - floori(float(row_depth) * 0.5))
		cells.append({"position": local_position, "palette_index": palette_index})
	return _raw_part(id_value, rig_role, cells, Vector3i.ZERO)


static func _foot_slice_cells() -> Array[Dictionary]:
	var cells: Array[Dictionary] = []
	for z in range(-4, 2):
		for y in range(-1, 2):
			for x in range(-2, 3):
				var palette_index := SOLE if y == -1 else (LEATHER_LIGHT if z <= -2 else LEATHER)
				cells.append({"position": Vector3i(x, y, z), "palette_index": palette_index})
	return cells


static func _arm_cells(left: bool, length: int, palette_index: int) -> Array[Dictionary]:
	var cells: Array[Dictionary] = []
	for i in range(length):
		var x := -i - 1 if left else i
		var radius := 2 if i < 2 else 1
		for y in range(-radius, radius + 1):
			for z in range(-1, 2):
				cells.append({"position": Vector3i(x, y, z), "palette_index": palette_index})
	return cells


static func _raw_part(id_value: String, rig_role: String, cells: Array[Dictionary], pivot: Vector3i) -> Dictionary:
	return {"part_id": id_value, "rig_role": rig_role, "pivot": pivot, "attachment_offset": Vector3.ZERO, "cells": cells}


static func _slice_width(y: int) -> int:
	if y < 8: return 8 # boots
	if y < 24: return 6 # calves/thighs
	if y < 34: return 12 # hips/torso
	if y < 43: return 14 # shoulders/chest
	return 10 # neck/head


static func _slice_depth(y: int) -> int:
	if y < 8: return 8
	if y < 24: return 6
	if y < 43: return 6
	return 8


static func _slice_palette(y: int) -> int:
	if y < 24: return TROUSER
	if y < 43: return CANVAS_LIGHT
	return SKIN


static func _slice_semantic(y: int) -> String:
	if y < 8: return "feet"
	if y < 24: return "legs"
	if y < 43: return "torso"
	return "head"


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
