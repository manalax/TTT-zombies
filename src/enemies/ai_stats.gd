class_name AIStats
extends RefCounted
## Per-physics-tick cost of all enemy AI steps, for the F3 overlay and the swarm perf test.
## Every EnemyBase.step() reports its own duration; totals roll over per physics frame.

## Exponential moving average of the per-tick total, in ms (overlay).
static var smoothed_ms: float = 0.0
## Total of the last completed tick, in ms.
static var last_tick_ms: float = 0.0
static var peak_ms: float = 0.0

static var _frame: int = -1
static var _accum_usec: int = 0
static var _sum_ms: float = 0.0
static var _ticks: int = 0


static func record(usec: int) -> void:
	var frame := Engine.get_physics_frames()
	if frame != _frame:
		_roll()
		_frame = frame
	_accum_usec += usec


## Mean per-tick total since the last [method reset], in ms (completed ticks only).
static func mean_ms() -> float:
	return _sum_ms / _ticks if _ticks > 0 else 0.0


static func tick_count() -> int:
	return _ticks


static func reset() -> void:
	smoothed_ms = 0.0
	last_tick_ms = 0.0
	peak_ms = 0.0
	_frame = -1
	_accum_usec = 0
	_sum_ms = 0.0
	_ticks = 0


static func _roll() -> void:
	if _frame < 0:
		return
	last_tick_ms = _accum_usec / 1000.0
	_accum_usec = 0
	_sum_ms += last_tick_ms
	_ticks += 1
	peak_ms = maxf(peak_ms, last_tick_ms)
	smoothed_ms = lerpf(smoothed_ms, last_tick_ms, 0.1)
