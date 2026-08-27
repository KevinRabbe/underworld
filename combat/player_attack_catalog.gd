extends RefCounted

const AttackDefinitionScript := preload("res://combat/player_attack_definition.gd")


static func for_tool(tool_id: String) -> RefCounted:
	match tool_id:
		"stone_axe":
			return AttackDefinitionScript.new(
				&"stone_axe_light",
				0.12,
				0.10,
				0.20,
				16,
				2.8,
				1.65,
				1.05,
				0.10
			)
		"stone_pickaxe":
			return AttackDefinitionScript.new(
				&"stone_pickaxe_light",
				0.14,
				0.10,
				0.20,
				13,
				2.75,
				1.60,
				1.00,
				0.12
			)
		_:
			return AttackDefinitionScript.new(
				&"hands_light",
				0.10,
				0.10,
				0.18,
				7,
				2.45,
				1.45,
				0.92,
				0.15
			)
