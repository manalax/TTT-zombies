extends Node
## Top-level game flow: scene changes between menu, lobby and match (DESIGN §4.1).
##
## Match logic itself lives in src/match/ (MatchManager); this autoload only routes. The entry
## node (src/main/main.gd) registers itself as [member main] and does the swapping (F056).

const TEST_ARENA := "res://maps/dev/sandbox_arena/sandbox_arena.tscn"
## The level behind "Play" (F057). Empty = Play is disabled ("Coming soon").
const PLAY_LEVEL := "res://maps/dev/test_level/test_level.tscn"

## The entry node: has show_menu() and start_level(path).
var main: Node
## Path of the level currently loaded ("" at the menu).
var current_level_path: String = ""
## True while a menu covers gameplay (the pause menu): the local input source sends nothing.
var gameplay_input_blocked: bool = false
## What quit() does. Tests swap it for a recorder.
var quit_handler: Callable = _default_quit


func go_to_menu() -> void:
	if main != null and is_instance_valid(main):
		main.call_deferred(&"show_menu")


func load_level(path: String) -> void:
	if path == "":
		push_warning("Game.load_level: no level path.")
		return
	if main != null and is_instance_valid(main):
		main.call_deferred(&"start_level", path)


## Reloads the current level (F5). Returns false when no level is loaded.
func reload_level() -> bool:
	if current_level_path == "":
		return false
	load_level(current_level_path)
	return true


func quit() -> void:
	quit_handler.call()


func _default_quit() -> void:
	get_tree().quit()
