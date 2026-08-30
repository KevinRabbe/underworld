extends Node3D

const VoxelPresentation := preload("res://presentation/characters/voxel/voxel_character_presentation.gd")
const BaselineFactory := preload("res://presentation/characters/voxel/baseline_survivor_factory.gd")

@onready var character_root: Node3D = $CharacterRoot
@onready var status_label: Label = $Interface/Status
@onready var preview_camera: Camera3D = $Camera3D

var character
var locomotion_velocity := Vector3.ZERO
var vertical_velocity := 0.0
var grounded := true
var sprinting := false
var block_held := false
var preview_capture_path := ""
var preview_capture_angle_degrees := 0.0
var preview_capture_delay_seconds := 0.25
var preview_pose_time_normalized := 0.35
var preview_state := "idle"
var preview_variant := "default"


func _ready() -> void:
	_parse_preview_arguments()
	preview_camera.look_at(Vector3(0.0, 0.9, 0.0), Vector3.UP)
	character = VoxelPresentation.new(BaselineFactory.build_variant(preview_variant))
	character.name = "FrontierExpeditionSurvivor"
	character_root.add_child(character)
	character.build()
	character.set_held_item("stone_axe")
	_set_locomotion(&"idle")
	_apply_preview_state(preview_state)
	if not preview_capture_path.is_empty():
		_freeze_preview_pose()
	if not is_zero_approx(preview_capture_angle_degrees):
		character_root.rotation_degrees.y = preview_capture_angle_degrees
	if not preview_capture_path.is_empty():
		_capture_preview.call_deferred()


func _process(delta: float) -> void:
	if character != null:
		if preview_capture_path.is_empty():
			character.update_voxel_visual(delta, locomotion_velocity, vertical_velocity, grounded, sprinting)
			status_label.text = _status_text(str(character.current_animation_state))
		else:
			status_label.text = _status_text(preview_state)
	if Input.is_key_pressed(KEY_Q):
		character_root.rotate_y(delta * 1.25)
	if Input.is_key_pressed(KEY_E):
		character_root.rotate_y(-delta * 1.25)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or character == null:
		return
	match event.keycode:
		KEY_1: _set_locomotion(&"idle")
		KEY_2: _set_locomotion(&"walk_forward")
		KEY_3: _set_locomotion(&"walk_backward")
		KEY_4: _set_locomotion(&"strafe_left")
		KEY_5: _set_locomotion(&"strafe_right")
		KEY_6: _set_locomotion(&"sprint")
		KEY_7: _set_airborne(true)
		KEY_8: _set_airborne(false)
		KEY_Z: _play_action(&"dodge_left")
		KEY_X: _play_action(&"dodge_forward")
		KEY_C: _play_action(&"dodge_right")
		KEY_F: _play_action(&"attack_light")
		KEY_G: _play_action(&"attack_heavy")
		KEY_H: _toggle_block()
		KEY_J: _play_action(&"parry")
		KEY_K: _play_action(&"hit")
		KEY_L: _play_action(&"tool_use")
		KEY_N: _play_action(&"death")
		KEY_R: _reset_character()
		KEY_T: _toggle_tool()


func _set_locomotion(state: StringName) -> void:
	character.reset_pose()
	grounded = true
	vertical_velocity = 0.0
	sprinting = state == &"sprint"
	match state:
		&"walk_forward": locomotion_velocity = Vector3(0.0, 0.0, 4.0)
		&"walk_backward": locomotion_velocity = Vector3(0.0, 0.0, -4.0)
		&"strafe_left": locomotion_velocity = Vector3(-4.0, 0.0, 0.0)
		&"strafe_right": locomotion_velocity = Vector3(4.0, 0.0, 0.0)
		&"sprint": locomotion_velocity = Vector3(0.0, 0.0, 8.5)
		_: locomotion_velocity = Vector3.ZERO
	block_held = false
	status_label.text = _status_text(str(state))


func _set_airborne(ascending: bool) -> void:
	character.reset_pose()
	grounded = false
	sprinting = false
	locomotion_velocity = Vector3.ZERO
	vertical_velocity = 4.0 if ascending else -4.0
	character.update_voxel_visual(0.0, Vector3.ZERO, vertical_velocity, false, false)
	status_label.text = _status_text("jump" if ascending else "fall")


func _play_action(action: StringName) -> void:
	character.reset_pose()
	grounded = true
	vertical_velocity = 0.0
	sprinting = false
	locomotion_velocity = Vector3.ZERO
	block_held = false
	match action:
		&"dodge_left": character.play_dodge(Vector2.LEFT)
		&"dodge_forward": character.play_dodge(Vector2.UP)
		&"dodge_right": character.play_dodge(Vector2.RIGHT)
		&"attack_light": character.play_attack(0.42, &"light")
		&"attack_heavy": character.play_attack(0.78, &"heavy")
		&"parry": character.play_parry()
		&"hit": character.play_hit()
		&"tool_use": character.play_tool_use(0.62)
		&"death": character.play_death()
	status_label.text = _status_text(str(action))


func _toggle_block() -> void:
	block_held = not block_held
	character.set_blocking(block_held)
	status_label.text = _status_text("block held" if block_held else "idle")


func _toggle_tool() -> void:
	var has_tool: bool = not character.get_tool_visual_root().find_children("VoxelHeld*", "MeshInstance3D", true, false).is_empty()
	character.set_held_item("hands" if has_tool else "stone_axe")
	status_label.text = _status_text("hands" if has_tool else "stone axe")


func _reset_character() -> void:
	character.reset_pose()
	character_root.rotation = Vector3.ZERO
	character.set_held_item("stone_axe")
	_set_locomotion(&"idle")


func _status_text(state: String) -> String:
	var metrics: Dictionary = character.mesh_metrics if character != null else {}
	return "FRONTIER UNDERWORLD EXPEDITION — %s   Parts %d  Cells %d  Triangles %d  Memory %.1f KiB\n1–6 locomotion  7/8 jump/fall  Z/X/C dodge  F/G attacks  H block  J parry  K hit  L tool  N death  T equipment  Q/E rotate  R reset" % [
		state.to_upper(),
		int(metrics.get("parts", 0)),
		int(metrics.get("cells", 0)),
		int(metrics.get("triangles", 0)),
		float(metrics.get("estimated_bytes", 0)) / 1024.0,
	]


func _parse_preview_arguments() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--preview-capture="):
			preview_capture_path = argument.trim_prefix("--preview-capture=")
		elif argument.begins_with("--preview-angle="):
			preview_capture_angle_degrees = float(argument.trim_prefix("--preview-angle="))
		elif argument.begins_with("--preview-state="):
			preview_state = argument.trim_prefix("--preview-state=")
		elif argument.begins_with("--preview-delay="):
			preview_capture_delay_seconds = maxf(float(argument.trim_prefix("--preview-delay=")), 0.0)
		elif argument.begins_with("--preview-pose-time="):
			preview_pose_time_normalized = clampf(float(argument.trim_prefix("--preview-pose-time=")), 0.0, 1.0)
		elif argument.begins_with("--preview-variant="):
			preview_variant = argument.trim_prefix("--preview-variant=")


func _apply_preview_state(state: String) -> void:
	match state:
		"idle", "walk_forward", "walk_backward", "strafe_left", "strafe_right", "sprint":
			_set_locomotion(StringName(state))
		"jump": _set_airborne(true)
		"fall": _set_airborne(false)
		"block": _toggle_block()
		"dodge_left", "dodge_forward", "dodge_right", "attack_light", "attack_heavy", "parry", "hit", "tool_use", "death":
			_play_action(StringName(state))
		_:
			push_warning("Unknown preview state '%s'; using idle" % state)
			_set_locomotion(&"idle")


func _freeze_preview_pose() -> void:
	var clip_name := preview_state
	if clip_name == "idle":
		clip_name = "idle"
	if character.animation_tree != null:
		character.animation_tree.active = false
	if character.animation_player == null or not character.animation_player.has_animation(clip_name):
		return
	character.animation_player.speed_scale = 1.0
	character.animation_player.play(clip_name)
	character.animation_player.seek(preview_pose_time_normalized, true)
	character.animation_player.pause()


func _capture_preview() -> void:
	# Wait for pose evaluation and a completed render before reading the viewport.
	for _frame in range(12):
		await get_tree().process_frame
	await get_tree().create_timer(preview_capture_delay_seconds).timeout
	await RenderingServer.frame_post_draw
	var screenshot: Image = get_viewport().get_texture().get_image()
	var error: Error = screenshot.save_png(preview_capture_path)
	if error == OK:
		print("[CHARACTER PREVIEW] captured %s" % preview_capture_path)
	else:
		push_error("Character preview capture failed (%d): %s" % [error, preview_capture_path])
	get_tree().quit(0 if error == OK else 1)
