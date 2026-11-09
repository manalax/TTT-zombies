class_name SwingSpec
extends RefCounted
## One melee attack's numbers and shape, derived from MeleeStats (docs/adr/0005-melee.md).

enum Kind { LIGHT, HEAVY }
## Light swings alternate horizontal directions; heavies come down from overhead.
enum Sweep { LEFT_TO_RIGHT, RIGHT_TO_LEFT, OVERHEAD }

## Overhead sweeps end this far below the horizon, so they never strike the floor.
const OVERHEAD_END_PITCH_DEG := -35.0

var kind: Kind = Kind.LIGHT
var sweep: Sweep = Sweep.LEFT_TO_RIGHT
var damage: float = 0.0
var stagger: float = 0.0
var stamina_cost: float = 0.0
var weakpoint_mult: float = 1.0
var windup_s: float = 0.0
var active_s: float = 0.1
var recovery_s: float = 0.0
var arc_deg: float = 90.0
var reach_m: float = 1.8
var weapon_id: StringName = &""
var riposte_mult: float = 1.0
## Cannot be parried or blocked (must be dodged).
var unparryable: bool = false


static func light(stats: MeleeStats, sweep_dir: Sweep, weapon_id: StringName = &"") -> SwingSpec:
	var spec := SwingSpec.new()
	spec.kind = Kind.LIGHT
	spec.sweep = sweep_dir
	spec.damage = stats.light_damage
	spec.stagger = stats.stagger_light
	spec.stamina_cost = stats.light_stamina_cost
	spec.windup_s = stats.light_windup_s
	spec.active_s = stats.light_active_s
	spec.recovery_s = stats.light_recovery_s
	spec.arc_deg = stats.light_arc_deg
	spec._common(stats, weapon_id)
	return spec


static func heavy(stats: MeleeStats, weapon_id: StringName = &"") -> SwingSpec:
	var spec := SwingSpec.new()
	spec.kind = Kind.HEAVY
	spec.sweep = Sweep.OVERHEAD
	spec.damage = stats.heavy_damage
	spec.stagger = stats.stagger_heavy
	spec.stamina_cost = stats.heavy_stamina_cost
	spec.windup_s = stats.heavy_windup_s
	spec.active_s = stats.heavy_active_s
	spec.recovery_s = stats.heavy_recovery_s
	spec.arc_deg = stats.heavy_arc_deg
	spec._common(stats, weapon_id)
	return spec


## The attack a release performs after holding for [param held_s].
static func for_release(
	stats: MeleeStats, held_s: float, light_sweep: Sweep, weapon_id: StringName = &""
) -> SwingSpec:
	if held_s >= stats.heavy_charge_s:
		return heavy(stats, weapon_id)
	return light(stats, light_sweep, weapon_id)


static func next_side(previous: Sweep) -> Sweep:
	return Sweep.RIGHT_TO_LEFT if previous == Sweep.LEFT_TO_RIGHT else Sweep.LEFT_TO_RIGHT


## Local direction (relative to the attacker's eye, -Z forward) at sweep progress [param t].
func direction_at(t: float) -> Vector3:
	t = clampf(t, 0.0, 1.0)
	var half := deg_to_rad(arc_deg) * 0.5
	match sweep:
		Sweep.LEFT_TO_RIGHT:
			return Vector3.FORWARD.rotated(Vector3.UP, lerpf(half, -half, t))
		Sweep.RIGHT_TO_LEFT:
			return Vector3.FORWARD.rotated(Vector3.UP, lerpf(-half, half, t))
	# Overhead: from the top of the arc down to OVERHEAD_END_PITCH_DEG.
	var end := deg_to_rad(OVERHEAD_END_PITCH_DEG)
	return Vector3.FORWARD.rotated(Vector3.RIGHT, lerpf(end + deg_to_rad(arc_deg), end, t))


func is_heavy() -> bool:
	return kind == Kind.HEAVY


func _common(stats: MeleeStats, p_weapon_id: StringName) -> void:
	reach_m = stats.reach_m
	weakpoint_mult = stats.weakpoint_mult
	riposte_mult = stats.riposte_mult
	weapon_id = p_weapon_id
