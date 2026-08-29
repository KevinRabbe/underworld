extends RefCounted

const ContentId := preload("res://core/content/identity/content_id.gd")

const ALLOWED_FAMILIES := ["resource_node", "resource_deposit"]

var resource_content_id: String = ""
var remaining_capacity_units: float = 0.0
var mutable_state: Dictionary = {}


func configure(
	p_resource_content_id: String,
	p_remaining_capacity_units: float,
	p_mutable_state: Dictionary = {}
) -> RefCounted:
	resource_content_id = p_resource_content_id
	remaining_capacity_units = p_remaining_capacity_units
	mutable_state = p_mutable_state.duplicate(true)
	return self


func validate_state() -> Array[String]:
	var failures: Array[String] = []
	for failure in ContentId.validate(resource_content_id):
		failures.append("resource content id: %s" % failure)
	if ContentId.is_valid(resource_content_id):
		var family: String = ContentId.family_of(resource_content_id)
		if not ALLOWED_FAMILIES.has(family):
			failures.append("depletion state must reference resource_node.* or resource_deposit.*: %s" % resource_content_id)
	if remaining_capacity_units < 0.0:
		failures.append("remaining resource capacity must be >= 0")
	failures.sort()
	return failures


func apply_depletion(capacity_units: float) -> float:
	var requested: float = maxf(capacity_units, 0.0)
	var consumed: float = minf(requested, remaining_capacity_units)
	remaining_capacity_units -= consumed
	return consumed


func is_depleted() -> bool:
	return is_zero_approx(remaining_capacity_units)


func set_value(key: String, value: Variant) -> void:
	mutable_state[key] = value


func get_value(key: String, default_value: Variant = null) -> Variant:
	return mutable_state.get(key, default_value)


func canonical_descriptor() -> Dictionary:
	return {
		"resource_content_id": resource_content_id,
		"remaining_capacity_units": remaining_capacity_units,
		"mutable_state": mutable_state.duplicate(true),
	}
