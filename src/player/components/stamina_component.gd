class_name StaminaComponent
extends Node
## Player stamina (DESIGN §6.1). Pure logic: the owner calls [method tick] once per physics step.
##
## Spending (sprint drain, later melee costs) pauses regen for [member regen_delay_s]. Hitting 0
## makes the component exhausted: sprinting is locked until stamina reaches [member recover_at].

signal stamina_changed(current: float, maximum: float)
signal exhausted_changed(exhausted: bool)

@export var max_stamina: float = 100.0
@export var regen_per_s: float = 20.0
@export var regen_delay_s: float = 1.0
@export var recover_at: float = 30.0

var current: float = 100.0
var _since_spend: float = INF
var _exhausted: bool = false


## Copies limits from [param defaults] and refills.
func configure(defaults: PlayerDefaults) -> void:
	max_stamina = defaults.max_stamina
	regen_per_s = defaults.stamina_regen_per_s
	regen_delay_s = defaults.stamina_regen_delay_s
	recover_at = defaults.exhausted_recover_at
	refill()


func refill() -> void:
	_since_spend = INF
	_set_exhausted(false)
	_set_current(max_stamina)


func tick(delta: float) -> void:
	_since_spend += delta
	if _since_spend >= regen_delay_s and current < max_stamina:
		_set_current(minf(max_stamina, current + regen_per_s * delta))
	if _exhausted and current >= recover_at:
		_set_exhausted(false)


## Removes up to [param amount] (continuous costs like sprinting). Reaching 0 exhausts.
func drain(amount: float) -> void:
	if amount <= 0.0:
		return
	_since_spend = 0.0
	_set_current(maxf(0.0, current - amount))
	if current <= 0.0:
		_set_exhausted(true)


## Spends [param amount] only if it is fully available (discrete costs like attacks).
func try_spend(amount: float) -> bool:
	if current < amount:
		return false
	drain(amount)
	return true


func is_exhausted() -> bool:
	return _exhausted


func can_sprint() -> bool:
	return not _exhausted and current > 0.0


func get_ratio() -> float:
	return current / max_stamina if max_stamina > 0.0 else 0.0


func _set_current(value: float) -> void:
	if is_equal_approx(value, current):
		current = value
		return
	current = value
	stamina_changed.emit(current, max_stamina)


func _set_exhausted(value: bool) -> void:
	if value == _exhausted:
		return
	_exhausted = value
	exhausted_changed.emit(value)
