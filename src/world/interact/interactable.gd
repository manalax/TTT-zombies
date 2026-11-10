class_name Interactable
extends Node
## Makes its parent collider usable with the interact key (docs/adr/0010-doors-zones.md).
## The player's look-at ray (WORLD layer, PlayerDefaults.interact_range_m) finds the collider,
## then this child. Owners connect [signal used] and keep [member prompt] / [member cost] current,
## either directly or per viewer through [member updater] (e.g. a wall-buy that sells or refills
## depending on whether that player owns the gun).

signal used(player: Player)

## Verb phrase for the HUD, e.g. "Open Annex Gate".
@export var prompt: String = "Use"
@export var enabled: bool = true
## Point price shown in the prompt and checked by [method can_use]. -1 = free.
@export var cost: int = -1
## Shown instead of the price while disabled, e.g. "Owned". Empty = just the prompt.
@export var disabled_text: String = ""

## Optional func(player: Player) -> void that sets prompt / cost / enabled / disabled_text for
## that viewer. Called before every prompt, check and use.
var updater: Callable


## The first Interactable child of [param collider], or null.
static func find_on(collider: Object) -> Interactable:
	var node := collider as Node
	if node == null:
		return null
	for child in node.get_children():
		if child is Interactable:
			return child as Interactable
	return null


func get_prompt_text(player: Player = null) -> String:
	_update(player)
	if not enabled and disabled_text != "":
		return "%s — %s" % [prompt, disabled_text]
	if cost >= 0:
		return "E: %s [%d]" % [prompt, cost]
	return "E: %s" % prompt


## Why [param player] cannot use this now: &"" if they can, else &"disabled" / &"points".
func deny_reason(player: Player) -> StringName:
	_update(player)
	if not enabled:
		return &"disabled"
	if cost > 0 and (player == null or not player.points.can_afford(cost)):
		return &"points"
	return &""


func can_use(player: Player) -> bool:
	return deny_reason(player) == &""


## Uses it if allowed. Returns the deny reason (&"" = used).
func use(player: Player) -> StringName:
	var reason := deny_reason(player)
	if reason == &"":
		used.emit(player)
	return reason


func _update(player: Player) -> void:
	if updater.is_valid() and player != null:
		updater.call(player)
