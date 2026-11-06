extends GdUnitTestSuite
## F001 smoke tests: the project boots, autoloads exist, the main scene loads.

const MAIN_SCENE := "res://src/main/main.tscn"
const AUTOLOADS: Array[String] = ["Events", "ContentDB", "Net", "Settings", "Game", "Audio"]


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
	var main: Control = auto_free(packed.instantiate())
	var title: Label = main.get_node("Title")
	assert_str(title.text).contains("Vigil of Ash")
