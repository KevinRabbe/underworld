extends HBoxContainer

@export var title: String = "SECTION"
@onready var title_label: Label = %Title


func _ready() -> void:
	title_label.text = title


func set_title(value: String) -> void:
	title = value
	if is_node_ready():
		title_label.text = value
