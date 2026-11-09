class_name TrainingDummy
extends StaticBody3D
## Dev target for damage (F011) and melee (F012). Cult faction, so Hunter attacks are hostile.
## Shows HP, poise state and the last hit; resets 2 s after dying. Faces -Z (block arc).
##
## Options: armour; always blocking (shows guard breaks); sparring (swings at whatever stands in
## front of it every few seconds, with a red telegraph, or purple if unparryable). Being staggered
## or stunned (parried) interrupts a swing.

signal spar_swung(results: Array[DamageResult])

@export var title: String = "Training Dummy"
@export_range(1, 10000, 1) var max_health: float = 200.0
@export_range(0.0, 0.95, 0.01) var armor: float = 0.0
## Always blocking (melee only), so block and guard break can be seen.
@export var block_always: bool = false
@export_range(0.0, 1.0, 0.01) var block_reduction: float = 0.7
@export_range(0.0, 5.0, 0.05) var block_stamina_per_damage: float = 0.5
@export_range(0.0, 30.0, 0.5, "suffix:s") var reset_delay_s: float = 2.0
## After a guard break the block stays down this long.
@export_range(0.0, 10.0, 0.05, "suffix:s") var guard_break_s: float = 1.0

@export_group("Sparring")
@export var spar_enabled: bool = false
@export_range(0.5, 30.0, 0.1, "suffix:s") var spar_interval_s: float = 2.5
@export_range(0.05, 3.0, 0.05, "suffix:s") var spar_windup_s: float = 0.6
@export_range(0.05, 1.0, 0.01, "suffix:s") var spar_active_s: float = 0.15
@export_range(0, 500, 1) var spar_damage: float = 40.0
@export_range(0, 200, 1) var spar_stagger: float = 20.0
@export_range(0.5, 5.0, 0.05, "suffix:m") var spar_reach_m: float = 2.2
@export_range(10, 180, 1, "suffix:°") var spar_arc_deg: float = 100.0
@export_range(0.5, 3.0, 0.05, "suffix:m") var spar_eye_height_m: float = 1.5
## Unparryable and unblockable swing (purple telegraph): must be dodged.
@export var spar_unparryable: bool = false

var last_hit: String = ""
var guard_broken: bool = false
## "idle", "windup" or "active".
var spar_phase: StringName = &"idle"

var _guard_timer: float = 0.0
var _reset_left: float = 0.0
var _spar_timer: float = 0.0
var _spar_sweep: MeleeSweep = MeleeSweep.new()
var _head_material: StandardMaterial3D

@onready var health: HealthComponent = $HealthComponent
@onready var stamina: StaminaComponent = $StaminaComponent
@onready var poise: PoiseComponent = $PoiseComponent
@onready var _label: Label3D = $Label
@onready var _head_mesh: MeshInstance3D = $Head/Mesh
@onready var _arm: Node3D = $ArmR


func _ready() -> void:
	collision_layer = PhysicsLayers.ENEMIES
	collision_mask = 0
	health.faction = CombatTypes.Faction.CULT
	health.armor = armor
	health.setup(max_health)
	health.poise = poise
	stamina.refill()
	if block_always:
		var block := BlockState.new()
		block.active = true
		block.reduction = block_reduction
		block.stamina_per_damage = block_stamina_per_damage
		block.stamina = stamina
		health.block = block
	# Own material so the telegraph glow does not tint every dummy.
	_head_material = (_head_mesh.get_active_material(0) as StandardMaterial3D).duplicate()
	_head_mesh.material_override = _head_material
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	poise.staggered.connect(_on_staggered)
	health.stunned.connect(_on_stunned)
	_spar_timer = spar_interval_s
	_refresh()


func _physics_process(delta: float) -> void:
	step(delta)


## One simulation step. Public so tests can drive it deterministically.
func step(delta: float) -> void:
	stamina.tick(delta)
	poise.tick(delta)
	health.tick(delta)
	if health.is_dead():
		_reset_left -= delta
		if _reset_left <= 0.0:
			health.reset()
			stamina.refill()
			poise.reset()
			last_hit = "reset"
	if guard_broken:
		_guard_timer -= delta
		if _guard_timer <= 0.0:
			guard_broken = false
			if health.block != null:
				health.block.active = true
	if spar_enabled:
		_spar_step(delta)
	_refresh()


func _spar_step(delta: float) -> void:
	if health.is_dead() or poise.is_staggered() or health.is_stunned():
		_spar_cancel()
		return
	_spar_timer -= delta
	match spar_phase:
		&"idle":
			if _spar_timer <= 0.0:
				spar_phase = &"windup"
				_spar_timer = spar_windup_s
				_set_telegraph(true)
		&"windup":
			if _spar_timer <= 0.0:
				spar_phase = &"active"
				_spar_timer = spar_active_s
				_set_telegraph(false)
				_spar_sweep.begin(_spar_spec(), health, Hitscan.collect_rids(self))
		&"active":
			var t := 1.0 - maxf(_spar_timer, 0.0) / spar_active_s
			var space := get_world_3d().direct_space_state
			var step_result := _spar_sweep.advance(space, spar_eye(), t)
			if not step_result.hits.is_empty():
				spar_swung.emit(step_result.hits)
			if t >= 1.0 or step_result.clanged:
				spar_phase = &"idle"
				_spar_timer = spar_interval_s


## Makes the sparring swing land on the next step (tests, tuning): skips the rest of the windup.
func trigger_spar_swing() -> void:
	spar_phase = &"windup"
	_spar_timer = 0.0


func spar_eye() -> Transform3D:
	return Transform3D(
		global_basis.orthonormalized(), global_position + Vector3.UP * spar_eye_height_m
	)


func _spar_spec() -> SwingSpec:
	var spec := SwingSpec.new()
	spec.sweep = SwingSpec.Sweep.RIGHT_TO_LEFT
	spec.damage = spar_damage
	spec.stagger = spar_stagger
	spec.arc_deg = spar_arc_deg
	spec.reach_m = spar_reach_m
	spec.active_s = spar_active_s
	spec.weapon_id = &"sparring_dummy"
	spec.unparryable = spar_unparryable
	return spec


func _spar_cancel() -> void:
	if spar_phase != &"idle":
		spar_phase = &"idle"
		_spar_timer = spar_interval_s
		_set_telegraph(false)


func _set_telegraph(on: bool) -> void:
	_head_material.emission_enabled = on
	_head_material.emission = Color(0.6, 0.1, 1.0) if spar_unparryable else Color(1.0, 0.1, 0.05)
	_head_material.emission_energy_multiplier = 2.0
	_arm.rotation_degrees.x = 150.0 if on else 0.0


func _on_damaged(result: DamageResult) -> void:
	last_hit = result.describe()
	if result.guard_broken and health.block != null:
		guard_broken = true
		_guard_timer = guard_break_s
		health.block.active = false
	_refresh()


func _on_staggered(_duration: float) -> void:
	_spar_cancel()
	_refresh()


func _on_stunned(_duration: float) -> void:
	_spar_cancel()
	last_hit = "PARRIED"
	_refresh()


func _on_died(_result: DamageResult) -> void:
	_spar_cancel()
	_reset_left = reset_delay_s
	_refresh()


## Shows a rejected hit (e.g. "no damage (friendly fire off)") on the label.
func show_result(result: DamageResult) -> void:
	if not result.accepted:
		last_hit = result.describe()
		_refresh()


func _refresh() -> void:
	var lines := PackedStringArray([title])
	if health.is_dead():
		lines.append("DOWN")
	else:
		lines.append("HP %.0f / %.0f" % [health.current_health, health.max_health])
	if block_always:
		lines.append("Stamina %.0f" % stamina.current)
	if guard_broken:
		lines.append("GUARD BROKEN")
	if poise.is_staggered():
		lines.append("STAGGERED")
	if health.is_stunned():
		lines.append("STUNNED (riposte!)")
	if spar_phase == &"windup":
		lines.append("!! UNPARRYABLE !!" if spar_unparryable else "!")
	if not last_hit.is_empty():
		lines.append(last_hit)
	_label.text = "\n".join(lines)
