# ADR 0013 — Boarded Windows (Barricades)

- **Status:** Accepted (F046, 2026-11-11; built ahead of M2)
- **Code:**
  - `src/world/barricade/`: `Barricade` + `barricade.tscn`;
  - `src/data/world/barricade_data.gd` + `content/world/barricades/boarded_window`;
  - `src/enemies/brain/breach.gd`, `climb.gd`; `EnemyBase.breach` / `walk_to` / `lunge_scale`;
  - `EnemySpawnPoint.barricade` / `max_spread_index`;
  - `PhysicsLayers.BARRIER` / `INTERACT_MASK`;
  - hold-to-use: `Interactable.hold_interval_s`, `MoveIntent.interact_held`, `Player.get_interact_hold_ratio()`;
  - `PointRules.repair_points`, `Events.barricade_changed`, `EnemyData.barricade_tear_s`;
  - the sandbox windows and closets.
- **Tests:**
  - `tests/world/test_barricade.gd` (the AC);
  - arena coverage in `test_runtime_nav_region.gd` and `tests/ui/test_debug_actions.gd`;
  - `test_events.gd`, content validation.

## Context
Until now, DESIGN said "Doors/Barricades" but only meant buyable doors (F017), and enemies spawned inside the play area. The owner asked for CoD-style boarded windows:
- enemies enter through fixed windows and tear the planks off one at a time;
- players hold E on the inside to nail them back, for points.

M1's range (F010–F019) was full, so it was registered as **F046** (the M4 band) and built before F020.

**AC:** enemies breach a window plank by plank and climb in; players repair it for points.

## Decisions

### Physics: the BARRIER layer
- `Barricade` is a StaticBody3D on **`PhysicsLayers.BARRIER`** (layer 5):
  - players (`CHARACTER_MASK`) and enemies collide with it, so nobody walks through it and avoidance can't push anyone through it;
  - it isn't in `ATTACK_MASK` or the LOS ray (WORLD), so **shots, melee sweeps and sight lines pass through**, whatever planks are left;
  - the player's interact ray uses `INTERACT_MASK` (WORLD | BARRIER).
- `RuntimeNavRegion` bakes with WORLD | BARRIER, and the barricade joins `nav_blockers`. Each closet is therefore **its own nav island**, and enemies inside never path back out.

### Window model
- **The planks:** `BarricadeData` (`plank_count` 6, `repair_interval_s` 0.75, `repair_points` 10, `climb_s` 0.8). The plank meshes show `planks` of them.
- **Orientation:** local −Z is outside, +Z inside. `OuterPoint` sits 1 m out, `InnerPoint` 1 m in.
- **Slots:** one **tearer** and one **climber** at a time (`claim_tear` / `claim_climb` / `release`). A dead holder's slot frees itself.
- **Events:** every change emits `planks_changed` and `Events.barricade_changed(barricade_id, planks)`.

### Enemy entry (entry-bound AI)
- **The link:** an `EnemySpawnPoint` with `barricade` set gives each enemy it spawns `breach = <that window>`. Enemies spawned elsewhere (or after climbing in) have no `breach` and ignore windows.
- **The ring spread** is clamped by `max_spread_index` (6 in the closets).
- **`Breach` state** (Chase and Idle send breaching enemies here):
  1. if `can_start_attack()` (through a window: reach + 0.3 m, a 40° arc so it doesn't clang off the jambs, and **no lunge**, because `lunge_scale()` is 0) → `Windup`, so it **swipes through** at a player standing close;
  2. when the window is open, `claim_climb` → walk to the outer point → `Climb`;
  3. otherwise `claim_tear` → stand at the outer point and tear one plank per `EnemyData.barricade_tear_s` (acolyte 1.2 s);
  4. otherwise wait within 2 m, facing the window.

  Recovery and staggers return to Chase, which routes back to Breach.
- **`Climb`:**
  - it adds a collision exception for the window and moves straight to the inner point over `climb_s`;
  - staggers and stuns are swallowed;
  - when it ends, it's inside (`breach = null` → Chase), or, if a body stopped it short (a player in the window), it goes back to Breach.
- **`walk_to(point)`** follows the agent's path. The last 1.5 m (where the eroded navmesh ends) is walked straight without avoidance, so the enemy actually reaches the outer point.

### Player repair (hold to use)
- **`Interactable.hold_interval_s` > 0** makes an interactable hold-to-use. `Player._update_interact` accumulates time while interact is held on the same target, and uses it once per interval. Releasing, looking away or the target changing resets the timer. A press on an unusable one still emits `interact_denied`. Press-type interactables are unchanged.
- **The prompt:** "Hold E: Repair barricade", plus a ▮▮▯ progress bar in the temp HUD. It's disabled with "Intact" (full), "Blocked" (an enemy holds the climb slot) or "Unreachable" (the player is outside).
- **Reward:** each plank pays `PointRules.repair_points(10)` through `PointsComponent.award(…, &"repair")`. It's **uncapped**, pays at any time, and isn't scaled by `points_per_damage_mult` (it isn't damage).

### Sandbox
- **Windows:**
  - north (x 6), south (x −12) and east (z 10) arena walls, each with a 6×4 m closet holding one spawn point;
  - one in the annex west wall, whose closet spawn is gated by the annex zone.
- **The 4 interior arena spawn points were removed**, so every enemy (director and F10) enters through a window.

## Consequences
- **F021/F023:** the host runs breach/repair. Clients mirror the planks from `barricade_changed` (or replicated state), and send the interact-held state in their intent (`interact_held` is already part of `MoveIntent`).
- **F031/F063:** traitors could quietly tear planks or refuse to repair (sabotage, stretch).
- **F044:** spawn legality can treat closets as off-camera by construction. Crowding at the outer point with large alive caps is the main tuning risk.
- **F040–F043:** new enemy types get `barricade_tear_s`. Specials may skip windows (e.g. leap through) by not using the Breach state.
- **Lint:** `EnemyBase` now carries `# gdlint:disable=max-public-methods` (it's the facade the brain states use).
