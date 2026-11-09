class_name PlayerDefaults
extends GameData
## Baseline player stats (DESIGN §6.1). Shipped as content/player/player_defaults/.
##
## MatchSettings multipliers (player_health_mult, ...) are applied on top by later features.
## All numbers are placeholders, to be tuned in playtests.

@export_group("Health")
@export_range(1, 1000, 1) var max_health: float = 100.0

@export_group("Stamina")
@export_range(1, 1000, 1) var max_stamina: float = 100.0
@export_range(0, 500, 0.5, "suffix:/s") var stamina_regen_per_s: float = 20.0
## Seconds without spending stamina before regen starts.
@export_range(0, 10, 0.05, "suffix:s") var stamina_regen_delay_s: float = 1.0
@export_range(0, 500, 0.5, "suffix:/s") var sprint_drain_per_s: float = 12.0
## After hitting 0 stamina, sprinting stays locked until stamina regenerates to this value.
@export_range(0, 1000, 1) var exhausted_recover_at: float = 30.0

@export_group("Combat")
## Total frontal arc a block covers. Hits from outside it land in full.
@export_range(1, 360, 1, "suffix:°") var block_arc_deg: float = 120.0
## Move speed multipliers while fighting. Attacking/blocking also prevents sprinting.
@export_range(0.0, 1.0, 0.01) var block_move_mult: float = 0.6
@export_range(0.0, 1.0, 0.01) var charge_move_mult: float = 0.7
@export_range(0.0, 1.0, 0.01) var swing_move_mult: float = 0.85
@export_range(0.0, 1.0, 0.01) var guard_break_move_mult: float = 0.5
## After a guard break: no attacking or blocking for this long.
@export_range(0.0, 5.0, 0.05, "suffix:s") var guard_break_stagger_s: float = 1.0
## After a parry window ends without a parry, new block presses cannot parry for this long.
@export_range(0.0, 5.0, 0.05, "suffix:s") var parry_lockout_s: float = 0.5

@export_group("Firearms")
## Move speed multiplier while aiming down sights (aiming also locks sprint).
@export_range(0.0, 1.0, 0.01) var aim_move_mult: float = 0.6
## Field of view reduction while aiming, in degrees.
@export_range(0.0, 60.0, 0.5, "suffix:°") var aim_fov_delta: float = 15.0
## Reach of the interact ray (pickups, later doors and stations).
@export_range(0.5, 10.0, 0.1, "suffix:m") var interact_range_m: float = 2.5

@export_group("Dodge")
@export_range(0.0, 10.0, 0.1, "suffix:m") var dodge_distance_m: float = 3.0
@export_range(0.05, 2.0, 0.01, "suffix:s") var dodge_duration_s: float = 0.3
## Invulnerable to attacks (melee, bullets, blasts) for this long from the dodge start.
@export_range(0.0, 2.0, 0.01, "suffix:s") var dodge_iframe_s: float = 0.2
@export_range(0, 100, 1) var dodge_stamina_cost: float = 20.0
@export_range(0.0, 5.0, 0.05, "suffix:s") var dodge_cooldown_s: float = 0.4

@export_group("Speeds")
@export_range(0, 20, 0.05, "suffix:m/s") var walk_speed: float = 4.5
@export_range(0, 20, 0.05, "suffix:m/s") var sprint_speed: float = 7.0
@export_range(0, 20, 0.05, "suffix:m/s") var crouch_speed: float = 2.25

@export_group("Acceleration")
@export_range(0, 200, 0.5, "suffix:m/s²") var ground_accel: float = 30.0
@export_range(0, 200, 0.5, "suffix:m/s²") var ground_decel: float = 35.0
## Air control. Low on purpose: momentum mostly carries through a jump.
@export_range(0, 200, 0.5, "suffix:m/s²") var air_accel: float = 4.0
## Sprint only applies while the move input is within this angle of forward.
@export_range(0, 180, 1, "suffix:°") var sprint_max_angle_deg: float = 45.0

@export_group("Jump")
@export_range(0, 20, 0.05, "suffix:m/s") var jump_velocity: float = 4.5
@export_range(0, 5, 0.05) var gravity_mult: float = 1.0
## Grace period after walking off a ledge during which a jump still works.
@export_range(0, 1, 0.01, "suffix:s") var coyote_time_s: float = 0.1
## A jump pressed this long before landing still triggers on landing.
@export_range(0, 1, 0.01, "suffix:s") var jump_buffer_s: float = 0.1

@export_group("Body")
@export_range(0.5, 3, 0.01, "suffix:m") var stand_height: float = 1.8
@export_range(0.5, 3, 0.01, "suffix:m") var crouch_height: float = 1.1
@export_range(0.1, 1, 0.01, "suffix:m") var body_radius: float = 0.35
## Eyes sit this far below the top of the body.
@export_range(0, 1, 0.01, "suffix:m") var eye_offset: float = 0.15
## Time for the eye height to move between standing and crouched.
@export_range(0.01, 1, 0.01, "suffix:s") var crouch_transition_s: float = 0.12

@export_group("Camera")
@export_range(0, 40, 0.5, "suffix:°") var sprint_fov_add: float = 8.0
@export_range(0.1, 50, 0.1) var fov_lerp_speed: float = 8.0
@export_range(0, 1, 0.01, "suffix:m") var landing_dip_max_m: float = 0.12
## Landings slower than this (vertical m/s) cause no dip.
@export_range(0, 30, 0.1, "suffix:m/s") var landing_dip_min_speed: float = 4.0
## Vertical speed at which the dip reaches its maximum.
@export_range(0, 50, 0.1, "suffix:m/s") var landing_dip_full_speed: float = 12.0
@export_range(0.1, 50, 0.1) var landing_dip_recover_speed: float = 6.0


func get_eye_height(crouched: bool) -> float:
	return (crouch_height if crouched else stand_height) - eye_offset


func _validate(report: ValidationReport) -> void:
	var source := source_label()
	for field: String in [
		"max_health",
		"max_stamina",
		"walk_speed",
		"sprint_speed",
		"crouch_speed",
		"ground_accel",
		"ground_decel",
		"jump_velocity",
		"stand_height",
		"crouch_height",
		"body_radius",
		"crouch_transition_s",
	]:
		report.check_positive(source, field, float(get(field)))
	for field: String in [
		"stamina_regen_per_s",
		"stamina_regen_delay_s",
		"sprint_drain_per_s",
		"air_accel",
		"gravity_mult",
		"coyote_time_s",
		"jump_buffer_s",
		"eye_offset",
	]:
		report.check_min(source, field, float(get(field)), 0.0)
	report.check(crouch_height < stand_height, source, "crouch_height", "must be < stand_height")
	report.check(
		body_radius * 2.0 <= crouch_height,
		source,
		"body_radius",
		"capsule diameter must fit within crouch_height"
	)
	report.check(eye_offset < crouch_height, source, "eye_offset", "must be < crouch_height")
	report.check(
		exhausted_recover_at > 0.0 and exhausted_recover_at <= max_stamina,
		source,
		"exhausted_recover_at",
		"must be in (0, max_stamina]"
	)
	report.check_range(source, "block_arc_deg", block_arc_deg, 1.0, 360.0)
	for field: String in [
		"block_move_mult", "charge_move_mult", "swing_move_mult", "guard_break_move_mult"
	]:
		report.check_range(source, field, float(get(field)), 0.0, 1.0)
	report.check_min(source, "guard_break_stagger_s", guard_break_stagger_s, 0.0)
	report.check_min(source, "parry_lockout_s", parry_lockout_s, 0.0)
	report.check_range(source, "aim_move_mult", aim_move_mult, 0.0, 1.0)
	report.check_min(source, "aim_fov_delta", aim_fov_delta, 0.0)
	report.check_positive(source, "interact_range_m", interact_range_m)
	report.check_min(source, "dodge_distance_m", dodge_distance_m, 0.0)
	report.check_positive(source, "dodge_duration_s", dodge_duration_s)
	report.check_min(source, "dodge_stamina_cost", dodge_stamina_cost, 0.0)
	report.check_min(source, "dodge_cooldown_s", dodge_cooldown_s, 0.0)
	report.check(
		dodge_iframe_s <= dodge_duration_s, source, "dodge_iframe_s", "must be <= dodge_duration_s"
	)
	report.check(
		landing_dip_full_speed > landing_dip_min_speed,
		source,
		"landing_dip_full_speed",
		"must be > landing_dip_min_speed"
	)
	if sprint_speed <= walk_speed:
		report.warn(source, "sprint_speed", "is not faster than walk_speed")
	if crouch_speed > walk_speed:
		report.warn(source, "crouch_speed", "is faster than walk_speed")
