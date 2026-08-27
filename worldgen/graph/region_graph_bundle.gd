extends RefCounted
class_name UnderworldRegionGraphBundle

var region_definition
var networks: Array = []
var nodes: Array = []
var edges: Array = []
var entrances: Array = []
var special_location_hooks: Array = []


func _init(
	region_definition_value,
	networks_value: Array = [],
	nodes_value: Array = [],
	edges_value: Array = [],
	entrances_value: Array = [],
	special_location_hooks_value: Array = []
) -> void:
	region_definition = region_definition_value
	networks = networks_value.duplicate()
	nodes = nodes_value.duplicate()
	edges = edges_value.duplicate()
	entrances = entrances_value.duplicate()
	special_location_hooks = special_location_hooks_value.duplicate()
