extends Control

signal new_game_requested
signal continue_requested
signal quit_requested

@onready var new_game_button: Button = %NewGameButton
@onready var continue_button: Button = %ContinueButton
@onready var quit_button: Button = %QuitButton


func _ready() -> void:
	new_game_button.pressed.connect(_on_new_game_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	set_continue_available(false)
	new_game_button.call_deferred("grab_focus")


func set_continue_available(is_available: bool) -> void:
	continue_button.disabled = not is_available
	continue_button.focus_mode = Control.FOCUS_ALL if is_available else Control.FOCUS_NONE


func _on_new_game_pressed() -> void:
	new_game_requested.emit()


func _on_continue_pressed() -> void:
	if continue_button.disabled:
		return
	continue_requested.emit()


func _on_quit_pressed() -> void:
	quit_requested.emit()
