class_name PauseMenu
extends CanvasLayer
## In-level Esc menu (F056): Resume / Main Menu / Exit, with an inline "Quit to desktop?"
## confirmation. The world keeps running (multiplayer later, so nothing pauses); while it is
## open the mouse is free and Game.gameplay_input_blocked stops the local player's input.

const LAYER := 10

var is_open: bool = false
var confirming: bool = false

var _panel: Control
var _buttons: VBoxContainer
var _confirm: VBoxContainer
var _resume: Button
var _menu: Button
var _exit: Button
var _quit: Button
var _cancel: Button


func _ready() -> void:
	layer = LAYER
	_panel = ColorRect.new()
	_panel.name = "Panel"
	(_panel as ColorRect).color = Color(0, 0, 0, 0.6)
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 12)
	center.add_child(column)
	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 40)
	column.add_child(title)
	_buttons = VBoxContainer.new()
	_buttons.name = "Buttons"
	_buttons.add_theme_constant_override(&"separation", 12)
	column.add_child(_buttons)
	_resume = _button(_buttons, "Resume", close)
	_menu = _button(_buttons, "Main Menu", Game.go_to_menu)
	_exit = _button(_buttons, "Exit", show_confirm)
	_confirm = VBoxContainer.new()
	_confirm.name = "Confirm"
	_confirm.add_theme_constant_override(&"separation", 12)
	column.add_child(_confirm)
	var question := Label.new()
	question.text = "Quit to desktop?"
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm.add_child(question)
	_quit = _button(_confirm, "Quit", Game.quit)
	_cancel = _button(_confirm, "Cancel", hide_confirm)
	_apply()


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"pause"):
		return
	get_viewport().set_input_as_handled()
	if not is_open:
		open()
	elif confirming:
		hide_confirm()
	else:
		close()


func open() -> void:
	is_open = true
	confirming = false
	Game.gameplay_input_blocked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_apply()
	_resume.grab_focus()


func close() -> void:
	is_open = false
	confirming = false
	Game.gameplay_input_blocked = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_apply()


func show_confirm() -> void:
	confirming = true
	_apply()
	_cancel.grab_focus()


func hide_confirm() -> void:
	confirming = false
	_apply()
	_exit.grab_focus()


func get_button(label: String) -> Button:
	for button: Button in [_resume, _menu, _exit, _quit, _cancel]:
		if button.text == label:
			return button
	return null


func _exit_tree() -> void:
	if is_open:
		Game.gameplay_input_blocked = false


func _apply() -> void:
	_panel.visible = is_open
	_buttons.visible = not confirming
	_confirm.visible = confirming


func _button(parent: Control, label: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(240, 44)
	button.add_theme_font_size_override(&"font_size", 22)
	button.pressed.connect(action)
	parent.add_child(button)
	return button
