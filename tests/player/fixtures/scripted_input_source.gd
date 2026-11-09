extends PlayerInputSource
## Test input source: returns whatever intent the test sets. jump_pressed is one-shot.

var current: MoveIntent = MoveIntent.new()
var look: Vector2 = Vector2.ZERO
var crouch_cancelled: bool = false
var attack_held: bool = false
var block_held: bool = false
var aim_held: bool = false
var _slot: int = -1
var _cycle: int = 0
var _reload: bool = false
var _interact: bool = false


func hold(move: Vector2, sprint: bool = false, crouch: bool = false) -> void:
	current = MoveIntent.make(move, sprint, false, crouch)


func press_jump() -> void:
	current.jump_pressed = true


func press_slot(slot: int) -> void:
	_slot = slot


func cycle_weapon(direction: int) -> void:
	_cycle = direction


func press_reload() -> void:
	_reload = true


func press_interact() -> void:
	_interact = true


func press_dodge() -> void:
	current.dodge_pressed = true


func get_intent() -> MoveIntent:
	var intent := MoveIntent.make(
		current.move, current.sprint, current.jump_pressed, current.crouch
	)
	current.jump_pressed = false
	intent.dodge_pressed = current.dodge_pressed
	current.dodge_pressed = false
	intent.attack_held = attack_held
	intent.block_held = block_held
	intent.aim_held = aim_held
	intent.slot_pressed = _slot
	intent.cycle = _cycle
	intent.reload_pressed = _reload
	intent.interact_pressed = _interact
	_slot = -1
	_cycle = 0
	_reload = false
	_interact = false
	return intent


func consume_look() -> Vector2:
	var value := look
	look = Vector2.ZERO
	return value


func cancel_crouch() -> void:
	crouch_cancelled = true
