# ADR 0004 — Damage Pipeline

- **Status:** Accepted (F011, 2026-11-07)
- **Code:**
  - `src/combat/` (`DamageEvent`, `DamageResult`, `DamageRules`, `DamagePipeline`, `HealthComponent`, `Hurtbox`, `BlockState`, `Hitscan`, `CombatTypes`);
  - the `Combat` autoload (`src/autoload/combat.gd`);
  - `src/core/physics_layers.gd`.
- **Tests:** `tests/combat/`, `tests/player/test_player_damage.gd`, `tests/ui/test_debug_actions.gd`.

## Context
Every attack in the game needs consistent rules:
- player melee and guns, cult melee, special-enemy explosions;
- hazards and falls;
- friendly fire (with traitors);
- host multipliers, blocking, and armour.

Later systems react to who hurt whom: points (F016), exposure (F032), death and conversion (F034). The math has to be auditable and testable without a scene.

## Decisions

### One entry point
- **All damage goes through `Combat.apply(event: DamageEvent) -> DamageResult`.** Nothing subtracts health directly.
- `apply` does nothing (rejects with `&"not_authority"`) unless `Net.is_authority()` is true.
- **On the authority**, `apply`:
  1. builds `DamageRules` from `Settings.match_settings`;
  2. calls the pure `DamagePipeline.resolve()`;
  3. **commits** the result: drains the block stamina, then calls `HealthComponent.apply_result()`;
  4. emits `Combat.damage_applied(result)` (a server-side service signal, which may carry node refs);
  5. for players (`peer_id > 0`), also emits `Events.player_damaged` / `Events.player_died` (ids only).

### Fixed stage order
`resolve()` never changes state. It runs a fixed list of public static stages:

| # | Stage | Rule |
|---|---|---|
| 1 | validate | no target, dead target, invulnerable, or amount ≤ 0 → rejected |
| 2 | relation gate | SELF needs `self_damage`; FRIENDLY (Hunter→Hunter) needs `friendly_fire`; CULT_ALLY needs `event.hits_allies`; HOSTILE and WORLD always pass |
| 3 | dodge (F013) | target has i-frames and the type is MELEE/BULLET/BLAST → rejected `dodged` |
| 4 | zone | × `hurtbox.damage_mult`, × `weakpoint_mult` on weak points |
| 5 | riposte (F013) | the parrier's MELEE hit on the attacker they stunned × `riposte_mult` (ignores block) |
| 6 | match multipliers | × `enemy_damage_mult` for Cult→Hunter |
| 7 | relation scale | FRIENDLY × `friendly_fire_scale` (melee too); CULT_ALLY × `cult_friendly_fire_scale` |
| 8 | parry (F013) | parryable MELEE inside a fresh block's window → amount 0, `parried`; skips block |
| 9 | block | see below (unparryable attacks and ripostes skip it) |
| 10 | armour | × (1 − armor), always in full, weak points included |
| 11 | clamp | `applied = min(amount, current_health)`, plus `overkill` and `killed` |

The F013 stages are specified in [ADR 0006](0006-parry-dodge.md).

- **Why fixed stages:** a fixed order is easier to reason about than a priority-sorted modifier chain, and each stage is tested on its own (the AC).
- **Future insertions:**
  - parry (F013) goes immediately **before** block (done: stage 8);
  - perk and consumable multipliers (F053) go after match multipliers;
  - player armour (if a perk adds it) reuses stage 7.
- **Factions:** hidden traitors are HUNTER. Traitor-specific handling (F031) and exposure (F032) read `damage_applied`; they don't change this math.

### Block
A block applies only when all of these hold:
- `BlockState.active` is set;
- the damage type is blockable (**MELEE only** for now);
- the attack origin is inside the frontal arc (`PlayerDefaults.block_arc_deg`, default 120°, measured on the horizontal plane);
- the blocker has stamina > 0.

The block absorbs `amount × reduction` and costs `absorbed × stamina_per_damage`. It also reduces the stagger delivered to poise by the same factor (`DamageResult.stagger`, added in F012). `Combat._commit` passes that value to the target's `PoiseComponent`. **Guard break:** if the cost exceeds the remaining stamina, the hit is *still fully blocked*, all stamina is spent, and `guard_broken` is set. The next hit then lands in full, because stamina is 0. F012 drives `active` from input and staggers the blocker (see [ADR 0005](0005-melee.md)).

### Hurtboxes and hitscan
- Hurtboxes are `Area3D`s on the `HURTBOXES` physics layer (`PhysicsLayers`), each owned by a `HealthComponent`.
- Character bodies sit on PLAYERS or ENEMIES. Attack queries use `ATTACK_MASK = WORLD | HURTBOXES`, so walls stop shots and bodies never absorb them.
- The player's body hurtbox stops `HEAD_ZONE_M` below the top, so it never shields the head weak point.

### Points
**Only `DamageResult.applied` counts for points** (F016): no overkill, nothing for rejected hits.

## Consequences
- New damage sources build a `DamageEvent` (`from_source` or `world`) and call `Combat.apply`.
- **Clients:** they never resolve damage. F022 sends attack intents to the host and replicates the outcomes.
- **New MatchSettings rules** reach the pipeline only through `DamageRules.from_settings`.
