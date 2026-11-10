class_name CombatTypes
extends RefCounted
## Shared combat enums (docs/adr/0004-damage-pipeline.md).

## Public allegiance. Hidden traitors are HUNTER: roles live in the server's RoleService (F030).
enum Faction { HUNTER, CULT, WORLD }

enum DamageType { MELEE, BULLET, BLAST, FALL, ENVIRONMENT, DEBUG }

## How the attacker relates to the target; decides the friendly-fire rules.
enum Relation { SELF, FRIENDLY, CULT_ALLY, HOSTILE, WORLD }

## Damage types a block can reduce.
const BLOCKABLE: Array[DamageType] = [DamageType.MELEE]
## Damage types dodge i-frames negate (falls, hazards and debug damage still apply).
const DODGEABLE: Array[DamageType] = [DamageType.MELEE, DamageType.BULLET, DamageType.BLAST]


static func is_blockable(type: DamageType) -> bool:
	return type in BLOCKABLE


static func is_dodgeable(type: DamageType) -> bool:
	return type in DODGEABLE


static func type_name(type: DamageType) -> StringName:
	return StringName(String(DamageType.find_key(type)).to_lower())


static func relation_name(relation: Relation) -> StringName:
	return StringName(String(Relation.find_key(relation)).to_lower())
