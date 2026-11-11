class_name EnemySpawnPoint
extends Marker3D
## Where enemies enter the map (F015 debug spawns; the F019 director will reuse it).
## Repeated spawns are spread on rings around the marker so a burst does not stack.
## A point inside a Zone is only active while that zone is unlocked (F017).
## A point in a spawn closet links its Barricade: enemies spawned there must breach it (F046).

const GROUP := &"enemy_spawn_points"
const RING_SPACING_M := 1.0
const PER_RING := 6

## The boarded window enemies spawned here must get through (empty = they spawn inside).
@export var barricade: NodePath
## Highest ring-spread slot used (0 = always the marker); keeps bursts inside a small closet.
@export_range(0, 60, 1) var max_spread_index: int = 13

var zone: Zone


func _ready() -> void:
	add_to_group(GROUP)
	zone = Zone.of(self)


func get_barricade() -> Barricade:
	return get_node_or_null(barricade) as Barricade if not barricade.is_empty() else null


## True if enemies may spawn here now: not in a zone, or in an unlocked one.
func is_active() -> bool:
	return zone == null or zone.unlocked


## Instances [param data]'s scene under [param parent] at this point. [param index] picks the
## slot in the spread pattern (0 = the marker itself).
func spawn(data: EnemyData, parent: Node, index: int = 0) -> EnemyBase:
	if data == null or data.scene == null:
		push_error("EnemySpawnPoint '%s': enemy has no scene." % name)
		return null
	var enemy := data.scene.instantiate() as EnemyBase
	if enemy == null:
		push_error("EnemySpawnPoint '%s': %s's scene is not an EnemyBase." % [name, data.id])
		return null
	enemy.data = data
	enemy.breach = get_barricade()
	parent.add_child(enemy)
	if index > max_spread_index:
		index = index % (max_spread_index + 1)
	enemy.global_position = global_position + spread_offset(index)
	enemy.rotation.y = global_rotation.y
	return enemy


static func spread_offset(index: int) -> Vector3:
	if index <= 0:
		return Vector3.ZERO
	var ring := (index - 1) / PER_RING + 1
	var slot := (index - 1) % PER_RING
	var angle := TAU * slot / PER_RING + ring * 0.5
	return Vector3(cos(angle), 0.0, sin(angle)) * ring * RING_SPACING_M
