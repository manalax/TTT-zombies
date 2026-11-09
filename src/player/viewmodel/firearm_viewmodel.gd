class_name FirearmViewmodel
extends Node3D
## Greybox first-person gun (a box), posed from the firearm state: hip, aim (centred), lowered
## (sprint), reload dip. Firing kicks the model back and flashes the muzzle. Purely visual and
## local: aim never moves (spread bloom only, F014).

const HIP := Vector3(0.22, -0.2, -0.45)
const AIM := Vector3(0.0, -0.11, -0.35)
const LOWERED := Vector3(0.2, -0.38, -0.35)
const POSE_SPEED := 16.0
const KICK_M := 0.05
const FLASH_S := 0.05

var _connected: bool = false
var _kick: float = 0.0
var _flash_left: float = 0.0
var _gun: Node3D
var _flash: OmniLight3D
var _flash_mesh: MeshInstance3D


func _ready() -> void:
	_gun = Node3D.new()
	_gun.name = "Gun"
	add_child(_gun)
	var body := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.06, 0.1, 0.45)
	body.mesh = mesh
	body.position = Vector3(0, 0, -0.1)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.25, 0.2, 0.17)
	material.no_depth_test = true
	material.render_priority = 10
	body.material_override = material
	_gun.add_child(body)
	_flash = OmniLight3D.new()
	_flash.light_color = Color(1.0, 0.8, 0.4)
	_flash.light_energy = 4.0
	_flash.omni_range = 4.0
	_flash.position = Vector3(0, 0, -0.38)
	_flash.visible = false
	_gun.add_child(_flash)
	_flash_mesh = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.12, 0.12)
	_flash_mesh.mesh = quad
	var flash_material := StandardMaterial3D.new()
	flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_material.albedo_color = Color(1.0, 0.85, 0.4)
	flash_material.no_depth_test = true
	flash_material.render_priority = 11
	flash_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_flash_mesh.material_override = flash_material
	_flash_mesh.position = Vector3(0, 0, -0.38)
	_flash_mesh.visible = false
	_gun.add_child(_flash_mesh)
	_gun.position = HIP


func _process(delta: float) -> void:
	var player := owner as Player
	if player == null or player.loadout == null:
		return
	if not _connected:
		_connected = true
		player.firearm.shot_fired.connect(_on_shot)
	visible = Loadout.is_firearm_slot(player.loadout.active_slot)
	if not visible:
		return
	var gun := player.firearm
	var target := HIP
	var rotation_x := 0.0
	if player.loadout.is_switching():
		target = LOWERED + Vector3(0, -0.2, 0)
	elif gun.machine.is_in_state(&"Lowered"):
		target = LOWERED
		rotation_x = deg_to_rad(-25)
	elif gun.machine.is_in_state(&"Reloading"):
		target = HIP + Vector3(-0.05, -0.08, 0)
		rotation_x = deg_to_rad(-35)
	elif gun.aiming:
		target = AIM
	_kick = lerpf(_kick, 0.0, 1.0 - exp(-20.0 * delta))
	var t := 1.0 - exp(-POSE_SPEED * delta)
	_gun.position = _gun.position.lerp(target + Vector3(0, 0, _kick), t)
	_gun.rotation.x = lerpf(_gun.rotation.x, rotation_x + _kick * 2.0, t)
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_flash.visible = false
			_flash_mesh.visible = false


func _on_shot(_results: Array[DamageResult], tracers: Array[Vector3]) -> void:
	_kick = KICK_M
	_flash_left = FLASH_S
	_flash.visible = true
	_flash_mesh.visible = true
	var muzzle := _flash_mesh.global_position
	for i in range(0, tracers.size(), 2):
		TracerDraw.submit(muzzle, tracers[i + 1])
