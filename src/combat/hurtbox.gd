class_name Hurtbox
extends Area3D
## A damageable zone of a combatant. Attacks (hitscan rays, melee shape casts) hit hurtboxes on
## the HURTBOXES layer and turn them into DamageEvents for the owning HealthComponent.

@export var health: HealthComponent
## Zone multiplier, e.g. 0.75 for limbs.
@export_range(0.0, 5.0, 0.05) var damage_mult: float = 1.0
## Weak point (head): the weapon's weakpoint_mult applies.
@export var is_weakpoint: bool = false


func _ready() -> void:
	collision_layer = PhysicsLayers.HURTBOXES
	collision_mask = 0
	monitoring = false
	monitorable = true
	if health == null:
		push_warning("Hurtbox '%s' has no HealthComponent." % get_path())
