extends Control

signal resume_requested
signal save_and_quit_requested
signal quit_requested

@onready var resume_button: Button = %ResumeButton
@onready var save_and_quit_button: Button = %SaveAndQuitButton
@onready var quit_button: Button = %QuitButton
@onready var feedback_label: Label = %FeedbackLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	resume_button.pressed.connect(_on_resume_pressed)
	save_and_quit_button.pressed.connect(_on_save_and_quit_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	set_feedback([])
	set_open(false)


func set_open(is_open: bool) -> void:
	visible = is_open
	if is_open:
		resume_button.call_deferred("grab_focus")


func is_open() -> bool:
	return visible


func set_feedback(messages: Array) -> void:
	var lines: Array[String] = []
	for message in messages:
		var text := str(message).strip_edges()
		if not text.is_empty():
			lines.append(text)
	feedback_label.text = "\n".join(PackedStringArray(lines))
	feedback_label.visible = not lines.is_empty()


func feedback_text() -> String:
	return feedback_label.text


func _on_resume_pressed() -> void:
	resume_requested.emit()


func _on_save_and_quit_pressed() -> void:
	save_and_quit_requested.emit()


func _on_quit_pressed() -> void:
	quit_requested.emit()
