class_name ShopStation
extends StaticBody3D
## Base for point sinks bought with the interact key (docs/adr/0011-shops-perks.md): wall-buys,
## ammo stations, perk altars. Subclasses implement [method _configure] (set the Interactable's
## prompt / cost / enabled for the viewing player) and [method _purchase] (authority: charge,
## then grant). The Interactable re-runs _configure before every use, so a stale prompt can never
## buy the wrong thing.

@onready var interactable: Interactable = $Interactable
@onready var label: Label3D = $Label


func _ready() -> void:
	collision_layer = PhysicsLayers.WORLD
	collision_mask = 0
	add_to_group(Door.NAV_BLOCKER_GROUP)  # baked as an obstacle like a closed door
	interactable.updater = _configure
	interactable.used.connect(_on_used)
	_setup()


## Called once in _ready (resolve data, set the label).
func _setup() -> void:
	pass


func _configure(_player: Player) -> void:
	pass


func _purchase(_player: Player) -> void:
	pass


## Sets the prompt for one case: enabled with [param cost], or disabled with [param reason].
func set_offer(prompt: String, cost: int, reason: String = "") -> void:
	interactable.prompt = prompt
	interactable.cost = cost
	interactable.enabled = reason == ""
	interactable.disabled_text = reason


## Spends [param price] from [param player] (authority). Returns false if not paid.
func charge(player: Player, price: int, reason: StringName) -> bool:
	return Net.is_authority() and player.points.try_spend(price, reason)


static func announce(player: Player, kind: StringName, item_id: StringName) -> void:
	Events.item_purchased.emit(player.health.peer_id, kind, item_id)


## True if [param item_id] passes a host whitelist (empty = everything allowed).
static func is_allowed(item_id: StringName, whitelist: Array[StringName]) -> bool:
	return whitelist.is_empty() or item_id in whitelist


func _on_used(player: Player) -> void:
	if Net.is_authority():
		_purchase(player)
