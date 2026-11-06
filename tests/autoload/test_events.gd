extends GdUnitTestSuite
## F002: guards the Events bus signal contract (names + argument names).

const EXPECTED := {
	&"match_state_changed": ["from_state", "to_state"],
	&"intermission_started": ["round_number", "duration_s"],
	&"round_started": ["round_number"],
	&"round_cleared": ["round_number"],
	&"match_ended": ["winning_side"],
	&"player_joined": ["peer_id"],
	&"player_left": ["peer_id"],
	&"player_spawned": ["peer_id", "as_role"],
	&"player_damaged": ["peer_id", "source_id", "amount"],
	&"player_died": ["peer_id", "killer_id", "cause"],
	&"player_converted": ["peer_id", "special_id"],
	&"player_respawned": ["peer_id"],
	&"local_role_assigned": ["role"],
	&"player_exposed": ["peer_id", "reason"],
	&"enemy_spawned": ["net_id", "enemy_id"],
	&"enemy_killed": ["net_id", "killer_id"],
	&"points_changed": ["peer_id", "total", "delta"],
	&"door_opened": ["door_id", "peer_id"],
	&"zone_unlocked": ["zone_id"],
}


func _declared_signals() -> Dictionary:
	var script: Script = Events.get_script()
	var result := {}
	for info: Dictionary in script.get_script_signal_list():
		var args: Array = []
		for arg: Dictionary in info["args"]:
			args.append(arg["name"])
		result[StringName(info["name"])] = args
	return result


func test_expected_signals_declared() -> void:
	var declared := _declared_signals()
	for signal_name: StringName in EXPECTED:
		(
			assert_bool(declared.has(signal_name))
			. override_failure_message("Events is missing signal %s" % signal_name)
			. is_true()
		)
		assert_array(declared.get(signal_name, [])).is_equal(EXPECTED[signal_name])


func test_no_undocumented_signals() -> void:
	var declared := _declared_signals()
	for signal_name: StringName in declared:
		(
			assert_bool(EXPECTED.has(signal_name))
			. override_failure_message(
				"Signal %s is not covered by this test; add it to EXPECTED" % signal_name
			)
			. is_true()
		)
