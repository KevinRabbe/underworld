extends Control

const ProfileCatalog := preload("res://gameplay/persistence/profile_catalog.gd")

signal start_requested(profile)
signal back_requested

@onready var character_name: LineEdit = %CharacterName
@onready var world_name: LineEdit = %WorldName
@onready var world_seed: LineEdit = %WorldSeed
@onready var character_select: OptionButton = %CharacterSelect
@onready var world_select: OptionButton = %WorldSelect
@onready var status: Label = %Status
@onready var start_button: Button = %StartButton
@onready var select_button: Button = %SelectButton
@onready var back_button: Button = %BackButton

func _ready() -> void:
	start_button.pressed.connect(_on_start)
	select_button.pressed.connect(_on_select_existing)
	back_button.pressed.connect(func(): back_requested.emit())
	var catalog_result := ProfileCatalog.load_catalog()
	if bool(catalog_result.get("success", false)):
		var catalog: Dictionary = catalog_result["catalog"]
		for character in catalog["characters"]:
			character_select.add_item(str(character.get("display_name", "")))
			character_select.set_item_metadata(character_select.item_count - 1, character.duplicate(true))
		for world in catalog["worlds"]:
			world_select.add_item("%s (seed %s)" % [str(world.get("world_name", "")), str(world.get("world_seed", 1))])
			world_select.set_item_metadata(world_select.item_count - 1, world.duplicate(true))
		if catalog["characters"].size() > 0:
			character_name.text = str(catalog["characters"][0].get("display_name", ""))
		if catalog["worlds"].size() > 0:
			world_name.text = str(catalog["worlds"][0].get("world_name", ""))
			world_seed.text = str(catalog["worlds"][0].get("world_seed", 1))
	else:
		status.text = str(catalog_result.get("diagnostics", ["Profile catalog is unavailable"])[0])
	world_seed.text = "1" if world_seed.text.is_empty() else world_seed.text
	character_name.call_deferred("grab_focus")
	select_button.disabled = character_select.item_count == 0 or world_select.item_count == 0

func _on_select_existing() -> void:
	if character_select.selected < 0 or world_select.selected < 0:
		status.text = "Select an existing character and world."
		return
	var character_variant: Variant = character_select.get_item_metadata(character_select.selected)
	var world_variant: Variant = world_select.get_item_metadata(world_select.selected)
	if not character_variant is Dictionary or not world_variant is Dictionary:
		status.text = "Selected profile metadata is invalid."
		return
	var selected := ProfileCatalog.select_pair(str(character_variant.get("character_id", "")), str(world_variant.get("world_id", "")))
	if not bool(selected.get("success", false)):
		status.text = str(selected.get("diagnostics", ["Selection failed"])[0])
		return
	status.text = "Starting %s in %s..." % [character_variant.get("display_name", ""), world_variant.get("world_name", "")]
	start_requested.emit({"character": character_variant, "world": world_variant})

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
