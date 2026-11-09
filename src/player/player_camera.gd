class_name PlayerCamera
extends Camera3D
## First-person camera: follows the head's interpolated position each render frame and applies
## look, sprint FOV kick and landing dip. Runs top_level with physics interpolation off, so look
## is never smoothed or delayed (see docs/adr/0003-player-controller.md).

## Pitch kick in degrees from hits, clangs and guard breaks; springs back.
const KICK_RECOVER_SPEED := 14.0

var _dip: float = 0.0
var _kick_deg: float = 0.0
var _roll_deg: float = 0.0
var _fov_offset: float = 0.0

@onready var _player: Player = owner as Player
@onready var _head: Node3D = get_parent() as Node3D


func _ready() -> void:
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	fov = Settings.fov


func _process(delta: float) -> void:
	if _player == null or _player.defaults == null:
		return
	var d := _player.defaults
	var fov_target := d.sprint_fov_add if _player.is_sprinting() else 0.0
	if _player.is_aiming():
		fov_target = -d.aim_fov_delta
	_fov_offset = lerpf(_fov_offset, fov_target, 1.0 - exp(-d.fov_lerp_speed * delta))
	fov = Settings.fov + _fov_offset
	_dip = lerpf(_dip, 0.0, 1.0 - exp(-d.landing_dip_recover_speed * delta))
	_kick_deg = lerpf(_kick_deg, 0.0, 1.0 - exp(-KICK_RECOVER_SPEED * delta))
	_roll_deg = lerpf(_roll_deg, 0.0, 1.0 - exp(-KICK_RECOVER_SPEED * 0.6 * delta))
	var origin := _head.get_global_transform_interpolated().origin + Vector3.DOWN * _dip
	global_transform = Transform3D(
		Basis.from_euler(
			Vector3(_player.pitch + deg_to_rad(_kick_deg), _player.yaw, deg_to_rad(_roll_deg))
		),
		origin
	)


## Dips the camera after a landing, scaled by [param fall_speed] between the defaults' thresholds.
func add_landing(fall_speed: float) -> void:
	var d := _player.defaults
	var t := clampf(
		inverse_lerp(d.landing_dip_min_speed, d.landing_dip_full_speed, fall_speed), 0.0, 1.0
	)
	_dip = maxf(_dip, t * d.landing_dip_max_m)


## Local-only feedback: kicks the view up by [param degrees] (does not change aim).
func add_kick(degrees: float) -> void:
	_kick_deg = maxf(_kick_deg, degrees)


## Local-only feedback: rolls the view by [param degrees] (dodge lean), springs back.
func add_roll(degrees: float) -> void:
	_roll_deg = degrees


func get_dip() -> float:
	return _dip
