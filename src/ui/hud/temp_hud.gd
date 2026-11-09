class_name TempHud
extends CanvasLayer
## Placeholder HUD until F071: crosshair (gap follows the firearm's spread; a dot for melee),
## ammo / weapon readout, hit markers (white hit, yellow weak point, red kill), and the points
## balance with floating "+N" popups per award (F016), the interact prompt with a "Not enough
## points" flash, and a public feed of door openings (F017).

const HIT_MARKER_S := 0.15
const PIXELS_PER_DEGREE := 9.0
const MIN_GAP := 4.0
const POPUP_S := 0.8
const POPUP_RISE_PX := 40.0
const WEAKPOINT_COLOR := Color(1.0, 0.85, 0.2)
const DENY_COLOR := Color(1.0, 0.35, 0.3)
const DENY_FLASH_S := 1.0
const FEED_S := 4.0
const FEED_MAX := 4

var hit_marker_left: float = 0.0
var hit_marker_color: Color = Color.WHITE

var _player: Player
var _crosshair: Control
var _label: Label
var _points_label: Label
var _popups: Control
var _prompt: Label
var _feed: VBoxContainer
var _deny_left: float = 0.0


func _ready() -> void:
	_crosshair = Control.new()
	_crosshair.name = "Crosshair"
	_crosshair.set_anchors_preset(Control.PRESET_FULL_RECT)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair.draw.connect(_draw_crosshair)
	add_child(_crosshair)
	_label = Label.new()
	_label.name = "Ammo"
	_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_label.position = Vector2(-24, -24)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.add_theme_font_size_override(&"font_size", 22)
	_label.add_theme_constant_override(&"outline_size", 6)
	_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	add_child(_label)
	_points_label = Label.new()
	_points_label.name = "Points"
	_points_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_points_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_points_label.position = Vector2(24, -24)
	_style(_points_label, 22)
	add_child(_points_label)
	_popups = Control.new()
	_popups.name = "PointPopups"
	_popups.set_anchors_preset(Control.PRESET_FULL_RECT)
	_popups.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_popups)
	_prompt = Label.new()
	_prompt.name = "Prompt"
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_prompt.position.y = -140
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style(_prompt, 22)
	add_child(_prompt)
	_feed = VBoxContainer.new()
	_feed.name = "Feed"
	_feed.position = Vector2(24, 24)
	add_child(_feed)
	Events.door_opened.connect(_on_door_opened)


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(Player.LOCAL_GROUP) as Player
		if _player != null:
			_player.firearm.shot_fired.connect(_on_shot)
			_player.melee.swing_hit.connect(_on_hits)
			_player.points.awarded.connect(show_award)
			_player.interact_denied.connect(_on_interact_denied)
	hit_marker_left = maxf(0.0, hit_marker_left - delta)
	_label.text = readout()
	_points_label.text = points_text()
	_update_popups(delta)
	_deny_left = maxf(0.0, _deny_left - delta)
	_update_prompt()
	_update_feed(delta)
	_crosshair.queue_redraw()


## "REVOLVER  4 / 12" plus RELOADING / EMPTY / SWITCHING.
func readout() -> String:
	if _player == null:
		return ""
	var loadout := _player.loadout
	var data := loadout.active_weapon()
	if data == null:
		return ""
	var text := data.display_name.to_upper()
	if loadout.is_switching():
		return text + "\nSWITCHING…"
	if Loadout.is_firearm_slot(loadout.active_slot):
		var ammo := loadout.ammo[loadout.active_slot]
		text += "  %d / %d" % [ammo.mag, ammo.reserve]
		if _player.firearm.machine.is_in_state(&"Reloading"):
			text += "\nRELOADING"
		elif ammo.mag == 0:
			text += "\nEMPTY" if ammo.reserve == 0 else "\nRELOAD"
	return text


func points_text() -> String:
	return "POINTS  %d" % _player.points.balance if _player != null else ""


## Floating "+N" above the crosshair (yellow on a weak point, "RIPOSTE" on a riposte).
func show_award(award: PointAward) -> void:
	var popup := Label.new()
	popup.text = "+%d" % award.total
	if award.riposte_bonus > 0:
		popup.text += "  RIPOSTE"
	_style(popup, 18)
	popup.modulate = WEAKPOINT_COLOR if award.weakpoint else Color.WHITE
	popup.set_meta(&"age", 0.0)
	_popups.add_child(popup)
	popup.position = _popups.size * 0.5 + Vector2(18, -30 - _popups.get_child_count() * 4)


## The interact prompt currently shown ("" if none).
func prompt_text() -> String:
	return _prompt.text if _prompt.visible else ""


func prompt_color() -> Color:
	return _prompt.modulate


func feed_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	for child in _feed.get_children():
		lines.append((child as Label).text)
	return lines


func _update_prompt() -> void:
	var target := _player.get_interact_target() if _player != null else null
	if target == null:
		_prompt.visible = _deny_left > 0.0
		return
	_prompt.visible = true
	if _deny_left > 0.0:
		_prompt.text = target.get_prompt_text() + "\nNot enough points"
		_prompt.modulate = DENY_COLOR
		return
	_prompt.text = target.get_prompt_text()
	_prompt.modulate = Color.WHITE if target.can_use(_player) else DENY_COLOR


func _on_interact_denied(reason: StringName) -> void:
	if reason == &"points":
		_deny_left = DENY_FLASH_S


func _on_door_opened(door_id: StringName, peer_id: int) -> void:
	var data := ContentDB.get_item(&"DoorData", door_id) as DoorData
	var title := data.display_name if data != null else String(door_id)
	var line := Label.new()
	line.text = "Player %d opened the %s" % [peer_id, title]
	line.set_meta(&"age", 0.0)
	_style(line, 18)
	_feed.add_child(line)
	while _feed.get_child_count() > FEED_MAX:
		var oldest := _feed.get_child(0)
		_feed.remove_child(oldest)
		oldest.queue_free()


func _update_feed(delta: float) -> void:
	for child in _feed.get_children():
		var line := child as Label
		var age: float = float(line.get_meta(&"age")) + delta
		line.set_meta(&"age", age)
		line.modulate.a = clampf((FEED_S - age) / 0.5, 0.0, 1.0)
		if age >= FEED_S:
			line.queue_free()


func popup_count() -> int:
	return _popups.get_child_count()


func _update_popups(delta: float) -> void:
	for popup in _popups.get_children():
		var label := popup as Label
		var age: float = float(label.get_meta(&"age")) + delta
		label.set_meta(&"age", age)
		label.position.y -= POPUP_RISE_PX / POPUP_S * delta
		label.modulate.a = clampf(1.0 - age / POPUP_S, 0.0, 1.0)
		if age >= POPUP_S:
			label.queue_free()


func _style(label: Label, font_size: int) -> void:
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_constant_override(&"outline_size", 6)
	label.add_theme_color_override(&"font_outline_color", Color.BLACK)


func _on_shot(results: Array[DamageResult], _tracers: Array[Vector3]) -> void:
	_on_hits(results)


func _on_hits(results: Array[DamageResult]) -> void:
	var best := -1
	for result in results:
		if not result.accepted or result.applied <= 0.0:
			continue
		var rank := 0
		if result.event.is_weakpoint():
			rank = 1
		if result.killed:
			rank = 2
		best = maxi(best, rank)
	if best < 0:
		return
	hit_marker_left = HIT_MARKER_S
	hit_marker_color = [Color.WHITE, Color(1.0, 0.85, 0.2), Color(1.0, 0.2, 0.2)][best]


func _draw_crosshair() -> void:
	if _player == null:
		return
	var center := _crosshair.size * 0.5
	var color := Color(1, 1, 1, 0.85)
	if Loadout.is_firearm_slot(_player.loadout.active_slot) and _player.firearm.is_active():
		var gap := MIN_GAP + _player.firearm.current_spread() * PIXELS_PER_DEGREE
		for dir: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			_crosshair.draw_line(center + dir * gap, center + dir * (gap + 8.0), color, 2.0)
	else:
		_crosshair.draw_circle(center, 2.0, color)
	if hit_marker_left > 0.0:
		for dir: Vector2 in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
			var d := dir.normalized()
			_crosshair.draw_line(center + d * 8.0, center + d * 15.0, hit_marker_color, 2.0)
