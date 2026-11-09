class_name EnemySpawnPoint
extends Marker3D
## Where enemies enter the map (F015 debug spawns; the F019 director will reuse it).
## Repeated spawns are spread on rings around the marker so a burst does not stack.
## A point inside a Zone is only active while that zone is unlocked (F017).

const GROUP := &"enemy_spawn_points"
const RING_SPACING_M := 1.0
const PER_RING := 6

var zone: Zone


func _ready() -> void:
	add_to_group(GROUP)
	zone = Zone.of(self)


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
	parent.add_child(enemy)
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
