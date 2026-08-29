extends RefCounted

const ContentId := preload("res://core/content/identity/content_id.gd")

const RESOURCE_FAMILY := "resource"

var resource_content_id: String = ""
var remaining_capacity_units: float = 0.0
var mutable_delta: Dictionary = {}


func configure(
	p_resource_content_id: String,
	p_remaining_capacity_units: float,
	p_mutable_delta: Dictionary = {}
) -> RefCounted:
	resource_content_id = p_resource_content_id
	remaining_capacity_units = p_remaining_capacity_units
	mutable_delta = p_mutable_delta.duplicate(true)
	return self


func validate_state() -> Array[String]:
	var failures: Array[String] = []
	for failure in ContentId.validate(resource_content_id):
		failures.append("resource content id: %s" % failure)
	if (
		ContentId.is_valid(resource_content_id)
		and ContentId.family_of(resource_content_id) != RESOURCE_FAMILY
	):
		failures.append(
			"depletion state must reference a resource.* definition: %s" % resource_content_id
		)
	if remaining_capacity_units < 0.0:
		failures.append("remaining resource capacity units must be >= 0")
	failures.sort()
	return failures


func consume_capacity(requested_units: float) -> float:
	if requested_units <= 0.0 or remaining_capacity_units <= 0.0:
		return 0.0
	var consumed: float = minf(requested_units, remaining_capacity_units)
	remaining_capacity_units -= consumed
	return consumed


func set_delta_value(key: String, value: Variant) -> void:
	mutable_delta[key] = value


func get_delta_value(key: String, default_value: Variant = null) -> Variant:
	return mutable_delta.get(key, default_value)


func canonical_descriptor() -> Dictionary:
	return {
		"resource_content_id": resource_content_id,
		"remaining_capacity_units": remaining_capacity_units,
		"mutable_delta": mutable_delta.duplicate(true),
	}
