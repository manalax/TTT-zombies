extends GdUnitTestSuite
## F015: AITargeting picks the nearest living Hunter, with hysteresis.


func _body(at: Vector3, faction: CombatTypes.Faction = CombatTypes.Faction.HUNTER) -> Node3D:
	var body: Node3D = auto_free(Node3D.new())
	var health := HealthComponent.new()
	health.name = "HealthComponent"
	health.faction = faction
	body.add_child(health)
	add_child(body)
	body.global_position = at
	return body


func test_picks_the_nearest_valid_target() -> void:
	var near := _body(Vector3(2, 0, 0))
	var far := _body(Vector3(8, 0, 0))
	var candidates: Array[Node3D] = [far, near]
	assert_object(AITargeting.pick(Vector3.ZERO, candidates, null, 2.0)).is_same(near)


func test_excludes_cult_dead_and_missing() -> void:
	var cultist := _body(Vector3(1, 0, 0), CombatTypes.Faction.CULT)
	var dead := _body(Vector3(2, 0, 0))
	var health: HealthComponent = dead.get_node("HealthComponent")
	health.setup(1.0)
	Combat.apply(DamageEvent.world(health, 5.0, CombatTypes.DamageType.DEBUG))
	var plain: Node3D = auto_free(Node3D.new())
	add_child(plain)
	var candidates: Array[Node3D] = [cultist, dead, plain, null]
	assert_object(AITargeting.pick(Vector3.ZERO, candidates, null, 2.0)).is_null()
	assert_bool(AITargeting.is_valid_target(null)).is_false()
	assert_bool(AITargeting.is_valid_target(cultist)).is_false()
	assert_bool(AITargeting.is_valid_target(dead)).is_false()


func test_hysteresis_keeps_current_target() -> void:
	var current := _body(Vector3(5, 0, 0))
	var slightly_closer := _body(Vector3(-4, 0, 0))
	var candidates: Array[Node3D] = [current, slightly_closer]
	assert_object(AITargeting.pick(Vector3.ZERO, candidates, current, 2.0)).is_same(current)
	var much_closer := _body(Vector3(0, 0, 2))
	candidates.append(much_closer)
	assert_object(AITargeting.pick(Vector3.ZERO, candidates, current, 2.0)).is_same(much_closer)


func test_invalid_current_target_is_replaced() -> void:
	var current := _body(Vector3(1, 0, 0), CombatTypes.Faction.CULT)
	var other := _body(Vector3(9, 0, 0))
	var candidates: Array[Node3D] = [current, other]
	assert_object(AITargeting.pick(Vector3.ZERO, candidates, current, 2.0)).is_same(other)


func test_candidates_come_from_the_group() -> void:
	var body := _body(Vector3.ZERO)
	body.add_to_group(AITargeting.GROUP)
	assert_array(AITargeting.candidates(get_tree())).contains([body])
