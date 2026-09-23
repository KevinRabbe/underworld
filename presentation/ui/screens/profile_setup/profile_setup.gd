extends Control

const ProfileCatalog := preload("res://gameplay/persistence/profile_catalog.gd")

signal start_requested(profile)
signal back_requested

@onready var character_name: LineEdit = %CharacterName
@onready var world_name: LineEdit = %WorldName
@onready var world_seed: LineEdit = %WorldSeed
@onready var status: Label = %Status
@onready var start_button: Button = %StartButton
@onready var back_button: Button = %BackButton

func _ready() -> void:
	start_button.pressed.connect(_on_start)
	back_button.pressed.connect(func(): back_requested.emit())
	var catalog := ProfileCatalog.load_catalog()
	if catalog["characters"].size() > 0:
		character_name.text = str(catalog["characters"][0].get("display_name", ""))
	if catalog["worlds"].size() > 0:
		world_name.text = str(catalog["worlds"][0].get("world_name", ""))
		world_seed.text = str(catalog["worlds"][0].get("world_seed", 1))
	else:
		world_seed.text = "1"
	character_name.call_deferred("grab_focus")

func _on_start() -> void:
	var name := character_name.text.strip_edges()
	var selected_world_name := world_name.text.strip_edges()
	var seed_text := world_seed.text.strip_edges()
	var seed := int(seed_text) if seed_text.is_valid_int() else 0
	if name.is_empty() or selected_world_name.is_empty() or not seed_text.is_valid_int():
		status.text = "Enter a character name, world name, and integer seed."
		return
	var character_result := ProfileCatalog.create_character(name)
	if not bool(character_result.get("success", false)):
		status.text = str(character_result.get("diagnostics", ["Character creation failed"])[0])
		return
	var world_result := ProfileCatalog.create_world(selected_world_name, seed)
	if not bool(world_result.get("success", false)):
		status.text = str(world_result.get("diagnostics", ["World creation failed"])[0])
		return
	var character: Dictionary = character_result["character"]
	var world: Dictionary = world_result["world"]
	var selected := ProfileCatalog.select_pair(str(character["character_id"]), str(world["world_id"]))
	if not bool(selected.get("success", false)):
		status.text = str(selected.get("diagnostics", ["Selection failed"])[0])
		return
	status.text = "Starting %s in %s..." % [character["display_name"], world["world_name"]]
	start_requested.emit({"character": character, "world": world})
