extends Node
## Entry scene. Until the main menu exists it boots straight into the dev sandbox arena
## (F010) with the F3 debug overlay and the F5–F9 debug actions (F011, F012).

const ARENA_SCENE := "res://maps/dev/sandbox_arena/sandbox_arena.tscn"
const OVERLAY_SCENE := "res://src/ui/debug/debug_overlay.tscn"


func _ready() -> void:
	var version: String = Engine.get_version_info()["string"]
	print("Vigil of Ash running on Godot %s; loading sandbox arena." % version)
	add_child((load(ARENA_SCENE) as PackedScene).instantiate())
	add_child((load(OVERLAY_SCENE) as PackedScene).instantiate())
	var hud := TempHud.new()
	hud.name = "TempHud"
	add_child(hud)
	var tracers := TracerDraw.new()
	tracers.name = "TracerDraw"
	add_child(tracers)
	if OS.is_debug_build():
		var actions := DebugActions.new()
		actions.name = "DebugActions"
		add_child(actions)
		var sweep_draw := MeleeDebugDraw.new()
		sweep_draw.name = "MeleeDebugDraw"
		add_child(sweep_draw)
