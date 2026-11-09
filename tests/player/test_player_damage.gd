extends GdUnitTestSuite
## F011 integration: player health, hurtboxes and the Dead state.

const PLAYER_SCENE := preload("res://src/player/player.tscn")
const ScriptedInputSource := preload("res://tests/player/fixtures/scripted_input_source.gd")
const DT := 1.0 / 60.0

var _world: Node3D
var _input: ScriptedInputSource
var _saved_settings: MatchSettings


func before_test() -> void:
	_saved_settings = Settings.match_settings
	_world = auto_free(Node3D.new())
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
	shape.shape = box
	floor_body.position = Vector3(0, -0.5, 0)
	floor_body.add_child(shape)
	_world.add_child(floor_body)
	add_child(_world)


func after_test() -> void:
	Settings.match_settings = _saved_settings


func _spawn() -> Player:
	var player: Player = PLAYER_SCENE.instantiate()
	player.get_node("LocalInputSource").free()
	_input = ScriptedInputSource.new()
	player.add_child(_input)
	_world.add_child(player)
	player.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	for i in 10:
		player.step(DT)
	return player


func test_health_from_defaults_and_settings() -> void:
	var player: Player = await _spawn()
	assert_float(player.health.max_health).is_equal(100.0)
	assert_int(player.health.faction).is_equal(CombatTypes.Faction.HUNTER)
	assert_int(player.health.peer_id).is_equal(1)
	assert_float(player.health.block.arc_deg).is_equal(120.0)
	assert_object(player.health.block.stamina).is_same(player.stamina)
	assert_bool(player.health.block.active).is_false()


func test_player_health_mult() -> void:
	var custom := MatchSettings.new()
	custom.player_health_mult = 1.5
	Settings.match_settings = custom
	var player: Player = await _spawn()
	assert_float(player.health.max_health).is_equal(150.0)


func test_lethal_damage_enters_dead_and_ignores_input() -> void:
	var player: Player = await _spawn()
	Combat.apply(DamageEvent.world(player.health, 500, CombatTypes.DamageType.DEBUG))
	assert_bool(player.is_dead()).is_true()
	assert_str(player.get_movement_state()).is_equal("Dead")
	var start := player.global_position
	_input.hold(Vector2(0, -1), true)
	for i in 30:
		player.step(DT)
	(
		assert_float(
			Vector2(player.global_position.x - start.x, player.global_position.z - start.z).length()
		)
		. is_less(0.01)
	)
	assert_bool(player.is_crouched()).is_true()


func test_hurtboxes_follow_posture() -> void:
	var player: Player = await _spawn()
	var body_shape: CollisionShape3D = player.get_node("BodyHurtbox/CollisionShape3D")
	var head_box: Hurtbox = player.get_node("Head/HeadHurtbox")
	var standing_head := head_box.global_position.y
	# The body zone stops HEAD_ZONE_M below the top so it never shields the head.
	assert_float((body_shape.shape as CapsuleShape3D).height).is_equal_approx(1.4, 0.0001)
	_input.hold(Vector2.ZERO, false, true)
	for i in 20:
		player.step(DT)
	assert_float((body_shape.shape as CapsuleShape3D).height).is_equal_approx(0.7, 0.0001)
	assert_float(body_shape.position.y).is_equal_approx(0.35, 0.001)
	assert_float(head_box.global_position.y).is_less(standing_head - 0.5)
	assert_bool(head_box.is_weakpoint).is_true()


func test_shot_at_player_head_is_weakpoint() -> void:
	var player: Player = await _spawn()
	await get_tree().physics_frame
	var head_y := (player.get_node("Head/HeadHurtbox/CollisionShape3D") as Node3D).global_position.y
	var space := _world.get_world_3d().direct_space_state
	var hit := Hitscan.cast(space, Vector3(0, head_y, -5), Vector3(0, head_y, 5))
	assert_object(hit).is_not_null()
	assert_object(hit.hurtbox).is_not_null()
	assert_bool(hit.hurtbox.is_weakpoint).is_true()
	assert_object(hit.hurtbox.health).is_same(player.health)


func test_shot_at_player_chest_hits_body() -> void:
	var player: Player = await _spawn()
	await get_tree().physics_frame
	var space := _world.get_world_3d().direct_space_state
	var hit := Hitscan.cast(space, Vector3(0, 1.1, -5), Vector3(0, 1.1, 5))
	assert_object(hit.hurtbox).is_not_null()
	assert_str(hit.hurtbox.name).is_equal("BodyHurtbox")
	assert_bool(hit.hurtbox.is_weakpoint).is_false()
