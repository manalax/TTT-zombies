class_name Barricade
extends StaticBody3D
## A boarded window (F046, docs/adr/0013-barricades.md). Local -Z is outside (the spawn closet),
## +Z inside.
##
## The body sits on PhysicsLayers.BARRIER, so it always blocks players and enemies, but shots,
## swings and sight lines pass through. It is in `nav_blockers`, so each closet is its own nav
## island. Enemies spawned behind it (EnemySpawnPoint.barricade) tear planks one at a time (one
## tearer per window), then climb through (one climber at a time; the brain's Climb state
## ignores this body while it moves). Players hold interact on the inside to nail planks back
## for BarricadeData.repair_points each.

signal planks_changed(planks: int)

const NAV_BLOCKER_GROUP := &"nav_blockers"
const GROUP := &"barricades"

## Unique per map; Events carry it.
@export var barricade_id: StringName = &"window"
## BarricadeData id in ContentDB.
@export var data_id: StringName = &"boarded_window"

var data: BarricadeData
var planks: int = 0
var tearer: EnemyBase
var climber: EnemyBase

@onready var interactable: Interactable = $Interactable
@onready var _planks_root: Node3D = $Planks
@onready var _outer: Marker3D = $OuterPoint
@onready var _inner: Marker3D = $InnerPoint


func _ready() -> void:
	add_to_group(NAV_BLOCKER_GROUP)
	add_to_group(GROUP)
	collision_layer = PhysicsLayers.BARRIER
	collision_mask = 0
	data = ContentDB.get_item(&"BarricadeData", data_id) as BarricadeData
	if data == null:
		push_error("Barricade '%s': BarricadeData '%s' not found." % [name, data_id])
		data = BarricadeData.new()
	planks = data.plank_count
	interactable.hold_interval_s = data.repair_interval_s
	interactable.updater = _configure
	interactable.used.connect(repair)
	_refresh()


func max_planks() -> int:
	return data.plank_count


func is_open() -> bool:
	return planks <= 0


func is_full() -> bool:
	return planks >= data.plank_count


func outer_point() -> Vector3:
	return _outer.global_position


func inner_point() -> Vector3:
	return _inner.global_position


## True if [param point] is on the inside (+Z) of the window.
func is_inside(point: Vector3) -> bool:
	return (point - global_position).dot(global_basis.z) > 0.0


## Takes the single tear slot for [param enemy]. True if it now holds it.
func claim_tear(enemy: EnemyBase) -> bool:
	if not _holder_valid(tearer):
		tearer = enemy
	return tearer == enemy


## Takes the single climb slot (only once the window is open).
func claim_climb(enemy: EnemyBase) -> bool:
	if not is_open():
		return false
	if not _holder_valid(climber):
		climber = enemy
	return climber == enemy


## Frees whatever slots [param enemy] holds (it climbed in, died or left).
func release(enemy: EnemyBase) -> void:
	if tearer == enemy:
		tearer = null
	if climber == enemy:
		climber = null


## One plank off (authority; only the tearer). Returns false if nothing changed.
func tear(enemy: EnemyBase) -> bool:
	if not Net.is_authority() or is_open() or tearer != enemy:
		return false
	_set_planks(planks - 1)
	return true


## One plank back for [param player], who earns the repair points (authority).
## The Interactable calls this; it is disabled while full or while an enemy climbs.
func repair(player: Player) -> bool:
	if not Net.is_authority() or not can_repair(player):
		return false
	_set_planks(planks + 1)
	if player != null:
		player.points.award(PointRules.repair_points(data.repair_points), &"repair")
	return true


func can_repair(player: Player) -> bool:
	if is_full() or _holder_valid(climber):
		return false
	return player == null or is_inside(player.global_position)


func _configure(player: Player) -> void:
	interactable.prompt = "Repair barricade"
	interactable.cost = -1
	interactable.enabled = can_repair(player)
	if is_full():
		interactable.disabled_text = "Intact"
	elif _holder_valid(climber):
		interactable.disabled_text = "Blocked"
	else:
		interactable.disabled_text = "Unreachable"


func _set_planks(value: int) -> void:
	planks = clampi(value, 0, data.plank_count)
	_refresh()
	planks_changed.emit(planks)
	Events.barricade_changed.emit(barricade_id, planks)


## Shows the first [member planks] plank meshes.
func _refresh() -> void:
	if _planks_root == null:
		return
	var index := 0
	for child in _planks_root.get_children():
		(child as Node3D).visible = index < planks
		index += 1


static func _holder_valid(enemy: EnemyBase) -> bool:
	return enemy != null and is_instance_valid(enemy) and not enemy.is_dead()
