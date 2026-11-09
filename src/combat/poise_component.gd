class_name PoiseComponent
extends Node
## Stagger build-up (docs/adr/0005-melee.md). Hits add their stagger; it decays over time.
## Crossing [member stagger_resist] staggers the owner for [member stagger_duration_s].
## The owner calls [method tick] each physics step. AI reacts to [signal staggered] (F015).

signal staggered(duration_s: float)
signal recovered

## Poise threshold (EnemyData.stagger_resist for enemies).
@export_range(0, 1000, 1) var stagger_resist: float = 30.0
@export_range(0, 500, 0.5, "suffix:/s") var decay_per_s: float = 15.0
@export_range(0.0, 10.0, 0.05, "suffix:s") var stagger_duration_s: float = 0.8

var accumulated: float = 0.0
var _stagger_left: float = 0.0


func add(amount: float) -> void:
	if amount <= 0.0 or is_staggered():
		return
	accumulated += amount
	if accumulated >= stagger_resist:
		accumulated = 0.0
		_stagger_left = stagger_duration_s
		staggered.emit(stagger_duration_s)


func tick(delta: float) -> void:
	accumulated = maxf(0.0, accumulated - decay_per_s * delta)
	if _stagger_left > 0.0:
		_stagger_left -= delta
		if _stagger_left <= 0.0:
			_stagger_left = 0.0
			recovered.emit()


func is_staggered() -> bool:
	return _stagger_left > 0.0


func reset() -> void:
	accumulated = 0.0
	_stagger_left = 0.0
