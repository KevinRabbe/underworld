extends RefCounted
class_name UnderworldStaminaComponent

var max_stamina: float = 100.0
var current_stamina: float = 100.0
var regen_delay: float = 0.75
var regen_rate: float = 20.0
var regen_lock_timer: float = 0.0


func _init(
	max_value: float = 100.0,
	regen_delay_value: float = 0.75,
	regen_rate_value: float = 20.0
) -> void:
	max_stamina = maxf(max_value, 1.0)
	current_stamina = max_stamina
	regen_delay = maxf(regen_delay_value, 0.0)
	regen_rate = maxf(regen_rate_value, 0.0)


func can_spend(amount: float) -> bool:
	return amount >= 0.0 and current_stamina + 0.0001 >= amount


func spend(amount: float) -> bool:
	if amount <= 0.0:
		return true
	if not can_spend(amount):
		return false
	current_stamina = maxf(current_stamina - amount, 0.0)
	regen_lock_timer = regen_delay
	return true


func tick(delta: float) -> void:
	if delta <= 0.0:
		return
	if regen_lock_timer > 0.0:
		regen_lock_timer = maxf(regen_lock_timer - delta, 0.0)
		return
	current_stamina = minf(current_stamina + regen_rate * delta, max_stamina)


func reset() -> void:
	current_stamina = max_stamina
	regen_lock_timer = 0.0


func get_ratio() -> float:
	return current_stamina / maxf(max_stamina, 0.001)
