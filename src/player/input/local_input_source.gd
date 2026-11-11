class_name LocalInputSource
extends PlayerInputSource
## Keyboard and mouse input for the local player.
##
## Applies the local prefs from the Settings autoload (sensitivity, invert Y, hold/toggle
## crouch) and owns mouse capture: `pause` releases the mouse, a click recaptures it.

## Capture the mouse when the node enters the tree. Tests turn this off.
@export var capture_on_ready: bool = true

var _look: Vector2 = Vector2.ZERO
var _crouch_toggled: bool = false
var _cycle: int = 0


func _ready() -> void:
	if capture_on_ready:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.is_pressed() and not is_capturing():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and is_capturing():
		add_mouse_motion((event as InputEventMouseMotion).screen_relative)
	elif is_capturing() and event.is_action_pressed(&"weapon_next"):
		# Wheel "presses" are released in the same frame, so accumulate them here.
		_cycle += 1
	elif is_capturing() and event.is_action_pressed(&"weapon_prev"):
		_cycle -= 1


func is_capturing() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


## Converts raw mouse motion (pixels) into look degrees using the player's prefs.
func add_mouse_motion(relative: Vector2) -> void:
	var look := relative * Settings.mouse_sensitivity
	if Settings.invert_y:
		look.y = -look.y
	_look += look


func consume_look() -> Vector2:
	var look := _look
	_look = Vector2.ZERO
	return look


func get_intent() -> MoveIntent:
	if Settings.crouch_mode == Settings.CrouchMode.TOGGLE:
		if Input.is_action_just_pressed(&"crouch"):
			_crouch_toggled = not _crouch_toggled
	else:
		_crouch_toggled = false
	var crouch := (
		_crouch_toggled
		if Settings.crouch_mode == Settings.CrouchMode.TOGGLE
		else Input.is_action_pressed(&"crouch")
	)
	var intent := MoveIntent.make(
		Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back"),
		Input.is_action_pressed(&"sprint"),
		Input.is_action_just_pressed(&"jump"),
		crouch
	)
	intent.dodge_pressed = Input.is_action_just_pressed(&"dodge")
	intent.reload_pressed = Input.is_action_just_pressed(&"reload")
	intent.interact_pressed = Input.is_action_just_pressed(&"interact")
	intent.interact_held = Input.is_action_pressed(&"interact")
	for slot in 3:
		if Input.is_action_just_pressed(StringName("weapon_slot_%d" % (slot + 1))):
			intent.slot_pressed = slot
	intent.cycle = signi(_cycle)
	_cycle = 0
	# The click that recaptures the mouse must not count as an attack.
	if is_capturing() or not capture_on_ready:
		intent.attack_held = Input.is_action_pressed(&"attack_light")
		intent.block_held = Input.is_action_pressed(&"block")
		intent.aim_held = intent.block_held
	return intent


func cancel_crouch() -> void:
	_crouch_toggled = false
