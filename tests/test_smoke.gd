extends GdUnitTestSuite
## Smoke tests: the project boots, autoloads exist, the main scene and sandbox arena load.

const MAIN_SCENE := "res://src/main/main.tscn"
const ARENA_SCENE := "res://maps/dev/sandbox_arena/sandbox_arena.tscn"
const AUTOLOADS: Array[String] = [
	"Events", "ContentDB", "Net", "Settings", "Combat", "Economy", "Game", "Audio"
]


func test_net_is_authority_offline() -> void:
	assert_bool(Net.is_authority()).is_true()


func test_autoloads_present() -> void:
	var root: Window = Engine.get_main_loop().root
	for autoload_name in AUTOLOADS:
		(
			assert_object(root.get_node_or_null(autoload_name))
			. override_failure_message("Missing autoload: %s" % autoload_name)
			. is_not_null()
		)


func test_main_scene_loads() -> void:
	var packed: PackedScene = load(MAIN_SCENE)
	assert_object(packed).is_not_null()
	var main: Node = auto_free(packed.instantiate())
	assert_str(main.name).is_equal("Main")


## F056: main boots into the placeholder main menu.
func test_main_boots_menu() -> void:
	var main: Node = auto_free((load(MAIN_SCENE) as PackedScene).instantiate())
	add_child(main)
	assert_object(main.get_node_or_null("MainMenu")).is_instanceof(MainMenu)


## F010: the sandbox arena (Test Arena) must contain a player.
func test_sandbox_arena_has_player() -> void:
	var packed: PackedScene = load(ARENA_SCENE)
	assert_object(packed).is_not_null()
	var arena: Node = auto_free(packed.instantiate())
	assert_object(arena.get_node_or_null("Player")).is_instanceof(Player)
