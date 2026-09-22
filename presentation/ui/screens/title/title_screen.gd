extends Control

const UNDERWORLD_THEME_PATH := "res://presentation/ui/theme/underworld_theme.tres"

signal new_game_requested
signal continue_requested
signal quit_requested

@onready var new_game_button: Button = %NewGameButton
@onready var continue_button: Button = %ContinueButton
@onready var quit_button: Button = %QuitButton


func _ready() -> void:
	# Keep the authored theme when available, but do not make title startup
	# depend on a hard scene preload of an optional presentation resource.
	theme = _load_underworld_theme()
	new_game_button.pressed.connect(_on_new_game_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	set_continue_available(false)
	new_game_button.call_deferred("grab_focus")


func _load_underworld_theme() -> Theme:
	if not ResourceLoader.exists(UNDERWORLD_THEME_PATH):
		return Theme.new()
	var authored := ResourceLoader.load(UNDERWORLD_THEME_PATH) as Theme
	return authored if authored != null else Theme.new()


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
