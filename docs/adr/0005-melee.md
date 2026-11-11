# ADR 0005 — Melee v1

- **Status:** Accepted (F012, 2026-11-07)
- **Code:**
  - `src/combat/melee/`: `MeleeWeapon` + `melee_weapon.tscn` + `states/`, `SwingSpec`, `MeleeSweep`, `MeleeDebugDraw`;
  - `src/combat/poise_component.gd`;
  - `src/player/viewmodel/melee_viewmodel.gd`;
  - `src/world/dev/training_dummy.gd` (sparring mode).
- **Tests:**
  - `tests/combat/test_swing_spec.gd`, `test_poise_component.gd`, `test_melee_sweep.gd`;
  - `tests/combat/test_melee_ac.gd`: the AC (kill a dummy with a sword; guard break both ways);
  - `tests/player/test_melee_weapon.gd`.

## Context
Melee is the core of the game (DESIGN §6.3): light/heavy attacks, blocking with stamina, guard breaks, and F013 parry/dodge/riposte later. It has to be data-driven (`MeleeStats`), run server-side later (F022), and stay readable as more rules arrive.

## Decisions

### Input: hold to charge, fire on release
- LMB press starts **Charging**. On release:
  - charge ≥ `heavy_charge_s` → **heavy** (overhead);
  - otherwise → **light** (horizontal, alternating left→right / right→left).
- Holding past full charge keeps the heavy ready; there's no auto-release.
- RMB blocks, and block wins over attack.
- The intent carries only button *state* (`attack_held`, `block_held`). The weapon derives the press/release edges, so network input (F021) stays state-only.

### Weapon state machine (ADR 0001, MANUAL tick)
The machine is ticked by `Player.step()` after stamina and **before movement**, so this step's speed modifiers apply immediately.

```
Ready{Idle, Charging, Blocking}   Attacking{Windup, Active, Recovery}   Staggered
```

- **Starting a swing:** it needs stamina > 0, and then pays the full cost. The cost may drive stamina to 0, which exhausts the player and makes the next block fail.
- **Feint:** block during **Windup** cancels the attack. Stamina is not refunded.
- **Recovery:** block can't cancel it. A light released within `combo_buffer_s` (0.2 s) of recovery ending chains into the next light, on the other side.
- **Guard break:**
  - `DamageResult.guard_broken` on the player sends the event `guard_broken`. The `Ready`/`Attacking` parents handle it by transitioning to `Staggered`.
  - In Staggered, the player can't attack or block for `guard_break_stagger_s`, and moves at `guard_break_move_mult`.
- **Movement coupling:** weapon states call `Player.set_combat_modifiers(speed_mult, sprint_locked)` every tick (the parent sets defaults, the leaf overrides).
  - Multipliers: block 0.6, charge 0.7, swing 0.85, guard broken 0.5 (`PlayerDefaults`). They apply on the ground only.
  - `sprint_locked` makes `MovementState.wants_sprint()` false, so Sprint drops to Walk.

### Hit detection: swept arc (`MeleeSweep`)
- The swing direction for progress `t` comes from `SwingSpec.direction_at(t)`, relative to the attacker's **eye** (physics head position + look).
  - Lights sweep ±arc/2 horizontally.
  - Heavies sweep from `−35° + arc` down to −35°, so they never strike the floor.
- **Sampling:** each physics tick, the arc travelled since the last tick is sampled every ≤ 4°. For each sample:
  1. A WORLD ray from the eye to the tip. If it hits, the blade is clipped there and the swing **clangs**: the sweep ends and recovery gets `clang_recovery_s` added.
  2. A capsule (radius 0.1) along the clipped blade is tested against HURTBOXES. Hits are grouped by `HealthComponent`, a weak point is preferred within a sample, and each combatant is hit **at most once per swing**.
- **No target cap:** everything the arc touches is hit.
- Hits go through `Combat.apply` (MELEE, weapon `weakpoint_mult`, stagger).
- The same sweep drives the sparring dummy and, later, AI melee (F015).

### Poise
- `PoiseComponent` accumulates `DamageResult.stagger` and decays it at `decay_per_s`. Reaching `stagger_resist` emits `staggered(duration)`.
- `DamageResult.stagger` is the event's stagger reduced by the block (the same `block.reduction`), and is committed by `Combat._commit` (ADR 0004).
- Players have no poise in F012; only guard break staggers them. AI reactions (F015) hook into `staggered`.

### Feedback is local only
- The viewmodel freezes for 60 ms and the camera kicks on a hit. A clang adds a stronger kick and a spark.
- `Engine.time_scale` is **never** used: it would slow the host's whole simulation in multiplayer.
- The greybox blade draws on top of the world (`no_depth_test`), so it never clips into walls.

## F013 amendments
- The weapon event is now `&"staggered"` with `{duration}`: a guard break sends `guard_break_stagger_s`, and a parry stun sends the parrier's `parry_stun_s`.
- `Blocking` opens a parry window on a fresh press only.
- A dodge cancels Blocking and Recovery (not Windup/Active), and the weapon stays in Idle while dodging.

See [ADR 0006](0006-parry-dodge.md).

## Consequences / extension points
- **F013 parry:** a parry window in `Blocking` (from block press to `parry_window_s`), plus a pipeline stage **before block** that turns an in-window MELEE hit into a parry. Riposte is a `SwingSpec` multiplier.
- **F013 dodge:** a movement state (the i-frames set `HealthComponent.invulnerable`).
- **F014:** owns the loadout and weapon swapping, which replaces the F9 debug swap. `MeleeWeapon.equip()` is the swap point.
- **F022:** the host runs the same weapon machine on network intents, and clients only render.
- **HUD:** the temp HUD draws a charge ring around the crosshair from `get_charge_ratio()` (thick amber = heavy ready, red = no stamina; hidden for taps under 0.08 s).
- **Performance:** about 6 samples × (1 ray + 1 shape query) per attacking combatant per tick. To be profiled in F055.
