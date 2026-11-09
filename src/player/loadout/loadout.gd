class_name Loadout
extends Node
## The player's weapon slots (DESIGN §6.2, docs/adr/0007-firearms-loadout.md):
## [FIREARM_A, FIREARM_B, MELEE]. Owns ammo per firearm slot and the switch flow
## (holster the current weapon, wait the new weapon's draw_s, then equip it). Player.step() ticks
## this first, then only the active weapon. F018 wall-buys call replace_slot() and grant_ammo().

signal loadout_changed
signal active_changed(slot: int)

enum { FIREARM_A = 0, FIREARM_B = 1, MELEE = 2 }

const SLOT_COUNT := 3
const NONE := -1

var slots: Array[WeaponData] = [null, null, null]
## Ammo for FIREARM_A / FIREARM_B (null when the slot is empty).
var ammo: Array[AmmoState] = [null, null]
var active_slot: int = NONE
var switch_left: float = 0.0

var player: Player:
	get:
		return owner as Player


## Builds the slots from weapon ids: the first two firearms and the first melee weapon.
## Spawns with the melee slot active (melee is the core of the game), else the first firearm.
func setup(ids: Array[StringName]) -> void:
	slots = [null, null, null]
	ammo = [null, null]
	for weapon_id in ids:
		var data := ContentDB.get_item(&"WeaponData", weapon_id) as WeaponData
		if data == null:
			push_warning("Loadout: unknown weapon '%s'." % weapon_id)
			continue
		var slot := _free_slot_for(data)
		if slot == NONE:
			push_warning("Loadout: no free slot for '%s' (max 2 firearms + 1 melee)." % weapon_id)
			continue
		_put(slot, data)
	var start := MELEE if slots[MELEE] != null else first_filled_slot()
	active_slot = NONE
	if start != NONE:
		set_active_immediate(start)
	loadout_changed.emit()


func physics_tick(delta: float) -> void:
	var intent := player.intent
	if not player.is_dead():
		if intent.slot_pressed != NONE:
			request_slot(intent.slot_pressed)
		elif intent.cycle != 0:
			cycle(intent.cycle)
	if switch_left > 0.0:
		switch_left -= delta
		if switch_left <= 0.0:
			switch_left = 0.0
			_activate(active_slot)


## Starts switching to [param slot] (ignored if empty, or already the active slot).
func request_slot(slot: int) -> void:
	if slot < 0 or slot >= SLOT_COUNT or slots[slot] == null:
		return
	if slot == active_slot:
		return
	_deactivate(active_slot)
	active_slot = slot
	switch_left = slots[slot].draw_s
	active_changed.emit(slot)


## Switches to the next filled slot in [param direction] (+1 / -1), wrapping around.
func cycle(direction: int) -> void:
	var start := maxi(active_slot, 0)
	for i in range(1, SLOT_COUNT + 1):
		var slot := posmod(start + i * signi(direction), SLOT_COUNT)
		if slots[slot] != null and slot != active_slot:
			request_slot(slot)
			return


## Switches instantly (spawn, tests).
func set_active_immediate(slot: int) -> void:
	if slot < 0 or slot >= SLOT_COUNT or slots[slot] == null:
		return
	_deactivate(active_slot)
	active_slot = slot
	switch_left = 0.0
	_activate(slot)
	active_changed.emit(slot)


## Puts [param weapon] in [param slot] and returns the weapon it replaced (or null).
## Firearms go in FIREARM_A/B with a fresh AmmoState (full mag + scarcity-scaled reserve);
## melee weapons go in MELEE. Returns null without changes on a slot-kind mismatch.
func replace_slot(slot: int, weapon: WeaponData) -> WeaponData:
	if weapon == null or not _slot_accepts(slot, weapon):
		push_warning(
			"Loadout: '%s' cannot go in slot %d." % [weapon.id if weapon else &"null", slot]
		)
		return null
	var old := slots[slot]
	if slot == active_slot:
		_deactivate(slot)
	_put(slot, weapon)
	if slot == active_slot:
		switch_left = weapon.draw_s
	loadout_changed.emit()
	return old


## Grants ammo to a firearm slot through AmmoRules (scarcity) and the reserve cap.
## Returns the rounds actually added.
func grant_ammo(slot: int, raw: int, settings: MatchSettings = null) -> int:
	if slot < FIREARM_A or slot > FIREARM_B or ammo[slot] == null:
		return 0
	return ammo[slot].add_reserve(AmmoRules.grant(raw, settings))


func first_filled_slot() -> int:
	for slot in SLOT_COUNT:
		if slots[slot] != null:
			return slot
	return NONE


## Where a picked-up firearm goes: the active firearm slot, else an empty one, else FIREARM_A.
func firearm_slot_for_pickup() -> int:
	if is_firearm_slot(active_slot):
		return active_slot
	for slot in [FIREARM_A, FIREARM_B]:
		if slots[slot] == null:
			return slot
	return FIREARM_A


func active_weapon() -> WeaponData:
	return slots[active_slot] if active_slot != NONE else null


func is_switching() -> bool:
	return switch_left > 0.0


func is_melee_active() -> bool:
	return active_slot == MELEE and not is_switching()


func is_firearm_active() -> bool:
	return is_firearm_slot(active_slot) and not is_switching()


static func is_firearm_slot(slot: int) -> bool:
	return slot == FIREARM_A or slot == FIREARM_B


func describe() -> String:
	var parts := PackedStringArray()
	for slot in SLOT_COUNT:
		var data := slots[slot]
		var text := "%d:%s" % [slot + 1, data.id if data else "-"]
		if is_firearm_slot(slot) and ammo[slot] != null:
			text += " %d/%d" % [ammo[slot].mag, ammo[slot].reserve]
		if slot == active_slot:
			text = "[%s]" % text
		parts.append(text)
	var line := " ".join(parts)
	if is_switching():
		line += " (switching %.0f ms)" % (switch_left * 1000.0)
	return line


func _put(slot: int, data: WeaponData) -> void:
	slots[slot] = data
	if is_firearm_slot(slot):
		ammo[slot] = AmmoState.for_stats(data.firearm_stats).fill()


func _free_slot_for(data: WeaponData) -> int:
	if data.slot == WeaponData.Slot.MELEE:
		return MELEE if slots[MELEE] == null else NONE
	for slot in [FIREARM_A, FIREARM_B]:
		if slots[slot] == null:
			return slot
	return NONE


func _slot_accepts(slot: int, data: WeaponData) -> bool:
	if slot == MELEE:
		return data.slot == WeaponData.Slot.MELEE and data.melee_stats != null
	return is_firearm_slot(slot) and data.slot == WeaponData.Slot.FIREARM


func _activate(slot: int) -> void:
	if slot == MELEE:
		player.melee.equip(slots[MELEE])
	elif is_firearm_slot(slot):
		player.firearm.equip(slots[slot], ammo[slot])


func _deactivate(slot: int) -> void:
	if slot == MELEE:
		player.melee.holster()
	elif is_firearm_slot(slot):
		player.firearm.holster()
