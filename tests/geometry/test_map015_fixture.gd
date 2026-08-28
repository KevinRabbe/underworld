extends RefCounted
const Fixture := preload("res://worldgen/validation/map015_fixture.gd")
static func run() -> Array[String]:
	return Fixture.validate()
