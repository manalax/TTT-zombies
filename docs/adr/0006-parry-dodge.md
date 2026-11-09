# ADR 0006 — Parry, Riposte & Dodge

- **Status:** Accepted (F013, 2026-11-09)
- **Code:**
  - `src/combat/block_state.gd` (parry timing);
  - `src/combat/health_component.gd` (stun, riposte owner, i-frames, `tick`);
  - `src/combat/damage_pipeline.gd` (dodge / riposte / parry stages);
  - `src/autoload/combat.gd` (commit);
  - `src/player/movement/states/dodge.gd`;
  - `src/combat/melee/states/{blocking,staggered}.gd`.
- **Tests:**
  - `tests/combat/test_parry_window.gd` and `test_parry_ac.gd` (the AC);
  - `tests/player/test_dodge.gd`;
  - extensions in `test_damage_pipeline.gd`, `test_combat_service.gd`, `test_melee_weapon.gd`.

## Context
DESIGN §6.3 asks for three mechanics:
- a block pressed within the parry window (200 ms) stuns the attacker and opens a riposte;
- some attacks must be dodged rather than parried;
- dodge is a stamina-costed i-frame sidestep.

**AC:** the parry window is correct to ±1 frame, and the riposte bonus is applied.

## Decisions

### Parry window: fresh press, tick-counted, with a lockout
- Only a **fresh block press** opens a window. The weapon derives `block_pressed` from the intent, and `Blocking._enter` calls `BlockState.open_parry_window()`. A block that's already held (through a stagger or recovery) never opens one.
- **Timing:** `BlockState.since_press` advances only through `tick(delta)`, which the weapon calls once per physics step before its machine.
  - A hit arriving N ticks after the press sees `N × delta`, and parries while that is ≤ `parry_window_s` (+ε).
  - At 60 Hz, 0.2 s gives ticks 0–12 parry and tick 13 doesn't.
  - Wall-clock time is never used, so the result is deterministic and identical when the host simulates clients (F032).
- **Lockout:** if the window ends without a parry (expiry or release), `parry_lockout_s` (0.5 s) blocks the next window. Mashing RMB only blocks. A successful parry doesn't lock out.

### Parry effect: negate and stun
- **Pipeline stage 8** (immediately before block): a parryable MELEE hit from an attacker inside the block arc during an open window → `parried`, the amount becomes 0, and the block stage is skipped (no stamina).
- **Commit:**
  - `source.stun(block.parry_stun_s, parrier)` (the parrier's weapon: sword 1.2 s, greatsword 1.4 s);
  - the parrier's `notify_parried()`;
  - `damage_applied` still fires (`applied` = 0, `parried` flag) for F016/F042.
- **Stun reactions:** players route `HealthComponent.stunned` to the weapon's `Staggered` state for that duration, interrupting any swing. Dummies and AI cancel their attack. The stun is also the riposte window.

### Riposte: the parrier's next melee hit
- **Pipeline stage 5** (after zone): if the target is stunned and `target.riposte_by == event.source` and the type is MELEE, then × `event.riposte_mult` (the attacker's `MeleeStats.riposte_mult`, carried by `SwingSpec` → `MeleeSweep`).
- A riposte **ignores block**. Armour still applies.
- **Consumed** on commit (`clear_riposte()`). Teammates get no bonus.
- `DamageResult.riposte` is flagged, so F016 can add a points bonus.

### Dodge: a movement state with attack-only i-frames
- **`Grounded/Dodge`** is entered on `intent.dodge_pressed` (Alt). It requires:
  - no cooldown;
  - stamina > 0;
  - the weapon not in Windup/Active;
  - headroom.
- **The dash:**
  - it pays `dodge_stamina_cost` and grants `dodge_iframe_s` of i-frames;
  - it dashes along the move input, or backsteps without input, for `dodge_distance_m` over `dodge_duration_s`, steered through `Player.set_wish_override()`;
  - on exit it sheds the dash speed (down to walk speed) and starts the cooldown.
- **Weapon interaction:** a dodge cancels Blocking and Recovery, and no block or attack starts during it.
- **I-frames (pipeline stage 3)** reject MELEE/BULLET/BLAST with `reject_reason = dodged`. FALL, ENVIRONMENT and DEBUG still apply.
- **Timers:** stun and i-frame timers live in `HealthComponent.tick()`, called by the owner each physics step. They snap float residue below 1e-6 to zero, so 0.2 s is exactly 12 ticks.

### Unparryable attacks
`DamageEvent.unparryable` skips **both parry and block**, so the attack must be dodged. The sparring dummy option `spar_unparryable` shows a purple telegraph. F015/F062 will map `EnemyData.parryable = false` to this flag.

## Consequences
- **New pipeline order:** validate → gate → **dodge** → zone → **riposte** → match → relation → **parry** → block → armour → clamp (ADR 0004).
- **AI melee (F015)** must call `HealthComponent.tick()` and react to `stunned`. Its swings are parryable unless the enemy data says otherwise.
- **Network (F032):** clients send intents; the host evaluates windows on its own ticks. Latency compensation for parry timing is out of scope for v1.
