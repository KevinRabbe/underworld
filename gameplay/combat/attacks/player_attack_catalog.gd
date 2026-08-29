extends RefCounted

const AttackDefinitionScript := preload("res://gameplay/combat/attacks/player_attack_definition.gd")


static func for_tool(tool_id: String, attack_kind: StringName = &"light") -> RefCounted:
	var heavy := attack_kind == &"heavy"
	match tool_id:
		"stone_axe":
			return AttackDefinitionScript.new(
				&"stone_axe_heavy" if heavy else &"stone_axe_light",
				0.24 if heavy else 0.12,
				0.12 if heavy else 0.10,
				0.34 if heavy else 0.20,
				28 if heavy else 16,
				3.0 if heavy else 2.8,
				1.75 if heavy else 1.65,
				1.18 if heavy else 1.05,
				0.06 if heavy else 0.10,
				&"heavy" if heavy else &"light",
				12.0 if heavy else 0.0
			)
		"stone_pickaxe":
			return AttackDefinitionScript.new(
				&"stone_pickaxe_heavy" if heavy else &"stone_pickaxe_light",
				0.26 if heavy else 0.14,
				0.12 if heavy else 0.10,
				0.36 if heavy else 0.20,
				24 if heavy else 13,
				2.95 if heavy else 2.75,
				1.70 if heavy else 1.60,
				1.12 if heavy else 1.00,
				0.08 if heavy else 0.12,
				&"heavy" if heavy else &"light",
				12.0 if heavy else 0.0
			)
		_:
			return AttackDefinitionScript.new(
				&"hands_heavy" if heavy else &"hands_light",
				0.22 if heavy else 0.10,
				0.12 if heavy else 0.10,
				0.30 if heavy else 0.18,
				13 if heavy else 7,
				2.65 if heavy else 2.45,
				1.55 if heavy else 1.45,
				1.04 if heavy else 0.92,
				0.10 if heavy else 0.15,
				&"heavy" if heavy else &"light",
				12.0 if heavy else 0.0
			)
