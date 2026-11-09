class_name Door
extends StaticBody3D
## A purchasable door between zones (DESIGN §10.2, §11, docs/adr/0010-doors-zones.md).
##
## Closed: a WORLD collider in the `nav_blockers` group, so the map's navmesh is baked with the
## doorway shut and zones are separate nav islands. Buying it (Interactable, E) spends
## PointRules.door_price(DoorData.cost); opening is permanent: the slab sinks, collision goes,
## the NavigationLink3D across the doorway is enabled, DoorData.unlocks_zone_id is unlocked and
## Events.door_opened is emitted. The local -Z/+Z sides are the two zones.

signal opened(peer_id: int)

const NAV_BLOCKER_GROUP := &"nav_blockers"
const OPEN_TWEEN_S := 0.6

## DoorData id in ContentDB.
@export var door_id: StringName = &"crypt_gate"

var data: DoorData
var is_open: bool = false

@onready var interactable: Interactable = $Interactable
@onready var link: NavigationLink3D = $NavigationLink3D
@onready var _slab: Node3D = $Slab
@onready var _shape: CollisionShape3D = $CollisionShape3D
@onready var _label: Label3D = $Label


func _ready() -> void:
	add_to_group(NAV_BLOCKER_GROUP)
	collision_layer = PhysicsLayers.WORLD
	collision_mask = 0
	data = ContentDB.get_item(&"DoorData", door_id) as DoorData
	if data == null:
		push_error("Door '%s': DoorData '%s' not found." % [name, door_id])
		data = DoorData.new()
	link.enabled = false
	interactable.used.connect(_on_used)
	refresh()


## Current price with the host's door_cost_mult.
func price() -> int:
	return PointRules.door_price(data.cost)


func title() -> String:
	return data.display_name if data.display_name != "" else String(door_id)


## Updates the prompt and label (call if MatchSettings change).
func refresh() -> void:
	var verb := data.prompt_text if data.prompt_text != "" else "Open %s" % title()
	interactable.prompt = verb
	interactable.cost = price()
	interactable.enabled = not is_open
	_label.text = "%s\n%d" % [title(), price()]
	_label.visible = not is_open


## Opens the door for good (authority). Returns false if it was already open.
func open(peer_id: int = 0) -> bool:
	if is_open or not Net.is_authority():
		return false
	is_open = true
	_shape.set_deferred(&"disabled", true)
	set_deferred(&"collision_layer", 0)
	link.enabled = true
	refresh()
	if is_inside_tree():
		var tween := create_tween()
		tween.tween_property(_slab, ^"position:y", _slab.position.y - 3.2, OPEN_TWEEN_S)
	var zone := Zone.find(get_tree(), data.unlocks_zone_id)
	if zone != null:
		zone.unlock()
	else:
		push_warning("Door '%s': zone '%s' not found." % [name, data.unlocks_zone_id])
	opened.emit(peer_id)
	Events.door_opened.emit(data.id, peer_id)
	return true


func _on_used(player: Player) -> void:
	if is_open or not Net.is_authority():
		return
	if not player.points.try_spend(price(), &"door"):
		return
	open(player.health.peer_id)
