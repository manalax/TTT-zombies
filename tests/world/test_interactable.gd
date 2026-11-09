extends GdUnitTestSuite
## F017: the Interactable component (prompt, cost, deny reasons).

const World := preload("res://tests/enemies/enemy_test_world.gd")

var _player: Player
var _body: StaticBody3D
var _item: Interactable


func before_test() -> void:
	var world: Node3D = auto_free(World.world(10.0))
	add_child(world)
	_player = World.player(world, Vector3.ZERO)
	_player.set_physics_process(false)
	_body = StaticBody3D.new()
	_item = Interactable.new()
	_item.prompt = "Ring the Bell"
	_body.add_child(_item)
	world.add_child(_body)


func test_prompt_text() -> void:
	assert_str(_item.get_prompt_text()).is_equal("E: Ring the Bell")
	_item.cost = 500
	assert_str(_item.get_prompt_text()).is_equal("E: Ring the Bell [500]")
	_item.cost = 0
	assert_str(_item.get_prompt_text()).is_equal("E: Ring the Bell [0]")


func test_cost_and_enabled_gate_use() -> void:
	var uses: Array[Player] = []
	_item.used.connect(func(p: Player) -> void: uses.append(p))
	_player.points.reset(400)
	_item.cost = 500
	assert_str(String(_item.use(_player))).is_equal("points")
	_item.cost = 400
	assert_bool(_item.can_use(_player)).is_true()
	assert_str(String(_item.use(_player))).is_equal("")
	_item.enabled = false
	assert_str(String(_item.use(_player))).is_equal("disabled")
	assert_int(uses.size()).is_equal(1)
	assert_int(_player.points.balance).is_equal(400)  # the owner decides whether to charge


func test_find_on() -> void:
	assert_object(Interactable.find_on(_body)).is_same(_item)
	assert_object(Interactable.find_on(_player)).is_null()
	assert_object(Interactable.find_on(null)).is_null()
