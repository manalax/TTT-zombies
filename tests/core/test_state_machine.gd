# gdlint:disable=max-public-methods
extends GdUnitTestSuite
## F002: hierarchical StateMachine semantics (docs/adr/0001-hierarchical-state-machine.md).
## Fixture tree: Root{ A, B{ B1, B2 }, C }.

const RecordingState := preload("res://tests/core/fixtures/recording_state.gd")

var _log: Array[String] = []


func _make(state_name: String, children: Array[State] = []) -> RecordingState:
	var state := RecordingState.new()
	state.name = state_name
	state.log_ref = _log
	for child in children:
		state.add_child(child)
	return state


## Builds the fixture machine in MANUAL tick mode and adds it to the tree (which starts it).
func _build(initial: String = "", tick_mode := StateMachine.TickMode.MANUAL) -> StateMachine:
	_log.clear()
	var sm: StateMachine = auto_free(StateMachine.new())
	sm.name = "Root"
	sm.tick_mode = tick_mode
	if initial != "":
		sm.initial_state = NodePath(initial)
	sm.add_child(_make("A"))
	sm.add_child(_make("B", [_make("B1"), _make("B2")]))
	sm.add_child(_make("C"))
	add_child(sm)
	return sm


func _state(sm: StateMachine, state_name: StringName) -> RecordingState:
	return sm.get_state(state_name) as RecordingState


func test_start_enters_first_state() -> void:
	var sm := _build()
	assert_bool(sm.is_running()).is_true()
	assert_str(sm.get_active_path()).is_equal("A")
	assert_array(_log).contains_exactly(["enter:A"])


func test_start_into_compound_descends_root_first() -> void:
	var sm := _build("B")
	assert_str(sm.get_active_path()).is_equal("B/B1")
	assert_array(_log).contains_exactly(["enter:B", "enter:B1"])


func test_sibling_transition_order_and_data() -> void:
	var sm := _build()
	_log.clear()
	assert_bool(sm.transition_to(&"C", {"tag": "x"})).is_true()
	assert_array(_log).contains_exactly(["exit:A", "enter:C", "data:C:x"])
	assert_str(sm.get_active_path()).is_equal("C")


func test_transition_out_of_and_into_compound() -> void:
	var sm := _build("B")
	_log.clear()
	sm.transition_to(&"A")
	assert_array(_log).contains_exactly(["exit:B1", "exit:B", "enter:A"])
	_log.clear()
	sm.transition_to(&"B")
	assert_array(_log).contains_exactly(["exit:A", "enter:B", "enter:B1"])


func test_transition_within_compound_keeps_parent() -> void:
	var sm := _build("B")
	_log.clear()
	sm.transition_to(&"B2")
	assert_array(_log).contains_exactly(["exit:B1", "enter:B2"])
	assert_str(sm.get_active_path()).is_equal("B/B2")


func test_shallow_history() -> void:
	var sm := _build("B")
	_state(sm, &"B").remember_last_child = true
	sm.transition_to(&"B2")
	sm.transition_to(&"A")
	sm.transition_to(&"B")
	assert_str(sm.get_active_path()).is_equal("B/B2")


func test_without_history_enters_initial_child() -> void:
	var sm := _build("B")
	sm.transition_to(&"B2")
	sm.transition_to(&"A")
	sm.transition_to(&"B")
	assert_str(sm.get_active_path()).is_equal("B/B1")


func test_allow_list_rejects_illegal_transition() -> void:
	var sm := _build()
	_state(sm, &"A").allowed_transitions = [&"C"]
	var rejected: Array = []
	sm.transition_rejected.connect(
		func(from: String, target: StringName) -> void: rejected.append([from, target])
	)
	_log.clear()
	assert_bool(sm.transition_to(&"B")).is_false()
	assert_str(sm.get_active_path()).is_equal("A")
	assert_array(_log).is_empty()
	assert_array(rejected).contains_exactly([["A", &"B"]])
	assert_bool(sm.transition_to(&"C")).is_true()


func test_allow_list_is_inherited_from_ancestors() -> void:
	var sm := _build("B")
	_state(sm, &"B").allowed_transitions = [&"C"]
	_state(sm, &"B1").allowed_transitions = [&"B2"]
	assert_bool(sm.transition_to(&"A")).is_false()
	assert_bool(sm.transition_to(&"C")).is_true()  # permitted by parent B


func test_unknown_target_is_rejected() -> void:
	var sm := _build()
	assert_bool(sm.transition_to(&"Nope")).is_false()
	assert_str(sm.get_active_path()).is_equal("A")


func test_event_bubbles_to_parent() -> void:
	var sm := _build("B")
	_state(sm, &"B").consumes = [&"hit"]
	_log.clear()
	assert_bool(sm.send_event(&"hit")).is_true()
	assert_array(_log).contains_exactly(["event:B1:hit", "event:B:hit"])


func test_event_consumed_by_leaf_stops_bubbling() -> void:
	var sm := _build("B")
	_state(sm, &"B1").consumes = [&"hit"]
	_state(sm, &"B").consumes = [&"hit"]
	_log.clear()
	assert_bool(sm.send_event(&"hit")).is_true()
	assert_array(_log).contains_exactly(["event:B1:hit"])


func test_unhandled_event_returns_false() -> void:
	var sm := _build("B")
	_log.clear()
	assert_bool(sm.send_event(&"ignored")).is_false()
	assert_array(_log).contains_exactly(["event:B1:ignored", "event:B:ignored"])


func test_tick_updates_root_to_leaf() -> void:
	var sm := _build("B")
	_log.clear()
	sm.tick(0.016)
	sm.physics_tick(0.016)
	assert_array(_log).contains_exactly(["update:B", "update:B1", "physics:B", "physics:B1"])


func test_transition_during_tick_stops_old_chain() -> void:
	var sm := _build("B")
	_state(sm, &"B").transition_on_update = &"A"
	_log.clear()
	sm.tick(0.016)
	assert_array(_log).contains_exactly(["update:B", "exit:B1", "exit:B", "enter:A"])


func test_transition_during_enter_runs_to_completion() -> void:
	var sm := _build()
	_state(sm, &"C").transition_on_enter = &"A"
	_log.clear()
	assert_bool(sm.transition_to(&"C")).is_true()
	assert_array(_log).contains_exactly(["exit:A", "enter:C", "exit:C", "enter:A"])
	assert_str(sm.get_active_path()).is_equal("A")


func test_manual_mode_does_not_self_tick() -> void:
	var sm := _build()
	assert_bool(sm.is_processing()).is_false()
	_log.clear()
	await await_idle_frame()
	await await_idle_frame()
	assert_array(_log).is_empty()


func test_auto_mode_self_ticks() -> void:
	var sm := _build("", StateMachine.TickMode.AUTO)
	assert_bool(sm.is_processing()).is_true()
	_log.clear()
	await await_idle_frame()
	await await_idle_frame()
	assert_array(_log).contains(["update:A"])


func test_apply_remote_state_bypasses_allow_list() -> void:
	var sm := _build()
	_state(sm, &"A").allowed_transitions = [&"C"]
	var changes: Array = []
	sm.state_changed.connect(func(from: String, to: String) -> void: changes.append([from, to]))
	sm.apply_remote_state("B/B2")
	assert_str(sm.get_active_path()).is_equal("B/B2")
	assert_array(changes).contains_exactly([["A", "B/B2"]])


func test_apply_remote_state_rejects_bad_path() -> void:
	var sm := _build()
	sm.apply_remote_state("C/B2")
	assert_str(sm.get_active_path()).is_equal("A")


func test_is_in_state_and_active_path() -> void:
	var sm := _build("B")
	assert_bool(sm.is_in_state(&"B")).is_true()
	assert_bool(sm.is_in_state(&"B1")).is_true()
	assert_bool(sm.is_in_state(&"A")).is_false()
	assert_object(sm.get_active_leaf()).is_same(sm.get_state(&"B1"))


func test_history_is_bounded() -> void:
	var sm := _build()
	sm.history_size = 3
	for target: StringName in [&"C", &"A", &"C", &"B2"]:
		sm.transition_to(target)
	var history := sm.get_history()
	assert_int(history.size()).is_equal(3)
	assert_str(history[-1]).is_equal("C -> B/B2")


func test_external_self_transition_reenters() -> void:
	var sm := _build("B")
	_log.clear()
	sm.transition_to(&"B1")
	assert_array(_log).contains_exactly(["exit:B1", "enter:B1"])
	_log.clear()
	sm.transition_to(&"B")
	assert_array(_log).contains_exactly(["exit:B1", "exit:B", "enter:B", "enter:B1"])


func test_stop_exits_all() -> void:
	var sm := _build("B")
	_log.clear()
	sm.stop()
	assert_array(_log).contains_exactly(["exit:B1", "exit:B"])
	assert_bool(sm.is_running()).is_false()
	assert_str(sm.get_active_path()).is_equal("")
	assert_bool(sm.transition_to(&"A")).is_false()
