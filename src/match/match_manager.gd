class_name MatchManager
extends Node
## Runs a match on the authority (DESIGN §4.1, docs/adr/0012-wave-director.md): drives the
## MatchFlow lifecycle machine, counts down intermissions, feeds a WaveDirector each wave and
## spawns its requests at active spawn points, and ends the match on Victory (final round
## cleared) or Defeat (no living Hunter). After Results the sandbox is reset to free play.
##
## Lobby is free play: start_match() (F4 in debug builds) begins round 1's intermission.

const GROUP := &"match_manager"
const FLOW_SCENE := preload("res://src/match/match_flow.tscn")
const RESULTS_S := 5.0

## Where players are revived after Results. Empty = where each player was at match start.
@export var player_spawn: NodePath
## Settings override (tests). Null = Settings.match_settings.
var settings: MatchSettings
var flow: MatchFlow
var director: WaveDirector = WaveDirector.new()
var round_number: int = 0
var final_round: int = 0
## Seconds left in the current countdown (Intermission or Results).
var phase_left: float = 0.0
## &"hunters" or &"cult" once the match has ended.
var winner: StringName = &""

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _start_transforms: Dictionary[int, Transform3D] = {}


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(&"debug_info")
	flow = FLOW_SCENE.instantiate() as MatchFlow
	add_child(flow)
	Events.enemy_killed.connect(_on_enemy_killed)


func _physics_process(delta: float) -> void:
	step(delta)


func get_settings() -> MatchSettings:
	return settings if settings != null else Settings.match_settings


## Leaf state name: &"Lobby", &"Intermission", &"WaveActive", &"Results", ...
func phase() -> StringName:
	return MatchFlow._leaf_name(flow.get_active_path())


func is_in_match() -> bool:
	return flow.is_in_state(&"InMatch")


## Starts round 1's intermission (authority, Lobby only). Returns false if it cannot start.
func start_match() -> bool:
	if not Net.is_authority() or phase() != &"Lobby":
		return false
	var s := get_settings()
	final_round = WaveRules.final_round(s)
	if final_round <= 0:
		push_warning("MatchManager: no waves to play (wave_set missing or empty).")
		return false
	if s.match_seed != 0:
		_rng.seed = s.match_seed
	else:
		_rng.randomize()
	round_number = 0
	winner = &""
	_start_transforms.clear()
	for player in _players():
		_start_transforms[player.get_instance_id()] = player.global_transform
	flow.transition_to(&"Loading")
	flow.transition_to(&"InMatch")
	_begin_intermission()
	return true


## One simulation step (authority). Public so tests can drive it.
func step(delta: float) -> void:
	if not Net.is_authority():
		return
	match phase():
		&"Intermission":
			if _living_hunters().is_empty():
				_end(&"cult")
				return
			phase_left -= delta
			if phase_left <= 0.0:
				_begin_wave()
		&"WaveActive":
			if _living_hunters().is_empty():
				_end(&"cult")
				return
			for enemy in director.step(delta):
				_spawn(enemy)
			if director.is_cleared():
				Events.round_cleared.emit(round_number)
				if round_number >= final_round:
					_end(&"hunters")
				else:
					_begin_intermission()
		&"Results":
			phase_left -= delta
			if phase_left <= 0.0:
				_reset_sandbox()
				flow.transition_to(&"Lobby")


func get_debug_info() -> Dictionary:
	var info := {"phase": phase()}
	if is_in_match() or phase() == &"Results":
		info["round"] = "%d / %d" % [round_number, final_round]
	if phase() == &"Intermission" or phase() == &"Results":
		info["countdown"] = "%.1f s" % phase_left
	if phase() == &"WaveActive":
		info["wave"] = (
			"alive %d (budget %d / %d), to spawn %d, kills %d"
			% [
				director.alive_count(),
				director.alive_budget(),
				director.wave.budget_points,
				director.remaining_to_spawn(),
				director.kills,
			]
		)
	return info


func _begin_intermission() -> void:
	if phase() != &"Intermission":
		flow.transition_to(&"Intermission")
	phase_left = get_settings().intermission_s
	Events.intermission_started.emit(round_number + 1, phase_left)


func _begin_wave() -> void:
	round_number += 1
	var s := get_settings()
	director.start(s.wave_set.waves[round_number - 1], s, _living_hunters().size(), _rng)
	flow.transition_to(&"WaveActive")
	Events.round_started.emit(round_number)


func _spawn(enemy: EnemyData) -> void:
	var registry := _registry()
	if registry == null:
		return
	var positions: Array[Vector3] = []
	for hunter in _living_hunters():
		positions.append(hunter.global_position)
	var point := WaveRules.pick_spawn_point(
		registry.active_spawn_points(), positions, get_settings().min_spawn_distance_m, _rng
	)
	var spawned := registry.spawn_one(enemy, point)
	if spawned != null:
		director.notify_spawned(spawned.net_id, enemy)


func _end(side: StringName) -> void:
	winner = side
	flow.transition_to(&"Victory" if side == &"hunters" else &"Defeat")
	Events.match_ended.emit(side)
	flow.transition_to(&"Results")
	phase_left = RESULTS_S


## Back to free play: enemies removed, players revived (doors and perks are kept).
func _reset_sandbox() -> void:
	var registry := _registry()
	if registry != null:
		registry.clear()
	var marker := get_node_or_null(player_spawn) as Node3D
	for player in _players():
		var at := player.global_transform
		if marker != null:
			at = marker.global_transform
		elif _start_transforms.has(player.get_instance_id()):
			at = _start_transforms[player.get_instance_id()]
		player.respawn(at)


func _on_enemy_killed(net_id: int, _killer_id: int) -> void:
	director.notify_died(net_id)


func _registry() -> EnemyRegistry:
	return get_tree().get_first_node_in_group(EnemyRegistry.GROUP) as EnemyRegistry


func _players() -> Array[Player]:
	var result: Array[Player] = []
	for node in AITargeting.candidates(get_tree()):
		if node is Player:
			result.append(node as Player)
	return result


func _living_hunters() -> Array[Player]:
	var result: Array[Player] = []
	for player in _players():
		if AITargeting.is_valid_target(player):
			result.append(player)
	return result
