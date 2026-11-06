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

@export_group("Economy & Director")
@export_range(0, 5000, 5) var kill_bonus_points: int = 60
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
	report.check_min(source, "kill_bonus_points", kill_bonus_points, 0)
	report.check_min(source, "budget_cost", budget_cost, 0)
	if player_controllable and category == Category.COMMON:
		report.warn(source, "player_controllable", "common enemies are not player-controlled")
	if parryable and category == Category.BOSS:
		report.warn(source, "parryable", "boss attacks should be dodged, not parried (§6.3)")
