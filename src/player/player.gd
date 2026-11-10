# gdlint:disable=max-public-methods
class_name Player
extends CharacterBody3D
## First-person Hunter body (DESIGN §6, docs/adr/0003-player-controller.md).
##
## Each physics step: read the intent from the input source, tick stamina and the movement
## machine (which sets the motor parameters and posture), then integrate and move_and_slide.
## Look is applied per render frame in _process for responsiveness.
## Damage arrives through Combat.apply() on the HealthComponent; death enters the Dead state.

## Emitted when the body lands, with the vertical speed it landed at (m/s, positive).
signal landed(fall_speed: float)
## Interact was pressed on something that could not be used; reason e.g. &"points".
signal interact_denied(reason: StringName)

const PITCH_LIMIT_DEG := 89.0
const DEFAULTS_ID := &"player_defaults"
## Group of the player controlled on this machine (debug tools, HUD).
const LOCAL_GROUP := &"local_player"
## Top part of the body covered by the head hurtbox; the body hurtbox stops below it so it
## never shields the weak point.
const HEAD_ZONE_M := 0.4

## Null = the shipped content/player/player_defaults.
@export var defaults: PlayerDefaults
## Weapon ids to spawn with instead of MatchSettings.starting_loadout (dev sandbox, tests).
@export var starting_loadout_override: Array[StringName] = []

## The intent for the current physics step. Read by movement states.
var intent: MoveIntent = MoveIntent.new()
var input_source: PlayerInputSource
var jump_assist: JumpAssist
## Look angles in radians. Yaw turns the body; pitch only the camera.
var yaw: float = 0.0
var pitch: float = 0.0

## Set each step by the weapon: move speed multiplier and whether sprinting is locked out.
var combat_speed_mult: float = 1.0
var sprint_locked: bool = false

var _wish_override: Vector3 = Vector3.ZERO
var _dodge_cooldown_left: float = 0.0

var _target_speed: float = 0.0
var _accel: float = 0.0
var _decel: float = 0.0
var _crouched: bool = false
var _last_fall_speed: float = 0.0
var _gravity: float = 9.8

@onready var stamina: StaminaComponent = $StaminaComponent
@onready var health: HealthComponent = $HealthComponent
@onready var points: PointsComponent = $PointsComponent
@onready var perks: PerkComponent = $PerkComponent
@onready var melee: MeleeWeapon = $MeleeWeapon
@onready var firearm: Firearm = $Firearm
@onready var loadout: Loadout = $Loadout
@onready var movement: StateMachine = $MovementMachine
@onready var head: Node3D = $Head
@onready var camera: PlayerCamera = $Head/Camera
@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var _body_mesh: Node3D = $Body
@onready var _capsule: CapsuleShape3D = _collision.shape as CapsuleShape3D
@onready var _body_hurtbox_shape: CollisionShape3D = $BodyHurtbox/CollisionShape3D
@onready var _hurt_capsule: CapsuleShape3D = _body_hurtbox_shape.shape as CapsuleShape3D


func _ready() -> void:
	add_to_group(&"debug_info")
	add_to_group(AITargeting.GROUP)
	if defaults == null:
		defaults = ContentDB.get_item(&"PlayerDefaults", DEFAULTS_ID) as PlayerDefaults
	if defaults == null:
		push_error("Player: PlayerDefaults '%s' not found; using built-in values." % DEFAULTS_ID)
		defaults = PlayerDefaults.new()
	if input_source == null:
		input_source = _find_input_source()
	if input_source is LocalInputSource:
		add_to_group(LOCAL_GROUP)
	collision_layer = PhysicsLayers.PLAYERS
	collision_mask = PhysicsLayers.CHARACTER_MASK
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	_gravity *= defaults.gravity_mult
	jump_assist = JumpAssist.new(defaults.coyote_time_s, defaults.jump_buffer_s)
	stamina.configure(defaults)
	_setup_health()
	points.peer_id = health.peer_id
	points.reset(Settings.match_settings.starting_points if Settings.match_settings != null else 0)
	loadout.setup(_starting_loadout())
	# Each player needs its own shape: crouching resizes it.
	_capsule = _capsule.duplicate() as CapsuleShape3D
	_collision.shape = _capsule
	_capsule.radius = defaults.body_radius
	_hurt_capsule = _hurt_capsule.duplicate() as CapsuleShape3D
	_body_hurtbox_shape.shape = _hurt_capsule
	_hurt_capsule.radius = defaults.body_radius
	_apply_shape(defaults.stand_height)
	head.position.y = defaults.get_eye_height(false)
	yaw = rotation.y
	movement.start()


func _process(_delta: float) -> void:
	if input_source == null:
		return
	var look := input_source.consume_look()
	yaw = wrapf(yaw - deg_to_rad(look.x), -PI, PI)
	var limit := deg_to_rad(PITCH_LIMIT_DEG)
	pitch = clampf(pitch - deg_to_rad(look.y), -limit, limit)


func _physics_process(delta: float) -> void:
	step(delta)


## One simulation step. Public so tests (and later server-side simulation) can drive it.
func step(delta: float) -> void:
	rotation.y = yaw
	intent = input_source.get_intent() if input_source != null else MoveIntent.new()
	jump_assist.tick(delta, is_on_floor(), intent.jump_pressed)
	stamina.tick(delta)
	health.tick(delta)
	_dodge_cooldown_left = maxf(0.0, _dodge_cooldown_left - delta)
	loadout.physics_tick(delta)
	if loadout.is_melee_active():
		melee.physics_tick(delta)
	elif loadout.is_firearm_active():
		firearm.physics_tick(delta)
	else:
		set_combat_modifiers(1.0, false)
	if intent.interact_pressed and not is_dead():
		try_interact()
	movement.physics_tick(delta)

	var wish := PlayerMotor.wish_direction(intent.move, global_basis)
	var speed := _target_speed * (combat_speed_mult if is_on_floor() else 1.0)
	if _wish_override != Vector3.ZERO:
		wish = _wish_override
		speed = _target_speed
	velocity = PlayerMotor.accelerate(velocity, wish, speed, _accel, _decel, delta)
	if not is_on_floor():
		velocity = PlayerMotor.apply_gravity(velocity, _gravity, delta)
	_last_fall_speed = maxf(0.0, -velocity.y)
	move_and_slide()
	_update_eye_height(delta)


## The eye: physics head position, facing the look direction. Attacks originate here.
func get_eye_transform() -> Transform3D:
	return Transform3D(Basis.from_euler(Vector3(pitch, yaw, 0.0)), head.global_position)


func is_aiming() -> bool:
	return loadout.is_firearm_active() and firearm.aiming


## The Interactable the eye is looking at within interact_range_m, or null.
func get_interact_target() -> Interactable:
	if not is_inside_tree():
		return null
	var eye := get_eye_transform()
	var to := eye.origin - eye.basis.z * defaults.interact_range_m
	var query := PhysicsRayQueryParameters3D.create(
		eye.origin, to, PhysicsLayers.WORLD, Hitscan.collect_rids(self)
	)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	return Interactable.find_on(hit["collider"])


## Uses the Interactable in view. Returns true if something was used; emits
## [signal interact_denied] if one was there but could not be used (e.g. not enough points).
func try_interact() -> bool:
	var target := get_interact_target()
	if target == null:
		return false
	var reason := target.use(self)
	if reason != &"":
		interact_denied.emit(reason)
		return false
	return true


## Brings the player back at [param at] (sandbox match reset; F034/F038 add their own rules):
## full health (perks kept), stamina, starting points and the starting loadout.
func respawn(at: Transform3D) -> void:
	if not Net.is_authority():
		return
	global_transform = at
	yaw = rotation.y
	pitch = 0.0
	velocity = Vector3.ZERO
	health.reset()
	apply_perks()
	stamina.refill()
	points.reset(Settings.match_settings.starting_points if Settings.match_settings != null else 0)
	loadout.setup(_starting_loadout())
	if movement.is_in_state(&"Dead"):
		movement.transition_to(&"Idle")
	set_crouched(false)


## Recomputes stats that perks modify at spawn time: max health (current health moves with it)
## and stamina regen. Rate-based perks (reload, riposte) are read where they apply.
func apply_perks() -> void:
	var mult := Settings.match_settings.player_health_mult if Settings.match_settings else 1.0
	var target := defaults.max_health * mult + perks.stat(&"max_health_add")
	if not is_equal_approx(target, health.max_health):
		health.set_max(target)
	stamina.regen_per_s = defaults.stamina_regen_per_s * perks.stat(&"stamina_regen_mult")


## Called by weapon states each step.
func set_combat_modifiers(speed_mult: float, p_sprint_locked: bool) -> void:
	combat_speed_mult = speed_mult
	sprint_locked = p_sprint_locked


## Called by movement states to set this step's horizontal motor parameters.
func set_move_params(target_speed: float, accel: float, decel: float) -> void:
	_target_speed = target_speed
	_accel = accel
	_decel = decel


## Movement states can steer the motor directly (dodge dash). ZERO = use the move input.
func set_wish_override(direction: Vector3) -> void:
	_wish_override = direction


func is_dodging() -> bool:
	return movement.is_in_state(&"Dodge")


func can_dodge() -> bool:
	return (
		not is_dodging()
		and _dodge_cooldown_left <= 0.0
		and stamina.current > 0.0
		and melee.allows_dodge()
		and has_headroom()
	)


func start_dodge_cooldown() -> void:
	_dodge_cooldown_left = defaults.dodge_cooldown_s


func jump() -> void:
	set_crouched(false)
	velocity.y = defaults.jump_velocity


## Switches posture. Standing up is skipped when there is no headroom.
func set_crouched(value: bool) -> void:
	if value == _crouched:
		return
	if not value and not has_headroom():
		return
	_crouched = value
	_apply_shape(defaults.crouch_height if value else defaults.stand_height)


func is_crouched() -> bool:
	return _crouched


## True if there is room to stand (always true while standing).
func has_headroom() -> bool:
	if not _crouched:
		return true
	var rise := defaults.stand_height - defaults.crouch_height
	return not test_move(global_transform, Vector3.UP * rise)


func is_dead() -> bool:
	return health.is_dead()


func is_sprinting() -> bool:
	return movement.is_in_state(&"Sprint")


## Vertical speed (m/s) just before the last move_and_slide; the landing speed after a landing.
func get_last_fall_speed() -> float:
	return _last_fall_speed


func notify_landed(fall_speed: float) -> void:
	landed.emit(fall_speed)
	camera.add_landing(fall_speed)


func get_movement_state() -> String:
	return movement.get_active_path()


## Shown by the F3 debug overlay.
func get_debug_info() -> Dictionary:
	return {
		"speed": "%.2f m/s" % PlayerMotor.horizontal_speed(velocity),
		"vertical": "%.2f m/s" % velocity.y,
		"state": get_movement_state(),
		"stamina":
		(
			"%.0f / %.0f%s"
			% [
				stamina.current,
				stamina.max_stamina,
				" (exhausted)" if stamina.is_exhausted() else ""
			]
		),
		"health": "%.0f / %.0f" % [health.current_health, health.max_health],
		"perks": ", ".join(perks.names()) if perks.count() > 0 else "-",
		"points":
		(
			"%d (last %s)"
			% [points.balance, points.last_award.describe() if points.last_award != null else "-"]
		),
		"loadout": loadout.describe(),
		"weapon": _weapon_debug(),
		"parry": _parry_debug(),
		"dodge": _dodge_debug(),
		"grounded": is_on_floor(),
		"crouched": _crouched,
	}


func _weapon_debug() -> String:
	if loadout.is_melee_active():
		var charge := melee.get_charge_ratio()
		return (
			"%s %s%s"
			% [
				melee.weapon.id,
				melee.get_state_path(),
				" %d%%" % roundi(charge * 100.0) if charge > 0 else ""
			]
		)
	if loadout.is_firearm_active():
		return (
			"%s %s spread %.1f°%s"
			% [
				firearm.weapon.id,
				firearm.get_state_path(),
				firearm.current_spread(),
				" ADS" if firearm.aiming else ""
			]
		)
	return "switching"


func _parry_debug() -> String:
	var block := health.block
	var text := "-"
	if block.is_parry_window_open():
		text = "OPEN %.0f ms left" % ((block.parry_window_s - block.since_press) * 1000.0)
	elif block.is_locked_out():
		text = "lockout %.0f ms" % (block.get_lockout_left() * 1000.0)
	if not is_nan(block.last_timing_ms):
		var timing := block.last_timing_ms
		text += (" | last %+.0f ms %s" % [timing, "(inside)" if timing <= 0.0 else "late"])
	return text


func _dodge_debug() -> String:
	if health.has_iframes():
		return "i-frames %.0f ms" % (health.get_iframes_left() * 1000.0)
	if is_dodging():
		return "dodging"
	if _dodge_cooldown_left > 0.0:
		return "cooldown %.0f ms" % (_dodge_cooldown_left * 1000.0)
	return "ready"


func _apply_shape(height: float) -> void:
	_capsule.height = height
	_collision.position.y = height * 0.5
	# The body hurtbox matches the capsule; the head hurtbox rides on the Head node.
	var body_zone := maxf(height - HEAD_ZONE_M, defaults.body_radius * 2.0)
	_hurt_capsule.height = body_zone
	_body_hurtbox_shape.position.y = body_zone * 0.5
	# Greybox body (hidden from the own camera): squash it so others will see the posture.
	_body_mesh.scale.y = height / defaults.stand_height
	_body_mesh.position.y = height * 0.5


func _update_eye_height(delta: float) -> void:
	var rate := (defaults.stand_height - defaults.crouch_height) / defaults.crouch_transition_s
	var target := defaults.get_eye_height(_crouched)
	head.position.y = move_toward(head.position.y, target, rate * delta)


func _setup_health() -> void:
	var mult := 1.0
	if Settings.match_settings != null:
		mult = Settings.match_settings.player_health_mult
	health.faction = CombatTypes.Faction.HUNTER
	health.peer_id = get_multiplayer_authority()
	health.setup(defaults.max_health * mult)
	var block := BlockState.new()
	block.arc_deg = defaults.block_arc_deg
	block.parry_lockout_s = defaults.parry_lockout_s
	block.stamina = stamina
	health.block = block
	health.died.connect(_on_died)
	health.damaged.connect(_on_damaged)
	health.stunned.connect(_on_stunned)


func _on_died(_result: DamageResult) -> void:
	movement.transition_to(&"Dead")


func _on_damaged(result: DamageResult) -> void:
	if result.parried:
		melee.parried.emit()
		camera.add_kick(3.0)
		print("[melee] PARRY (%+.0f ms from window edge)" % result.parry_timing_ms)
	elif result.guard_broken:
		melee.notify_guard_broken()
		camera.add_kick(4.0)


func _on_stunned(duration: float) -> void:
	melee.notify_staggered(duration)
	firearm.notify_staggered(duration)
	camera.add_kick(3.0)


## Spawn weapons: the override if set, else MatchSettings.starting_loadout, else a sword.
func _starting_loadout() -> Array[StringName]:
	var ids: Array[StringName] = []
	if not starting_loadout_override.is_empty():
		ids.assign(starting_loadout_override)
	elif Settings.match_settings != null:
		ids.assign(Settings.match_settings.starting_loadout)
	if ids.is_empty():
		ids.append(&"arming_sword")
	return ids


func _find_input_source() -> PlayerInputSource:
	for child in get_children():
		if child is PlayerInputSource:
			return child as PlayerInputSource
	return null
