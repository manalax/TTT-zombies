extends GdUnitTestSuite
## F012: swept-arc hit detection against training dummies.

const DUMMY_SCENE := preload("res://src/world/dev/training_dummy.tscn")

var _world: Node3D
var _attacker: HealthComponent


func before_test() -> void:
	_world = auto_free(Node3D.new())
	add_child(_world)
	var body := Node3D.new()
	_attacker = HealthComponent.new()
	_attacker.faction = CombatTypes.Faction.HUNTER
	body.add_child(_attacker)
	_world.add_child(body)


func _dummy(pos: Vector3) -> TrainingDummy:
	var dummy: TrainingDummy = DUMMY_SCENE.instantiate()
	dummy.position = pos
	dummy.rotation.y = PI  # face the attacker at the origin
	_world.add_child(dummy)
	return dummy


func _wall(pos: Vector3, size: Vector3) -> StaticBody3D:
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	wall.add_child(shape)
	wall.position = pos
	_world.add_child(wall)
	return wall


func _light() -> SwingSpec:
	return SwingSpec.light(MeleeStats.new(), SwingSpec.Sweep.LEFT_TO_RIGHT, &"test_blade")


func _eye(height: float) -> Transform3D:
	return Transform3D(Basis.IDENTITY, Vector3(0, height, 0))


## Runs a whole swing in [param ticks] steps; returns every hit.
func _swing(spec: SwingSpec, eye: Transform3D, ticks: int = 8) -> MeleeSweep:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var sweep := MeleeSweep.new()
	sweep.begin(spec, _attacker, [])
	var space := _world.get_world_3d().direct_space_state
	for i in range(1, ticks + 1):
		sweep.advance(space, eye, float(i) / ticks)
	return sweep


func test_hits_dummy_in_front_once() -> void:
	var dummy := _dummy(Vector3(0, 0, -1.2))
	var sweep: MeleeSweep = await _swing(_light(), _eye(1.2), 16)
	assert_int(sweep.hit_count()).is_equal(1)
	# One hit only: the torso (35) or an arm (×0.75), whichever the blade reaches first.
	assert_float(dummy.health.current_health).is_between(200.0 - 35.0, 200.0 - 26.25)


func test_no_target_cap() -> void:
	var left := _dummy(Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(30)) * 1.3)
	var middle := _dummy(Vector3(0, 0, -1.3))
	var right := _dummy(Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(-30)) * 1.3)
	var sweep: MeleeSweep = await _swing(_light(), _eye(1.2))
	assert_int(sweep.hit_count()).is_equal(3)
	for dummy: TrainingDummy in [left, middle, right]:
		assert_float(dummy.health.current_health).is_less(200.0)


func test_misses_outside_arc_and_reach() -> void:
	var side := _dummy(Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(80)) * 1.2)
	var far := _dummy(Vector3(0, 0, -3.0))
	var sweep: MeleeSweep = await _swing(_light(), _eye(1.2))
	assert_int(sweep.hit_count()).is_equal(0)
	assert_float(side.health.current_health).is_equal(200.0)
	assert_float(far.health.current_health).is_equal(200.0)


func test_wall_clangs_and_protects_targets_behind() -> void:
	_wall(Vector3(0, 1, -0.7), Vector3(4, 3, 0.2))
	var behind := _dummy(Vector3(0, 0, -1.3))
	var sweep: MeleeSweep = await _swing(_light(), _eye(1.2))
	assert_bool(sweep.clanged).is_true()
	assert_float(behind.health.current_health).is_equal(200.0)


func test_clang_stops_the_rest_of_the_arc() -> void:
	# A pillar on the left: the left-to-right swing clangs before reaching the dummy on the right.
	_wall(Vector3(-0.8, 1, -0.6), Vector3(0.3, 3, 0.3))
	var right := _dummy(Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(-30)) * 1.3)
	var sweep: MeleeSweep = await _swing(_light(), _eye(1.2))
	assert_bool(sweep.clanged).is_true()
	assert_float(right.health.current_health).is_equal(200.0)


func test_prefers_weakpoint_within_a_sample() -> void:
	# At 1.55 m the blade touches both the torso top and the head: the head wins. A narrow arc
	# keeps the arms (which a wide sweep reaches first) out of the way.
	var dummy := _dummy(Vector3(0, 0, -1.0))
	var spec := _light()
	spec.arc_deg = 10.0
	var sweep: MeleeSweep = await _swing(spec, _eye(1.55))
	assert_int(sweep.hit_count()).is_equal(1)
	assert_float(dummy.health.current_health).is_equal_approx(200.0 - 35.0 * 1.5, 0.001)


func test_attacker_never_hits_itself() -> void:
	var dummy := _dummy(Vector3.ZERO)
	await get_tree().physics_frame
	var sweep := MeleeSweep.new()
	sweep.begin(_light(), dummy.health, [])
	var space := _world.get_world_3d().direct_space_state
	for i in range(1, 9):
		sweep.advance(space, _eye(1.2), i / 8.0)
	assert_int(sweep.hit_count()).is_equal(0)
	assert_float(dummy.health.current_health).is_equal(200.0)


func test_overhead_does_not_hit_floor() -> void:
	_wall(Vector3(0, -0.5, 0), Vector3(20, 1, 20))
	var dummy := _dummy(Vector3(0, 0, -1.2))
	var heavy := SwingSpec.heavy(MeleeStats.new())
	var sweep: MeleeSweep = await _swing(heavy, _eye(1.65))
	assert_bool(sweep.clanged).is_false()
	assert_float(dummy.health.current_health).is_less(200.0)
