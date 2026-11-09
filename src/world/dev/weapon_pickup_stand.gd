class_name WeaponPickupStand
extends StaticBody3D
## Dev pickup (until wall-buys in F018): interact (E) to swap the stand's firearm into your
## active firearm slot (or an empty / the first one if melee is out). Your old gun goes on the
## stand. A fresh pickup comes with a full magazine and a scarcity-scaled reserve.

@export var weapon_id: StringName = &"rifle"

var weapon: WeaponData

@onready var _label: Label3D = $Label
@onready var _interactable: Interactable = $Interactable


func _ready() -> void:
	collision_layer = PhysicsLayers.WORLD
	weapon = ContentDB.get_item(&"WeaponData", weapon_id) as WeaponData
	_interactable.used.connect(interact)
	_refresh()


func interact(player: Player) -> void:
	if weapon == null:
		return
	var loadout := player.loadout
	var slot := loadout.firearm_slot_for_pickup()
	var old := loadout.replace_slot(slot, weapon)
	if loadout.active_slot != slot:
		loadout.request_slot(slot)
	weapon = old
	_refresh()


func _refresh() -> void:
	_interactable.enabled = weapon != null
	_interactable.prompt = "Take %s" % weapon.display_name if weapon != null else "Empty"
	_label.text = weapon.display_name if weapon != null else "(empty)"
