extends RefCounted
class_name UnderworldSeedDomain

var domain_id: int
var readable_name: String
var revision: int


func _init(id_value: int, name_value: String, revision_value: int) -> void:
	domain_id = id_value
	readable_name = name_value
	revision = revision_value


func canonical_key() -> String:
	return "%08x@%d:%s" % [domain_id, revision, readable_name]
