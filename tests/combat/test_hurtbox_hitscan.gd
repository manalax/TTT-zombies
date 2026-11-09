extends GdUnitTestSuite
## F011: hitscan rays find hurtboxes on the training dummy and stop at world geometry.

const DUMMY_SCENE := preload("res://src/world/dev/training_dummy.tscn")

var _world: Node3D
var _dummy: TrainingDummy


func before_test() -> void:
	_world = auto_free(Node3D.new())
	add_child(_world)
	_dummy = DUMMY_SCENE.instantiate()
	_world.add_child(_dummy)
	await get_tree().physics_frame
	await get_tree().physics_frame


func _space() -> PhysicsDirectSpaceState3D:
	return _world.get_world_3d().direct_space_state


func _shoot_at(height: float, exclude: Array[RID] = []) -> Hitscan.Hit:
	return Hitscan.cast(_space(), Vector3(0, height, -5), Vector3(0, height, 5), exclude)


func test_head_is_weakpoint() -> void:
	var hit := _shoot_at(1.68)
	assert_object(hit).is_not_null()
	assert_object(hit.hurtbox).is_not_null()
	assert_str(hit.hurtbox.name).is_equal("Head")
	assert_bool(hit.hurtbox.is_weakpoint).is_true()
	assert_object(hit.hurtbox.health).is_same(_dummy.health)


func test_torso_and_legs() -> void:
	assert_str(_shoot_at(1.2).hurtbox.name).is_equal("Torso")
	var leg := Hitscan.cast(_space(), Vector3(0.12, 0.4, -5), Vector3(0.12, 0.4, 5))
	assert_str(leg.hurtbox.name).is_equal("LegR")
	assert_float(leg.hurtbox.damage_mult).is_equal(0.75)


func test_ray_passes_through_character_body_but_not_walls() -> void:
	# The dummy's StaticBody is on the ENEMIES layer: rays ignore it and hit hurtboxes.
	assert_object(_shoot_at(1.2).hurtbox).is_not_null()
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 4, 0.2)
	shape.shape = box
	wall.add_child(shape)
	wall.position = Vector3(0, 1, -2)
	_world.add_child(wall)
	await get_tree().physics_frame
	var hit := _shoot_at(1.2)
	assert_object(hit).is_not_null()
	assert_object(hit.hurtbox).is_null()
	assert_object(hit.collider).is_same(wall)


func test_excluded_rids_are_skipped() -> void:
	var exclude: Array[RID] = [_dummy.get_node("Head").get_rid()]
	var hit := _shoot_at(1.68, exclude)
	assert_bool(hit == null or hit.hurtbox == null or hit.hurtbox.name != "Head").is_true()


func test_collect_rids_includes_body_and_hurtboxes() -> void:
	var rids := Hitscan.collect_rids(_dummy)
	assert_int(rids.size()).is_equal(7)  # body + 6 hurtboxes


func test_dummy_takes_damage_and_labels_hit() -> void:
	var hit := _shoot_at(1.68)
	var shooter := HealthComponent.new()
	shooter.faction = CombatTypes.Faction.HUNTER
	var shooter_body: Node3D = auto_free(Node3D.new())
	shooter_body.add_child(shooter)
	_world.add_child(shooter_body)
	var event := DamageEvent.from_source(
		shooter, hit.hurtbox.health, 30, CombatTypes.DamageType.BULLET, hit.hurtbox
	)
	event.weakpoint_mult = 2.0
	var result := Combat.apply(event)
	assert_float(result.applied).is_equal(60.0)
	assert_float(_dummy.health.current_health).is_equal(140.0)
	assert_str(_dummy.last_hit).contains("weak point")


func test_armoured_dummy_halves_damage() -> void:
	var armoured: TrainingDummy = DUMMY_SCENE.instantiate()
	armoured.armor = 0.5
	_world.add_child(armoured)
	var result := Combat.apply(DamageEvent.world(armoured.health, 40))
	assert_float(result.applied).is_equal(20.0)
