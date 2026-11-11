class_name TempHud
extends CanvasLayer
## Placeholder HUD until F051: crosshair (gap follows the firearm's spread; a dot for melee),
## ammo / weapon readout, hit markers (white hit, yellow weak point, red kill), and the points
## balance with floating "+N" popups per award (F016), the interact prompt with a "Not enough
## points" flash, and a public feed of door openings (F017) and weapon / perk purchases (F018),
## plus the owned perks under the points, and the match: round counter, intermission countdown
## and centre banners (F019). Bottom left: points (and perks) above a health bar with
## "HP current / max", red at or below a quarter. While a melee attack charges, a ring around
## the crosshair fills clockwise; it turns thick amber once the heavy is ready (red: no stamina).

const HIT_MARKER_S := 0.15
const LOW_HEALTH_RATIO := 0.25
const HEALTH_BAR_SIZE := Vector2(220, 18)
const HEALTH_COLOR := Color(0.9, 0.9, 0.88)
const CHARGE_RING_RADIUS := 14.0
## Taps shorter than this draw no ring, so quick light attacks don't flicker it.
const CHARGE_RING_DELAY_S := 0.08
const CHARGE_TRACK_COLOR := Color(1, 1, 1, 0.25)
const CHARGE_WIDTH := 2.0
const CHARGE_READY_WIDTH := 3.5
const HOLD_BAR_STEPS := 5
const PIXELS_PER_DEGREE := 9.0
const MIN_GAP := 4.0
const POPUP_S := 0.8
const POPUP_RISE_PX := 40.0
const WEAKPOINT_COLOR := Color(1.0, 0.85, 0.2)
const DENY_COLOR := Color(1.0, 0.35, 0.3)
const DENY_FLASH_S := 1.0
const FEED_S := 4.0
const FEED_MAX := 4
const BANNER_S := 2.5

var hit_marker_left: float = 0.0
var hit_marker_color: Color = Color.WHITE

var _player: Player
var _crosshair: Control
var _label: Label
var _points_label: Label
var _health_bar: ProgressBar
var _health_fill: StyleBoxFlat
var _health_label: Label
var _popups: Control
var _prompt: Label
var _feed: VBoxContainer
var _deny_left: float = 0.0
var _round_label: Label
var _banner: Label
var _banner_left: float = 0.0


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
	_build_bottom_left()
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
	_round_label = Label.new()
	_round_label.name = "Round"
	_round_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_round_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_round_label.position.y = 16
	_round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style(_round_label, 22)
	add_child(_round_label)
	_banner = Label.new()
	_banner.name = "Banner"
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	_banner.position.y = -120
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style(_banner, 48)
	_banner.visible = false
	add_child(_banner)
	Events.round_started.connect(func(n: int) -> void: show_banner("ROUND %d" % n))
	Events.round_cleared.connect(func(_n: int) -> void: show_banner("ROUND CLEARED"))
	Events.match_ended.connect(_on_match_ended)
	Events.door_opened.connect(_on_door_opened)
	Events.item_purchased.connect(_on_item_purchased)


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
	_update_health()
	_update_popups(delta)
	_deny_left = maxf(0.0, _deny_left - delta)
	_update_prompt()
	_update_feed(delta)
	_round_label.text = round_text()
	_banner_left = maxf(0.0, _banner_left - delta)
	_banner.visible = _banner_left > 0.0
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
	if _player == null:
		return ""
	var text := "POINTS  %d" % _player.points.balance
	if _player.perks.count() > 0:
		text += "\n" + " · ".join(_player.perks.names())
	return text


## "HP  75 / 125", rounded up so only a dead player reads 0.
func health_text() -> String:
	if _player == null:
		return ""
	var health := _player.health
	return "HP  %d / %d" % [ceili(health.current_health), ceili(health.max_health)]


func health_low() -> bool:
	return _player != null and _player.health.get_ratio() <= LOW_HEALTH_RATIO


func _update_health() -> void:
	var shown := _player != null
	_health_bar.visible = shown
	_health_label.visible = shown
	if not shown:
		return
	_health_bar.max_value = _player.health.max_health
	_health_bar.value = _player.health.current_health
	var color := DENY_COLOR if health_low() else HEALTH_COLOR
	_health_fill.bg_color = color
	_health_label.text = health_text()
	_health_label.add_theme_color_override(&"font_color", color)


## Points (growing upward with perk lines) stacked above the health bar and its numbers.
func _build_bottom_left() -> void:
	var box := VBoxContainer.new()
	box.name = "BottomLeft"
	box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.position = Vector2(24, -24)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_points_label = Label.new()
	_points_label.name = "Points"
	_style(_points_label, 22)
	box.add_child(_points_label)
	var row := HBoxContainer.new()
	row.name = "Health"
	row.add_theme_constant_override(&"separation", 12)
	box.add_child(row)
	_health_bar = ProgressBar.new()
	_health_bar.name = "Bar"
	_health_bar.custom_minimum_size = HEALTH_BAR_SIZE
	_health_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_health_bar.show_percentage = false
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0, 0, 0, 0.55)
	_health_fill = StyleBoxFlat.new()
	_health_fill.bg_color = HEALTH_COLOR
	_health_bar.add_theme_stylebox_override(&"background", back)
	_health_bar.add_theme_stylebox_override(&"fill", _health_fill)
	row.add_child(_health_bar)
	_health_label = Label.new()
	_health_label.name = "Text"
	_style(_health_label, 22)
	row.add_child(_health_label)


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


## "ROUND 3 / 12", plus "Next round in 0:24" during intermission. "" outside a match.
func round_text() -> String:
	var manager := get_tree().get_first_node_in_group(MatchManager.GROUP) as MatchManager
	if manager == null:
		return ""
	match manager.phase():
		&"Intermission":
			var left := ceili(maxf(manager.phase_left, 0.0))
			var text := "Next round in %d:%02d" % [left / 60, left % 60]
			if manager.round_number > 0:
				text = "ROUND %d / %d\n%s" % [manager.round_number, manager.final_round, text]
			return text
		&"WaveActive", &"Victory", &"Defeat", &"Results":
			return "ROUND %d / %d" % [manager.round_number, manager.final_round]
	return ""


func show_banner(text: String) -> void:
	_banner.text = text
	_banner_left = BANNER_S
	_banner.visible = true


func banner_text() -> String:
	return _banner.text if _banner.visible else ""


func _on_match_ended(side: StringName) -> void:
	show_banner("VICTORY" if side == &"hunters" else "DEFEAT")


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
		_prompt.text = target.get_prompt_text(_player) + "\nNot enough points"
		_prompt.modulate = DENY_COLOR
		return
	_prompt.text = target.get_prompt_text(_player) + hold_bar(_player.get_interact_hold_ratio())
	_prompt.modulate = Color.WHITE if target.can_use(_player) else DENY_COLOR


## "  ▮▮▮▯▯" progress toward the next use of a held interactable ("" when not holding).
static func hold_bar(ratio: float) -> String:
	if ratio <= 0.0:
		return ""
	var filled := clampi(int(ratio * HOLD_BAR_STEPS), 0, HOLD_BAR_STEPS)
	return "  " + "▮".repeat(filled) + "▯".repeat(HOLD_BAR_STEPS - filled)


func _on_interact_denied(reason: StringName) -> void:
	if reason == &"points":
		_deny_left = DENY_FLASH_S


func _on_door_opened(door_id: StringName, peer_id: int) -> void:
	var data := ContentDB.get_item(&"DoorData", door_id) as DoorData
	var title := data.display_name if data != null else String(door_id)
	add_feed_line("Player %d opened the %s" % [peer_id, title])


func _on_item_purchased(peer_id: int, kind: StringName, item_id: StringName) -> void:
	match kind:
		&"weapon":
			var weapon := ContentDB.get_item(&"WeaponData", item_id) as WeaponData
			var title := weapon.display_name if weapon != null else String(item_id)
			add_feed_line("Player %d bought the %s" % [peer_id, title])
		&"perk":
			var perk := ContentDB.get_item(&"PerkData", item_id) as PerkData
			var title := perk.display_name if perk != null else String(item_id)
			add_feed_line("Player %d took the %s sacrament" % [peer_id, title])


## Adds a public feed line (top left, fades after FEED_S, at most FEED_MAX lines).
func add_feed_line(text: String) -> void:
	var line := Label.new()
	line.text = text
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


## Heavy-attack charge 0..1 for the crosshair ring, or -1 when the ring is hidden
## (not charging a melee attack, or held for less than [constant CHARGE_RING_DELAY_S]).
func charge_ring_ratio() -> float:
	if _player == null or Loadout.is_firearm_slot(_player.loadout.active_slot):
		return -1.0
	var melee := _player.melee
	if not melee.machine.is_in_state(&"Charging") or melee.charge_s < CHARGE_RING_DELAY_S:
		return -1.0
	return melee.get_charge_ratio()


## Red with no stamina (the release would fail), amber once the heavy is ready, else white.
func charge_ring_color() -> Color:
	if _player != null and _player.stamina.current <= 0.0:
		return DENY_COLOR
	return WEAKPOINT_COLOR if charge_ring_ratio() >= 1.0 else Color.WHITE


func _draw_charge_ring(center: Vector2) -> void:
	var ratio := charge_ring_ratio()
	if ratio < 0.0:
		return
	var color := charge_ring_color()
	if ratio >= 1.0:
		_crosshair.draw_arc(
			center, CHARGE_RING_RADIUS, 0.0, TAU, 48, color, CHARGE_READY_WIDTH, true
		)
		return
	_crosshair.draw_arc(
		center, CHARGE_RING_RADIUS, 0.0, TAU, 48, CHARGE_TRACK_COLOR, CHARGE_WIDTH, true
	)
	if ratio > 0.0:
		var start := -PI * 0.5
		_crosshair.draw_arc(
			center, CHARGE_RING_RADIUS, start, start + TAU * ratio, 48, color, CHARGE_WIDTH, true
		)


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
		_draw_charge_ring(center)
	if hit_marker_left > 0.0:
		for dir: Vector2 in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
			var d := dir.normalized()
			_crosshair.draw_line(center + d * 8.0, center + d * 15.0, hit_marker_color, 2.0)
