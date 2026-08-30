extends RefCounted


static func is_finite_number(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)
