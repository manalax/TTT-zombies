class_name DebugOverlay
extends CanvasLayer
## F3 debug overlay for feel tuning and playtests. Lists FPS plus get_debug_info() from every
## node in the "debug_info" group.

const GROUP := &"debug_info"

@onready var _label: Label = $Panel/Label
@onready var _panel: Control = $Panel


func _ready() -> void:
	_panel.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_toggle"):
		_panel.visible = not _panel.visible
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _panel.visible:
		_label.text = build_text()


func build_text() -> String:
	var lines := PackedStringArray(["FPS %d" % Engine.get_frames_per_second()])
	for node in get_tree().get_nodes_in_group(GROUP):
		if not node.has_method(&"get_debug_info"):
			continue
		lines.append("[%s]" % node.name)
		var info: Dictionary = node.call(&"get_debug_info")
		for key: Variant in info:
			lines.append("  %s: %s" % [key, info[key]])
	return "\n".join(lines)
