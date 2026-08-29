extends Node3D

const VoxelPresentation := preload("res://presentation/characters/voxel/voxel_character_presentation.gd")

@onready var character_root: Node3D = $CharacterRoot
@onready var status_label: Label = $Interface/Status

var character
var locomotion_velocity := Vector3.ZERO
var grounded := true
var sprinting := false
var block_held := false


func _ready() -> void:
	character = VoxelPresentation.new()
	character.name = "FrontierExpeditionSurvivor"
	character_root.add_child(character)
	character.build()
	character.set_held_item("stone_axe")
	_set_locomotion(&"idle")


func _process(delta: float) -> void:
	if character != null:
		character.update_voxel_visual(delta, locomotion_velocity, 0.0, grounded, sprinting)
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
	locomotion_velocity = Vector3(0.0, 4.0 if ascending else -4.0, 0.0)
	character.update_voxel_visual(0.0, Vector3.ZERO, locomotion_velocity.y, false, false)
	status_label.text = _status_text("jump" if ascending else "fall")


func _play_action(action: StringName) -> void:
	character.reset_pose()
	grounded = true
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
	return "FRONTIER UNDERWORLD EXPEDITION — %s\n1–6 locomotion  7/8 jump/fall  Z/X/C dodge  F/G attacks  H block  J parry  K hit  L tool  N death  T equipment  Q/E rotate  R reset" % state.to_upper()
