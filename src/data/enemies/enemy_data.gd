class_name EnemyData
extends GameData
## A cultist type (DESIGN §7). Specials share this class; abilities are added in F045+.

enum Category { COMMON, SPECIAL, BOSS }

@export var category: Category = Category.COMMON

@export_group("Survival")
@export_range(1, 20000, 1) var max_health: float = 100.0
## Fraction of incoming damage ignored.
@export_range(0.0, 0.95, 0.01) var armor: float = 0.0
@export_range(0.0, 20.0, 0.1, "suffix:m/s") var move_speed: float = 3.5
@export_range(0, 1000, 1) var stagger_resist: float = 0.0

@export_group("Attack")
@export_range(0, 500, 1) var attack_damage: float = 15.0
@export_range(0.1, 50.0, 0.1, "suffix:m") var attack_range_m: float = 1.6
## Telegraph before the hit lands; this is the player's parry read.
@export_range(0.0, 5.0, 0.01, "suffix:s") var attack_windup_s: float = 0.5
@export_range(0.0, 10.0, 0.05, "suffix:s") var attack_cooldown_s: float = 1.2
@export var parryable: bool = true
## Blade length of the swing (eye to tip). attack_range_m is the distance that starts a swing.
@export_range(0.1, 10.0, 0.05, "suffix:m") var attack_reach_m: float = 1.8
@export_range(10, 360, 1, "suffix:°") var attack_arc_deg: float = 90.0
## The swing's hit window; the lunge happens during it.
@export_range(0.05, 2.0, 0.01, "suffix:s") var attack_active_s: float = 0.2
## Standing still after the swing: the punish window.
@export_range(0.0, 5.0, 0.05, "suffix:s") var attack_recovery_s: float = 0.8
## Poise damage dealt to the target.
@export_range(0, 500, 1) var attack_stagger: float = 15.0
## Distance covered during the active window, in the direction locked at windup end.
@export_range(0.0, 10.0, 0.05, "suffix:m") var lunge_distance_m: float = 1.2

@export_group("Behaviour")
## How long a poise stagger interrupts this enemy.
@export_range(0.05, 5.0, 0.05, "suffix:s") var stagger_duration_s: float = 0.6
## After being damaged by a player, it targets that player for this long.
@export_range(0.0, 30.0, 0.5, "suffix:s") var aggro_memory_s: float = 4.0
## The corpse stays this long before being removed.
@export_range(0.0, 60.0, 0.5, "suffix:s") var corpse_s: float = 3.0

@export_group("Director")
## Director budget spent to spawn one of these.
@export_range(0, 100, 1) var budget_cost: int = 1
## Can be controlled by a converted player (specials).
@export var player_controllable: bool = false

@export_group("Assets")
@export var scene: PackedScene
@export var icon: Texture2D


func _validate(report: ValidationReport) -> void:
	var source := source_label()
	report.check_positive(source, "max_health", max_health)
	report.check_range(source, "armor", armor, 0.0, 0.95)
	report.check_min(source, "move_speed", move_speed, 0.0)
	report.check_min(source, "stagger_resist", stagger_resist, 0.0)
	report.check_min(source, "attack_damage", attack_damage, 0.0)
	report.check_positive(source, "attack_range_m", attack_range_m)
	report.check_min(source, "attack_windup_s", attack_windup_s, 0.0)
	report.check_min(source, "attack_cooldown_s", attack_cooldown_s, 0.0)
	report.check_positive(source, "attack_reach_m", attack_reach_m)
	report.check_range(source, "attack_arc_deg", attack_arc_deg, 10.0, 360.0)
	report.check_positive(source, "attack_active_s", attack_active_s)
	report.check_min(source, "attack_recovery_s", attack_recovery_s, 0.0)
	report.check_min(source, "attack_stagger", attack_stagger, 0.0)
	report.check_min(source, "lunge_distance_m", lunge_distance_m, 0.0)
	report.check_positive(source, "stagger_duration_s", stagger_duration_s)
	report.check_min(source, "aggro_memory_s", aggro_memory_s, 0.0)
	report.check_min(source, "corpse_s", corpse_s, 0.0)
	if attack_range_m > attack_reach_m + lunge_distance_m:
		report.warn(
			source, "attack_range_m", "starts swings it can never land (> reach + lunge distance)"
		)
	report.check_min(source, "budget_cost", budget_cost, 0)
	if player_controllable and category == Category.COMMON:
		report.warn(source, "player_controllable", "common enemies are not player-controlled")
	if parryable and category == Category.BOSS:
		report.warn(source, "parryable", "boss attacks should be dodged, not parried (§6.3)")
