extends GdUnitTestSuite
## F016: the PointsComponent wallet (awards, spending, announcements).

var _wallet: PointsComponent
var _events: Array[Array] = []


func before_test() -> void:
	_wallet = auto_free(PointsComponent.new())
	add_child(_wallet)
	_wallet.peer_id = 3
	_events.clear()
	Events.points_changed.connect(_on_points_changed)


func after_test() -> void:
	Events.points_changed.disconnect(_on_points_changed)


func _on_points_changed(peer_id: int, total: int, delta: int) -> void:
	_events.append([peer_id, total, delta])


func test_reset_sets_the_starting_balance() -> void:
	_wallet.reset(500)
	assert_int(_wallet.balance).is_equal(500)
	assert_array(_events).contains_exactly([[3, 500, 500]])
	_wallet.reset(-20)
	assert_int(_wallet.balance).is_equal(0)


func test_award_rounds_up_and_announces() -> void:
	_wallet.reset(500)
	var awards: Array[PointAward] = []
	_wallet.awarded.connect(func(award: PointAward) -> void: awards.append(award))
	assert_int(_wallet.award(15, &"debug")).is_equal(20)
	assert_int(_wallet.balance).is_equal(520)
	assert_int(awards.size()).is_equal(1)
	assert_str(String(_wallet.last_award.reason)).is_equal("debug")
	assert_array(_events.back()).is_equal([3, 520, 20])


func test_empty_awards_are_ignored() -> void:
	_wallet.reset(100)
	_events.clear()
	_wallet.award_points(PointAward.new())
	_wallet.award_points(null)
	assert_int(_wallet.award(0, &"debug")).is_equal(0)
	assert_int(_wallet.balance).is_equal(100)
	assert_array(_events).is_empty()


func test_try_spend_deducts_when_affordable() -> void:
	_wallet.reset(1000)
	var spent: Array = []
	_wallet.spent.connect(func(cost: int, reason: StringName) -> void: spent.append([cost, reason]))
	assert_bool(_wallet.can_afford(750)).is_true()
	assert_bool(_wallet.try_spend(750, &"door")).is_true()
	assert_int(_wallet.balance).is_equal(250)
	assert_array(spent).contains_exactly([[750, &"door"]])
	assert_array(_events.back()).is_equal([3, 250, -750])


func test_try_spend_fails_without_change_when_short() -> void:
	_wallet.reset(500)
	_events.clear()
	assert_bool(_wallet.can_afford(501)).is_false()
	assert_bool(_wallet.try_spend(501, &"door")).is_false()
	assert_bool(_wallet.try_spend(-10, &"refund")).is_false()
	assert_int(_wallet.balance).is_equal(500)
	assert_array(_events).is_empty()
	assert_bool(_wallet.try_spend(500, &"perk")).is_true()
	assert_int(_wallet.balance).is_equal(0)
	assert_bool(_wallet.try_spend(10, &"perk")).is_false()
	assert_int(_wallet.balance).is_equal(0)


func test_free_items_are_always_affordable() -> void:
	_wallet.reset(0)
	assert_bool(_wallet.try_spend(0, &"free")).is_true()
	assert_int(_wallet.balance).is_equal(0)
