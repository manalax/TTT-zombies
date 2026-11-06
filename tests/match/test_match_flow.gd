extends GdUnitTestSuite
## F002: reference match-flow machine wiring and allow-lists (DESIGN §4.1).

const MATCH_FLOW_SCENE := "res://src/match/match_flow.tscn"


func _build() -> MatchFlow:
	var packed: PackedScene = load(MATCH_FLOW_SCENE)
	var flow: MatchFlow = auto_free(packed.instantiate())
	add_child(flow)
	return flow


func test_starts_in_lobby() -> void:
	var flow := _build()
	assert_str(flow.get_active_path()).is_equal("Lobby")


func test_full_happy_path() -> void:
	var flow := _build()
	for target: StringName in [&"Loading", &"InMatch"]:
		assert_bool(flow.transition_to(target)).is_true()
	assert_str(flow.get_active_path()).is_equal("InMatch/Intermission")
	for target: StringName in [&"WaveActive", &"Intermission", &"WaveActive", &"Victory"]:
		assert_bool(flow.transition_to(target)).is_true()
	for target: StringName in [&"Results", &"Lobby"]:
		assert_bool(flow.transition_to(target)).is_true()
	assert_str(flow.get_active_path()).is_equal("Lobby")


func test_illegal_transition_rejected() -> void:
	var flow := _build()
	assert_bool(flow.transition_to(&"Victory")).is_false()
	assert_str(flow.get_active_path()).is_equal("Lobby")


func test_defeat_allowed_from_wave_via_in_match() -> void:
	var flow := _build()
	flow.transition_to(&"Loading")
	flow.transition_to(&"InMatch")
	flow.transition_to(&"WaveActive")
	assert_bool(flow.transition_to(&"Lobby")).is_false()
	assert_bool(flow.transition_to(&"Defeat")).is_true()
	assert_str(flow.get_active_path()).is_equal("Defeat")


func test_emits_match_state_changed_with_leaf_names() -> void:
	var flow := _build()
	var changes: Array = []
	var record := func(from: StringName, to: StringName) -> void: changes.append([from, to])
	Events.match_state_changed.connect(record)
	flow.transition_to(&"Loading")
	flow.transition_to(&"InMatch")
	Events.match_state_changed.disconnect(record)
	assert_array(changes).contains_exactly([[&"Lobby", &"Loading"], [&"Loading", &"Intermission"]])
