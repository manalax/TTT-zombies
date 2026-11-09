class_name MeleeViewmodel
extends Node3D
## Greybox first-person blade, posed from the melee weapon's state each frame. Purely visual and
## local: it never affects hit detection (that is MeleeSweep from the eye).
## Feedback: a short pose freeze and camera kick on hits, a spark and stronger kick on clangs.

const HILT_REST := Vector3(0.32, -0.32, -0.35)
const HILT_BLOCK := Vector3(0.0, -0.18, -0.45)
const HILT_SWING := Vector3(0.15, -0.25, -0.3)
const POSE_SPEED := 18.0
const HIT_FREEZE_S := 0.06
const HIT_KICK_DEG := 0.8
const CLANG_KICK_DEG := 2.5
const SPARK_LIFETIME_S := 0.12
const PARRY_FLASH_S := 0.15
const RIPOSTE_FREEZE_S := 0.12

var _freeze_left: float = 0.0
var _connected: bool = false
var _flash_left: float = 0.0
var _blade_material: StandardMaterial3D
var _pivot: Node3D
var _blade: MeshInstance3D

@onready var _camera: PlayerCamera = get_parent() as PlayerCamera


func _ready() -> void:
	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	add_child(_pivot)
	_blade = MeshInstance3D.new()
	_blade.name = "Blade"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.04, 0.08, 0.9)
	_blade.mesh = mesh
	_blade.position = Vector3(0, 0, -0.45)
	_blade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.75, 0.76, 0.8)
	material.metallic = 0.6
	material.roughness = 0.35
	# Drawn on top of the world so the blade never clips into walls.
	material.no_depth_test = true
	material.render_priority = 10
	_blade.material_override = material
	_blade_material = material
	_pivot.add_child(_blade)
	_pivot.position = HILT_REST


func _process(delta: float) -> void:
	var weapon := _weapon()
	if weapon == null or weapon.stats == null:
		return
	var player := owner as Player
	visible = player.loadout.active_slot == Loadout.MELEE and not player.loadout.is_switching()
	if not _connected:
		# The player (and its weapon) become ready after this child, so connect lazily.
		_connected = true
		weapon.swing_hit.connect(_on_swing_hit)
		weapon.clanged.connect(_on_clanged)
		weapon.parried.connect(_on_parried)
	if _flash_left > 0.0:
		_flash_left -= delta
		_blade_material.emission_enabled = _flash_left > 0.0
	if _freeze_left > 0.0:
		_freeze_left -= delta
		return
	var target := _target_pose(weapon)
	var t := 1.0 - exp(-POSE_SPEED * delta)
	_pivot.transform = _pivot.transform.interpolate_with(target, t)


func _target_pose(weapon: MeleeWeapon) -> Transform3D:
	var machine := weapon.machine
	var swing := weapon.swing
	var rest := Transform3D(Basis.from_euler(Vector3(deg_to_rad(25), deg_to_rad(12), 0)), HILT_REST)
	var pose := rest
	if machine.is_in_state(&"Blocking"):
		pose = Transform3D(Basis.from_euler(Vector3(0, deg_to_rad(90), deg_to_rad(80))), HILT_BLOCK)
	elif machine.is_in_state(&"Staggered"):
		pose = Transform3D(Basis.from_euler(Vector3(deg_to_rad(-50), deg_to_rad(30), 0)), HILT_REST)
	elif machine.is_in_state(&"Charging"):
		var charge := weapon.get_charge_ratio()
		var shake := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.006 * charge
		var heavy := SwingSpec.heavy(weapon.stats)
		pose = _aim(heavy.direction_at(0.0).lerp(Vector3.UP, 0.3), HILT_REST + shake)
	elif swing != null and machine.is_in_state(&"Windup"):
		pose = _aim(_cocked(swing.direction_at(0.0)), HILT_SWING)
	elif swing != null and machine.is_in_state(&"Active"):
		pose = _aim(swing.direction_at(weapon.sweep.progress), HILT_SWING)
	elif swing != null and machine.is_in_state(&"Recovery"):
		pose = _aim(swing.direction_at(1.0), HILT_SWING)
	return pose


## Pulls a swing's start direction further back for the windup telegraph.
func _cocked(direction: Vector3) -> Vector3:
	return (direction + Vector3(signf(direction.x) * 0.6, 0.4, 0.5)).normalized()


func _aim(direction: Vector3, hilt: Vector3) -> Transform3D:
	var up := Vector3.UP if absf(direction.normalized().y) < 0.95 else Vector3.BACK
	return Transform3D(Basis.looking_at(direction, up), hilt)


func _weapon() -> MeleeWeapon:
	var player := owner as Player
	return player.melee if player != null else null


func _on_swing_hit(results: Array[DamageResult]) -> void:
	for result in results:
		if result.accepted:
			_freeze_left = RIPOSTE_FREEZE_S if result.riposte else HIT_FREEZE_S
			if _camera != null:
				_camera.add_kick(HIT_KICK_DEG)
			return


func _on_parried() -> void:
	_flash_left = PARRY_FLASH_S
	_blade_material.emission_enabled = true
	_blade_material.emission = Color(1.0, 0.95, 0.6)
	_blade_material.emission_energy_multiplier = 3.0


func _on_clanged(point: Vector3) -> void:
	if _camera != null:
		_camera.add_kick(CLANG_KICK_DEG)
	_freeze_left = HIT_FREEZE_S * 2.0
	_spawn_spark(point)


func _spawn_spark(point: Vector3) -> void:
	if not is_inside_tree():
		return
	var spark := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.06
	mesh.height = 0.12
	spark.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.85, 0.3)
	spark.material_override = material
	spark.top_level = true
	add_child(spark)
	spark.global_position = point
	get_tree().create_timer(SPARK_LIFETIME_S).timeout.connect(spark.queue_free)
