extends GdUnitTestSuite
## F014: penetrating hitscan (rifle) against dummies.

const DUMMY_SCENE := preload("res://src/world/dev/training_dummy.tscn")

var _world: Node3D


func before_test() -> void:
	_world = auto_free(Node3D.new())
	add_child(_world)


func _dummy(z: float) -> TrainingDummy:
	var dummy: TrainingDummy = DUMMY_SCENE.instantiate()
	dummy.position = Vector3(0, 0, z)
	_world.add_child(dummy)
	return dummy


func _cast(max_hits: int, exclude: Array[RID] = []) -> Hitscan.Through:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space := _world.get_world_3d().direct_space_state
	return Hitscan.cast_through(space, Vector3(0, 1.2, 5), Vector3(0, 1.2, -50), exclude, max_hits)


func test_penetrates_into_second_combatant() -> void:
	var front := _dummy(0.0)
	var back := _dummy(-2.0)
	var through: Hitscan.Through = await _cast(2)
	assert_int(through.hits.size()).is_equal(2)
	assert_object(through.hits[0].hurtbox.health).is_same(front.health)
	assert_object(through.hits[1].hurtbox.health).is_same(back.health)
	assert_bool(through.blocked).is_false()


func test_stops_after_max_hits() -> void:
	_dummy(0.0)
	_dummy(-2.0)
	var through: Hitscan.Through = await _cast(1)
	assert_int(through.hits.size()).is_equal(1)


func test_each_combatant_hit_once() -> void:
	# Torso and arm boxes overlap the ray's path through one dummy: still one hit.
	_dummy(0.0)
	var through: Hitscan.Through = await _cast(3)
	assert_int(through.hits.size()).is_equal(1)
	assert_vector(through.end).is_equal(Vector3(0, 1.2, -50))


func test_wall_stops_penetration() -> void:
	_dummy(0.0)
	var behind := _dummy(-3.0)
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 4, 0.2)
	shape.shape = box
	wall.add_child(shape)
	wall.position = Vector3(0, 1, -1.5)
	_world.add_child(wall)
	var through: Hitscan.Through = await _cast(2)
	assert_int(through.hits.size()).is_equal(1)
	assert_bool(through.blocked).is_true()
	assert_float(behind.health.current_health).is_equal(200.0)


func test_excluded_shooter() -> void:
	var shooter := _dummy(0.0)
	var target := _dummy(-2.0)
	var through: Hitscan.Through = await _cast(1, Hitscan.collect_rids(shooter))
	assert_object(through.hits[0].hurtbox.health).is_same(target.health)
