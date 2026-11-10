extends Node
## Local user preferences (look, FOV, crouch mode), saved to user://settings.cfg.
##
## Also holds the active MatchSettings (DESIGN §9). Until the lobby (F025) picks one, it is the
## Betrayal preset. Local prefs are never replicated: they are per-player comfort settings.
## There is no options menu yet (F051/F060): edit the cfg file's [controls] section,
## e.g. `mouse_sensitivity=0.2` or `crouch_mode="TOGGLE"`.

signal prefs_changed

enum CrouchMode { HOLD, TOGGLE }

const DEFAULT_PATH := "user://settings.cfg"
const DEFAULT_MATCH_PRESET := &"betrayal"
const SECTION := "controls"
const SENSITIVITY_RANGE := Vector2(0.01, 2.0)
const FOV_RANGE := Vector2(60.0, 120.0)

## Degrees of look rotation per pixel of mouse motion.
var mouse_sensitivity: float = 0.15
var invert_y: bool = false
## Base vertical field of view in degrees (sprint FOV kick is added on top).
var fov: float = 90.0
var crouch_mode: CrouchMode = CrouchMode.HOLD

## Rules for the current match. Read by Combat and later match services.
var match_settings: MatchSettings


func _ready() -> void:
	match_settings = ContentDB.get_item(&"MatchSettings", DEFAULT_MATCH_PRESET) as MatchSettings
	if match_settings == null:
		push_error("Settings: preset '%s' not found." % DEFAULT_MATCH_PRESET)
	load_prefs()


## Restores the built-in defaults (does not save).
func reset_prefs() -> void:
	mouse_sensitivity = 0.15
	invert_y = false
	fov = 90.0
	crouch_mode = CrouchMode.HOLD
	prefs_changed.emit()


## Loads prefs from [param path]. Missing file or keys keep the defaults; values are clamped and
## wrong types are ignored. Returns false only if the file exists but cannot be parsed.
func load_prefs(path: String = DEFAULT_PATH) -> bool:
	reset_prefs()
	if not FileAccess.file_exists(path):
		return true
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		push_warning("Settings: could not parse %s; using defaults." % path)
		return false
	var sens: Variant = cfg.get_value(SECTION, "mouse_sensitivity", mouse_sensitivity)
	if sens is float or sens is int:
		mouse_sensitivity = clampf(float(sens), SENSITIVITY_RANGE.x, SENSITIVITY_RANGE.y)
	var inv: Variant = cfg.get_value(SECTION, "invert_y", invert_y)
	if inv is bool:
		invert_y = inv
	var fov_value: Variant = cfg.get_value(SECTION, "fov", fov)
	if fov_value is float or fov_value is int:
		fov = clampf(float(fov_value), FOV_RANGE.x, FOV_RANGE.y)
	var mode: Variant = cfg.get_value(SECTION, "crouch_mode", "")
	if mode is String and CrouchMode.has(mode):
		crouch_mode = CrouchMode[mode] as CrouchMode
	prefs_changed.emit()
	return true


func save_prefs(path: String = DEFAULT_PATH) -> Error:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value(SECTION, "invert_y", invert_y)
	cfg.set_value(SECTION, "fov", fov)
	cfg.set_value(SECTION, "crouch_mode", CrouchMode.find_key(crouch_mode))
	return cfg.save(path)
