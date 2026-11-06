class_name MatchSettings
extends GameData
## Every host-tunable rule for a match (DESIGN §9). A game mode is just a preset of this
## resource (content/match_presets/). Defaults are the Betrayal values.
##
## validate() errors only for impossible values; questionable-but-legal combinations are
## warnings shown to the host ("warn, never block").

enum Mode { BETRAYAL, VIGIL }
enum LateJoin { SPECTATOR, HUNTER }
enum TraitorCountMode { RATIO, EXACT }
enum RegenMode { NONE, BETWEEN_WAVES, ALWAYS }

const MIN_PLAYERS := 2
const MAX_PLAYERS := 8
## Below this, Betrayal plays poorly (DESIGN §0).
const RECOMMENDED_BETRAYAL_PLAYERS := 4
const MAX_LOADOUT_FIREARMS := 2
const MAX_LOADOUT_MELEE := 1

@export_group("Lobby")
@export var mode: Mode = Mode.BETRAYAL
@export_range(2, 8, 1) var max_players: int = 6
@export var is_public: bool = false
@export var allow_join_in_progress: bool = true
@export var late_join_role: LateJoin = LateJoin.SPECTATOR

@export_group("Roles")
@export var traitors_enabled: bool = true
@export var traitor_count_mode: TraitorCountMode = TraitorCountMode.RATIO
## RATIO mode: one traitor per this many players.
@export_range(2, 8, 1) var hunters_per_traitor: int = 5
## EXACT mode: number of traitors.
@export_range(1, 7, 1) var exact_traitor_count: int = 1
@export var traitors_know_each_other: bool = false
## Points for killing an exposed traitor.
@export_range(0, 10000, 50) var exposed_bounty: int = 500
## Line-of-sight radius for witnessed-aggression exposure (§5.3).
@export_range(1.0, 100.0, 0.5, "suffix:m") var witness_radius_m: float = 20.0
## Ignore the very first traitor hit for exposure (friendly-fire misfire grace).
@export var first_hit_grace: bool = false

@export_group("Rules")
@export var friendly_fire: bool = true
@export_range(0.0, 2.0, 0.05) var friendly_fire_scale: float = 1.0
@export var self_damage: bool = true
@export_range(3, 30, 1) var final_round: int = 12
@export_range(0.0, 300.0, 1.0, "suffix:s") var intermission_s: float = 30.0
@export var intermission_skip_vote: bool = true
@export_range(0.1, 5.0, 0.05) var player_health_mult: float = 1.0
@export var regen_mode: RegenMode = RegenMode.BETWEEN_WAVES
## Dead Hunters rise as specials (Betrayal).
@export var conversion_enabled: bool = true
@export_range(0.0, 120.0, 1.0, "suffix:s") var respawn_delay_cult_s: float = 15.0
## Vigil: dead Hunters respawn at the start of the next wave.
@export var coop_respawn_next_wave: bool = true
@export var downed_state: bool = false

@export_group("Economy")
@export_range(0.0, 10.0, 0.05) var points_per_damage_mult: float = 1.0
@export_range(0, 50000, 50) var starting_points: int = 500
@export_range(0.0, 10.0, 0.05) var kill_bonus_mult: float = 1.0
@export_range(0.1, 10.0, 0.05) var shop_price_mult: float = 1.0
## Scales ammo drops and ammo costs (§6.4). Lower = scarcer.
@export_range(0.25, 3.0, 0.05) var ammo_scarcity: float = 1.0
@export_range(0.0, 10.0, 0.05) var door_cost_mult: float = 1.0
@export_range(0.1, 5.0, 0.05) var loot_quality: float = 1.0
@export var allow_gifting: bool = false
## Fraction of points dropped on death.
@export_range(0.0, 1.0, 0.05) var death_point_loss: float = 0.25
@export var friendly_fire_point_penalty: bool = false

@export_group("Enemies & Waves")
@export var wave_set: WaveSet
@export_range(0.1, 10.0, 0.05) var enemy_health_mult: float = 1.0
@export_range(0.1, 10.0, 0.05) var enemy_damage_mult: float = 1.0
@export_range(0.1, 5.0, 0.05) var enemy_speed_mult: float = 1.0
@export_range(0.0, 10.0, 0.05) var special_freq_mult: float = 1.0
## -1 = use each wave's special_cap.
@export_range(-1, 32, 1) var special_cap_override: int = -1
## Enemy count multiplier indexed by living Hunter count (index 0..8).
@export var player_scale: PackedFloat32Array = PackedFloat32Array(
	[0.0, 1.0, 1.4, 1.8, 2.2, 2.6, 3.0, 3.4, 3.8]
)

@export_group("Weapons & Perks")
## Weapon ids allowed in shops and loot. Empty = all.
@export var allowed_weapons: Array[StringName] = []
## Perk ids available at altars. Empty = all.
@export var allowed_perks: Array[StringName] = []
@export_range(0, 10, 1) var max_perks: int = 4
## Weapon ids every Hunter spawns with.
@export var starting_loadout: Array[StringName] = []

@export_group("Misc")
## 0 = random seed per match.
@export var match_seed: int = 0
@export_range(0.0, 100.0, 0.5, "suffix:m") var min_spawn_distance_m: float = 15.0
@export var ambient_spawns_in_closed_zones: bool = true
@export var hud_hide_nameplates: bool = false
@export var hud_hide_minimap: bool = false


## Number of traitors for a lobby of [param players] (DESIGN §4.2). Always leaves >= 1 Hunter.
func traitor_count_for(players: int) -> int:
	if mode != Mode.BETRAYAL or not traitors_enabled or players < 2:
		return 0
	var count: int
	if traitor_count_mode == TraitorCountMode.EXACT:
		count = exact_traitor_count
	else:
		count = maxi(1, floori(float(players) / float(hunters_per_traitor)))
	return clampi(count, 0, players - 1)


func _validate(report: ValidationReport) -> void:
	_validate_ranges(report)
	_validate_combinations(report)


func _validate_ranges(report: ValidationReport) -> void:
	var s := source_label()
	report.check_range(s, "max_players", max_players, MIN_PLAYERS, MAX_PLAYERS)
	report.check_range(s, "hunters_per_traitor", hunters_per_traitor, 2, MAX_PLAYERS)
	report.check_range(s, "exact_traitor_count", exact_traitor_count, 1, MAX_PLAYERS - 1)
	report.check_min(s, "exposed_bounty", exposed_bounty, 0)
	report.check_positive(s, "witness_radius_m", witness_radius_m)
	report.check_range(s, "friendly_fire_scale", friendly_fire_scale, 0.0, 2.0)
	report.check_range(s, "final_round", final_round, 1, 30)
	report.check_min(s, "intermission_s", intermission_s, 0.0)
	report.check_positive(s, "player_health_mult", player_health_mult)
	report.check_min(s, "respawn_delay_cult_s", respawn_delay_cult_s, 0.0)
	for field: String in [
		"points_per_damage_mult", "kill_bonus_mult", "door_cost_mult", "special_freq_mult"
	]:
		report.check_min(s, field, float(get(field)), 0.0)
	for field: String in [
		"shop_price_mult",
		"loot_quality",
		"enemy_health_mult",
		"enemy_damage_mult",
		"enemy_speed_mult",
	]:
		report.check_positive(s, field, float(get(field)))
	report.check_min(s, "starting_points", starting_points, 0)
	report.check_range(s, "ammo_scarcity", ammo_scarcity, 0.25, 3.0)
	report.check_range(s, "death_point_loss", death_point_loss, 0.0, 1.0)
	report.check_min(s, "special_cap_override", special_cap_override, -1)
	report.check_min(s, "max_perks", max_perks, 0)
	report.check_min(s, "min_spawn_distance_m", min_spawn_distance_m, 0.0)
	report.check(
		player_scale.size() == MAX_PLAYERS + 1,
		s,
		"player_scale",
		"needs %d entries (index = living players 0..%d)" % [MAX_PLAYERS + 1, MAX_PLAYERS]
	)
	for value in player_scale:
		if value < 0.0:
			report.error(s, "player_scale", "entries must be >= 0")
			break
	if wave_set == null:
		report.error(s, "wave_set", "is required")
	else:
		GameData.validate_embedded(wave_set, report)


func _validate_combinations(report: ValidationReport) -> void:
	var s := source_label()
	if mode == Mode.BETRAYAL:
		if max_players < RECOMMENDED_BETRAYAL_PLAYERS:
			report.warn(
				s,
				"max_players",
				"Betrayal plays poorly below %d players" % RECOMMENDED_BETRAYAL_PLAYERS
			)
		if traitors_enabled and not friendly_fire:
			report.warn(s, "friendly_fire", "is off, so traitors cannot attack Hunters")
		if traitors_enabled and traitor_count_for(max_players) * 2 >= max_players:
			report.warn(s, "traitor_count_mode", "traitors would be half the lobby or more")
		if not traitors_enabled:
			report.warn(s, "traitors_enabled", "Betrayal without traitors plays like Vigil")
	else:
		if traitors_enabled:
			report.warn(s, "traitors_enabled", "is ignored in Vigil mode")
		if conversion_enabled:
			report.warn(s, "conversion_enabled", "is ignored in Vigil mode")
	if wave_set != null and wave_set.waves.size() < final_round:
		report.warn(
			s,
			"wave_set",
			"has %d waves but final_round is %d" % [wave_set.waves.size(), final_round]
		)


## Serializable form for lobby replication (F035). See DataSerializer.
func to_dict() -> Dictionary:
	return DataSerializer.to_dict(self)


## Returns {"resource": MatchSettings or null, "report": ValidationReport}.
static func from_dict(data: Dictionary) -> Dictionary:
	return DataSerializer.from_dict(data, &"MatchSettings")
