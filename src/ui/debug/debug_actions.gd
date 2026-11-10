class_name DebugActions
extends Node
## Debug-build hotkeys for exercising systems before their real triggers exist.
## F4 start a match (waves; F019)
## F5 reload scene · F6 hurt self (25, world damage) · F7 test shot (30, hitscan from camera)
## F8 toggle melee sweep drawing · F9 cycle the equipped melee weapon.
## F10 spawn an acolyte · Shift+F10 spawn 30 · F11 remove all enemies · F12 grant 1000 points.

const HURT_SELF_AMOUNT := 25.0
const TEST_SHOT_DAMAGE := 30.0
const TEST_SHOT_WEAKPOINT_MULT := 2.0
const TEST_SHOT_RANGE_M := 100.0
const HORDE_SIZE := 30
const SPAWN_ENEMY_ID := &"acolyte"
const GRANT_POINTS := 1000


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_reload"):
		get_viewport().set_input_as_handled()
		get_tree().reload_current_scene()
	elif event.is_action_pressed(&"debug_hurt_self"):
		get_viewport().set_input_as_handled()
		hurt_self()
	elif event.is_action_pressed(&"debug_test_shot"):
		get_viewport().set_input_as_handled()
		test_shot()
	elif event.is_action_pressed(&"debug_melee_draw"):
		get_viewport().set_input_as_handled()
		MeleeDebugDraw.enabled = not MeleeDebugDraw.enabled
		print("[debug] melee sweep drawing %s" % ("on" if MeleeDebugDraw.enabled else "off"))
	elif event.is_action_pressed(&"debug_swap_melee"):
		get_viewport().set_input_as_handled()
		swap_melee()
	elif event.is_action_pressed(&"debug_spawn_horde", false, true):
		get_viewport().set_input_as_handled()
		spawn_enemies(HORDE_SIZE)
	elif event.is_action_pressed(&"debug_spawn_enemy", false, true):
		get_viewport().set_input_as_handled()
		spawn_enemies(1)
	elif event.is_action_pressed(&"debug_clear_enemies"):
		get_viewport().set_input_as_handled()
		clear_enemies()
	elif event.is_action_pressed(&"debug_start_match"):
		get_viewport().set_input_as_handled()
		start_match()
	elif event.is_action_pressed(&"debug_grant_points"):
		get_viewport().set_input_as_handled()
		grant_points(GRANT_POINTS)


func get_local_player() -> Player:
	return get_tree().get_first_node_in_group(Player.LOCAL_GROUP) as Player


func hurt_self() -> DamageResult:
	var player := get_local_player()
	if player == null:
		return null
	var event := DamageEvent.world(player.health, HURT_SELF_AMOUNT, CombatTypes.DamageType.DEBUG)
	var result := Combat.apply(event)
	print("[debug] hurt self: %s" % result.describe())
	return result


## Fires a hitscan from the local player's camera. Returns null if it hit no hurtbox.
func test_shot() -> DamageResult:
	var player := get_local_player()
	if player == null:
		return null
	var cam := player.camera
	var from := cam.global_position
	var to := from - cam.global_basis.z * TEST_SHOT_RANGE_M
	var hit := Hitscan.cast(
		player.get_world_3d().direct_space_state, from, to, Hitscan.collect_rids(player)
	)
	if hit == null or hit.hurtbox == null or hit.hurtbox.health == null:
		print("[debug] test shot: no hurtbox hit")
		return null
	var event := DamageEvent.from_source(
		player.health,
		hit.hurtbox.health,
		TEST_SHOT_DAMAGE,
		CombatTypes.DamageType.BULLET,
		hit.hurtbox
	)
	event.weakpoint_mult = TEST_SHOT_WEAKPOINT_MULT
	event.weapon_id = &"debug_test_shot"
	var result := Combat.apply(event)
	var dummy := hit.hurtbox.health.get_body() as TrainingDummy
	if dummy != null:
		dummy.show_result(result)
	print("[debug] test shot %s: %s" % [hit.hurtbox.get_path(), result.describe()])
	return result


## Equips the next MELEE weapon in ContentDB (sorted by id). Returns the new weapon.
func swap_melee() -> WeaponData:
	var player := get_local_player()
	if player == null:
		return null
	var options: Array[WeaponData] = []
	for item in ContentDB.get_all(&"WeaponData"):
		var data := item as WeaponData
		if data.slot == WeaponData.Slot.MELEE:
			options.append(data)
	if options.is_empty():
		return null
	options.sort_custom(func(a: WeaponData, b: WeaponData) -> bool: return a.id < b.id)
	var index := options.find(player.loadout.slots[Loadout.MELEE])
	var next := options[(index + 1) % options.size()]
	player.loadout.replace_slot(Loadout.MELEE, next)
	print("[debug] melee weapon: %s" % next.display_name)
	return next


## Spawns [param count] acolytes over the map's spawn points. Returns how many spawned.
func spawn_enemies(count: int) -> int:
	var registry := get_tree().get_first_node_in_group(EnemyRegistry.GROUP) as EnemyRegistry
	var data := ContentDB.get_item(&"EnemyData", SPAWN_ENEMY_ID) as EnemyData
	if registry == null or data == null:
		print("[debug] spawn: no EnemyRegistry in the map or no '%s' data" % SPAWN_ENEMY_ID)
		return 0
	var spawned := registry.spawn_many(data, count).size()
	print("[debug] spawned %d %s (%d alive)" % [spawned, data.display_name, registry.alive_count()])
	return spawned


## Removes every enemy. Returns how many were removed.
func clear_enemies() -> int:
	var registry := get_tree().get_first_node_in_group(EnemyRegistry.GROUP) as EnemyRegistry
	if registry == null:
		return 0
	var removed := registry.clear()
	print("[debug] removed %d enemies" % removed)
	return removed


## Gives the local player [param amount] points. Returns the new balance (-1 without a player).
func grant_points(amount: int) -> int:
	var player := get_local_player()
	if player == null:
		return -1
	player.points.award(amount, &"debug")
	print("[debug] +%d points (balance %d)" % [amount, player.points.balance])
	return player.points.balance


## Starts a match on the map's MatchManager (from free play). Returns true if it started.
func start_match() -> bool:
	var manager := get_tree().get_first_node_in_group(MatchManager.GROUP) as MatchManager
	if manager == null:
		print("[debug] no MatchManager in this map")
		return false
	var started := manager.start_match()
	print("[debug] match %s" % ("started" if started else "already running"))
	return started
