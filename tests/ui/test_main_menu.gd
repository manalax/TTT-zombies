extends GdUnitTestSuite
## F056: the placeholder main menu (Play, Test Arena, Exit), the Esc pause menu, and
## Game routing between them.

const MAIN_SCENE := preload("res://src/main/main.tscn")

var _main: Node
var _quits: int = 0
var _saved_quit: Callable


func before_test() -> void:
	_quits = 0
	_saved_quit = Game.quit_handler
	Game.quit_handler = func() -> void: _quits += 1
	_main = auto_free(MAIN_SCENE.instantiate())
	add_child(_main)
	await get_tree().process_frame


func after_test() -> void:
	Game.quit_handler = _saved_quit
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _menu() -> MainMenu:
	return _main.get_node_or_null("MainMenu") as MainMenu


func _player() -> Player:
	return get_tree().get_first_node_in_group(Player.LOCAL_GROUP) as Player


func _pause_menu() -> PauseMenu:
	return _main.get_node_or_null("Session/PauseMenu") as PauseMenu


func _enter_arena() -> void:
	_menu().arena_button.pressed.emit()
	await get_tree().process_frame
	await get_tree().physics_frame


func _press_pause() -> void:
	var event := InputEventAction.new()
	event.action = &"pause"
	event.pressed = true
	_pause_menu()._input(event)


func test_boots_into_menu() -> void:
	var menu := _menu()
	assert_object(menu).is_not_null()
	assert_object(_player()).is_null()
	assert_int(Input.mouse_mode).is_equal(Input.MOUSE_MODE_VISIBLE)
	assert_bool(menu.play_button.disabled).is_false()  # F057: the test level exists
	assert_bool(menu.play_note.visible).is_false()
	assert_bool(menu.play_button.has_focus()).is_true()
	assert_str(Game.current_level_path).is_equal("")


func test_play_loads_the_test_level_and_starts_a_match() -> void:
	_menu().play_button.pressed.emit()
	await get_tree().process_frame
	await get_tree().physics_frame
	assert_str(Game.current_level_path).is_equal(Game.PLAY_LEVEL)
	assert_object(_player()).is_not_null()
	var manager := get_tree().get_first_node_in_group(MatchManager.GROUP) as MatchManager
	assert_str(manager.phase()).is_equal("Intermission")
	assert_object(_pause_menu()).is_not_null()


func test_test_arena_loads_the_sandbox() -> void:
	await _enter_arena()
	assert_object(_menu()).is_null()
	assert_object(_player()).is_not_null()
	assert_object(_main.get_node_or_null("Session/TempHud")).is_not_null()
	assert_object(_pause_menu()).is_not_null()
	assert_str(Game.current_level_path).is_equal(Game.TEST_ARENA)


func test_pause_blocks_input_and_resume_restores_it() -> void:
	await _enter_arena()
	var pause := _pause_menu()
	assert_bool(pause.is_open).is_false()
	_press_pause()
	assert_bool(pause.is_open).is_true()
	assert_bool(Game.gameplay_input_blocked).is_true()
	assert_int(Input.mouse_mode).is_equal(Input.MOUSE_MODE_VISIBLE)
	Input.action_press(&"move_forward")
	var source := _player().get_node("LocalInputSource") as LocalInputSource
	assert_float(source.get_intent().move.length()).is_equal(0.0)
	Input.action_release(&"move_forward")
	pause.get_button("Resume").pressed.emit()
	assert_bool(pause.is_open).is_false()
	assert_bool(Game.gameplay_input_blocked).is_false()


func test_pause_main_menu_returns_to_menu() -> void:
	await _enter_arena()
	_press_pause()
	_pause_menu().get_button("Main Menu").pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_object(_menu()).is_not_null()
	assert_object(_player()).is_null()
	assert_bool(Game.gameplay_input_blocked).is_false()
	assert_str(Game.current_level_path).is_equal("")


func test_exit_from_menu_quits_at_once() -> void:
	_menu().exit_button.pressed.emit()
	assert_int(_quits).is_equal(1)


func test_exit_from_pause_asks_first() -> void:
	await _enter_arena()
	var pause := _pause_menu()
	_press_pause()
	pause.get_button("Exit").pressed.emit()
	assert_bool(pause.confirming).is_true()
	assert_int(_quits).is_equal(0)
	_press_pause()  # Esc while confirming = Cancel
	assert_bool(pause.confirming).is_false()
	assert_bool(pause.is_open).is_true()
	pause.get_button("Exit").pressed.emit()
	pause.get_button("Cancel").pressed.emit()
	assert_bool(pause.confirming).is_false()
	pause.get_button("Exit").pressed.emit()
	pause.get_button("Quit").pressed.emit()
	assert_int(_quits).is_equal(1)


func test_reload_level_reloads_the_arena() -> void:
	await _enter_arena()
	var first := _player()
	assert_bool(Game.reload_level()).is_true()
	await get_tree().process_frame
	await get_tree().physics_frame
	var second := _player()
	assert_object(second).is_not_null()
	assert_object(second).is_not_same(first)
	assert_object(_menu()).is_null()
