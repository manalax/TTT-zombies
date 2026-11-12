extends Node
## Entry scene (F056): shows the placeholder main menu, and swaps between it and a level
## session (the level plus the HUD, debug overlay, pause menu and debug tools). Routing calls go
## through the Game autoload; this node only builds and frees what is on screen.

const MENU_SCENE := "res://src/ui/menu/main_menu.tscn"
const OVERLAY_SCENE := "res://src/ui/debug/debug_overlay.tscn"

## The current screen: a MainMenu, or a "Session" node holding the level and its UI.
var current: Node


func _ready() -> void:
	var version: String = Engine.get_version_info()["string"]
	print("Vigil of Ash running on Godot %s." % version)
	Game.main = self
	show_menu()


func _exit_tree() -> void:
	if Game.main == self:
		Game.main = null
		Game.current_level_path = ""
		Game.gameplay_input_blocked = false


func show_menu() -> void:
	_clear()
	Game.current_level_path = ""
	Game.gameplay_input_blocked = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	current = (load(MENU_SCENE) as PackedScene).instantiate()
	add_child(current)


func start_level(path: String) -> void:
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("Main: level '%s' not found." % path)
		return
	_clear()
	Game.current_level_path = path
	Game.gameplay_input_blocked = false
	var session := Node.new()
	session.name = "Session"
	current = session
	add_child(session)
	session.add_child(packed.instantiate())
	session.add_child((load(OVERLAY_SCENE) as PackedScene).instantiate())
	_add(session, TempHud.new(), "TempHud")
	_add(session, TracerDraw.new(), "TracerDraw")
	_add(session, PauseMenu.new(), "PauseMenu")
	if OS.is_debug_build():
		_add(session, DebugActions.new(), "DebugActions")
		_add(session, MeleeDebugDraw.new(), "MeleeDebugDraw")


func _add(parent: Node, node: Node, node_name: String) -> void:
	node.name = node_name
	parent.add_child(node)


## Frees the current screen right away (out of the tree first, so its groups are gone).
func _clear() -> void:
	if current != null and is_instance_valid(current):
		remove_child(current)
		current.queue_free()
	current = null
