extends RefCounted

const AttackDefinitionScript := preload("res://gameplay/combat/attacks/player_attack_definition.gd")

const PROFILE_HANDS_LIGHT := "attack_profile.player.hands_light"
const PROFILE_STONE_AXE_LIGHT := "attack_profile.player.stone_axe_light"
const PROFILE_STONE_PICKAXE_LIGHT := "attack_profile.player.stone_pickaxe_light"
const PROFILE_STANDARD_BLADE_LIGHT := "attack_profile.player.standard_blade_light"


static func has_profile(profile_id: String) -> bool:
	return known_profile_ids().has(profile_id)


static func known_profile_ids() -> Array[String]:
	return [
		PROFILE_HANDS_LIGHT,
		PROFILE_STANDARD_BLADE_LIGHT,
		PROFILE_STONE_AXE_LIGHT,
		PROFILE_STONE_PICKAXE_LIGHT,
	]


static func for_profile(profile_id: String):
	match profile_id:
		PROFILE_HANDS_LIGHT:
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
		PROFILE_STONE_AXE_LIGHT:
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
		PROFILE_STONE_PICKAXE_LIGHT:
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
		PROFILE_STANDARD_BLADE_LIGHT:
			return AttackDefinitionScript.new(
				&"standard_blade_light",
				0.13,
				0.10,
				0.21,
				15,
				2.85,
				1.70,
				1.00,
				0.08
			)
		_:
			return null


static func for_tool(tool_id: String) -> RefCounted:
	match tool_id:
		"stone_axe":
			return for_profile(PROFILE_STONE_AXE_LIGHT)
		"stone_pickaxe":
			return for_profile(PROFILE_STONE_PICKAXE_LIGHT)
		_:
			return for_profile(PROFILE_HANDS_LIGHT)
