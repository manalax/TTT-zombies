# ADR 0008 — Enemy AI v1 (Acolyte)

- **Status:** Accepted (F015, 2026-11-09)
- **Code:**
  - `src/enemies/`: `EnemyBase` (`enemy_base.gd`), `brain/` states, `AITargeting`, `AIStats`, `EnemyRegistry`, `acolyte/acolyte.tscn`;
  - `src/world/nav/runtime_nav_region.gd`;
  - `src/world/spawn/enemy_spawn_point.gd`;
  - `EnemyData` Attack/Behaviour fields.
- **Tests:**
  - `tests/enemies/test_acolyte_swarm.gd` (the AC);
  - `tests/enemies/test_acolyte.gd`, `test_ai_targeting.gd`;
  - `tests/world/test_runtime_nav_region.gd`;
  - `tests/data/test_misc_data.gd`, `tests/ui/test_debug_actions.gd`.

## Context
DESIGN §7.1 sets out the common AI:
- navmesh pathing to the nearest valid target (never traitors);
- a simple melee state machine;
- parry-readable telegraphs;
- 60 active AI at 60 fps on the host (§12.5).

**AC:** 30 acolytes chase a player without frame drops. We test at **60**.

The design reuses earlier systems: `MeleeSweep` (ADR 0005), the parry and stun rules (ADR 0006) and `Combat.apply` (ADR 0004).

## Decisions

### EnemyBase anatomy and step order
- **The body:** a `CharacterBody3D` on ENEMIES, with mask WORLD | PLAYERS.
  - Players can be surrounded and body-blocked.
  - Enemies don't collide with each other; avoidance spaces them, which is cheaper and doesn't jitter.
  - Children: `HealthComponent` (CULT), `PoiseComponent`, body and head (weak-point) `Hurtbox`es, a `NavigationAgent3D`, the `Brain` StateMachine (MANUAL tick), and a greybox `Visual`.
- **Data:** stats come from `EnemyData`. It's set by the spawner, or looked up through the `enemy_id` export. The scene never references its `.tres`, which avoids a load cycle, since `EnemyData.scene` points at the scene.
- **`step(delta)`**, run on the authority only:
  1. `health.tick` and `poise.tick`.
  2. Cooldown and aggro timers.
  3. **Target re-pick** every 1 s.
  4. **Repath** every 0.3 s.
  5. `brain.physics_tick`.
  6. Integrate + `move_and_slide`.
- **Throttling:** the target and repath timers start at offsets derived from `net_id`, so a burst of spawns doesn't replan on the same tick. Movement and attack timing run **every** tick, so parry windows stay exact (ADR 0006). Distance LOD is deferred to F055.
- **Movement modes:**
  - `CHASE`: the agent's next path point, through RVO avoidance (`velocity_computed`);
  - `DIRECT`: an exact velocity that ignores avoidance (the lunge);
  - `STOP`.
  - In non-chase modes the real velocity is reported to the agent, so neighbours don't predict that a stopped enemy is still walking.

### Brain state machine (ADR 0001)
```
Alive{ Idle, Chase, Attack{Windup, Lunge, Recovery}, Staggered, Stunned }   Dead
```
- **Chase → Windup** when the target is valid, within `attack_range_m` (horizontal), in line of sight (a WORLD ray), the enemy is on the floor and `cooldown_left` is 0.
- **Windup** (`attack_windup_s`, the parry read): the enemy stands still with the telegraph on (a red glow, or purple if unparryable, plus a raised arm). It turns toward the target at 120°/s, so it tracks a walking player, but a late sidestep or dodge beats it.
- **Lunge** (`attack_active_s`):
  - **The direction locks** on entry: yaw from the body, plus pitch toward the target's centre (±40°).
  - The body moves `lunge_distance_m` along it via `DIRECT`, so walls and players stop it.
  - A `MeleeSweep` (RIGHT_TO_LEFT, `attack_arc_deg`, `attack_reach_m`, `attack_damage`, `attack_stagger`, `unparryable = not parryable`) runs over the window. A clang ends it early.
- **Recovery** (`attack_recovery_s`): standing still, the punish window. Then `cooldown_left = attack_cooldown_s`, and the enemy chases (adjacent) until it can swing again. The cooldown is a timer, not a state.
- **Interruptions:** `Alive` handles the `staggered` event (from `PoiseComponent`, duration `stagger_duration_s`) and the `stunned` event (a parry, with the parrier's `parry_stun_s`).
  - The `Attack` parent's `_exit` clears the telegraph, so any interruption cancels the swing.
  - A repeated interruption extends to the longer remaining time. A stun overrides a stagger.
  - The riposte itself is the pipeline rule from ADR 0006 (`health.riposte_by`).
- **Hits below `stagger_resist` don't interrupt**, so swarms stay dangerous.

### Targeting
- **`AITargeting.is_valid_target(body)`:** alive and in the HUNTER faction. **F031 adds the traitor exclusion here**, and no other code may decide AI targets.
- **`pick()`:** the nearest candidate in the group `ai_targets`. The current target is kept unless another is ≥ 2 m closer (hysteresis).
- **Aggro:** a player who damages the enemy becomes its target immediately, and is kept for `aggro_memory_s` while valid.
- With no valid target, the enemy goes to Idle.

### Navigation
- **`RuntimeNavRegion`** bakes **at load, deferred by one call**, from collision geometry under its `source`:
  - the `StaticBody3D` colliders on WORLD (e.g. the invisible stair ramp), via the geometry parser, restricted to those bodies with a temporary explicit group;
  - **plus each colliding root CSG shape's `bake_collision_shape()` faces**, added by hand.
  - **Why:** CSG collision is internal rather than a body node, so the collider parser never sees it. Godot's own CSG parser reads the visual mesh back from the GPU (a runtime performance warning). CSG also builds its shapes with a deferred call, so a bake in `_ready` missed the whole arena floor. `test_arena_walkability` guards against this.
  - **Cells:** 0.25 m wide and **0.125 m high** (project setting `navigation/3d/default_cell_height` must match). Agent radius 0.5, height 1.75, climb 0.25, slope 45°. With 0.25 m-high cells, a 0.5 m box rounded down to a climbable step.
  - Greybox maps stay editable with no baked asset to keep in sync. The arena bakes in about 30 ms.
- **Navigation regions sync asynchronously:** paths are available a few physics frames after the bake. Until then, `chase()` heads straight for the target.
- **What's walkable in the arena:** the 20° and 40° ramps and the stairs, and every spawn point reaches the player. Not the 50° ramp or the 0.5 m and 1.3 m jump boxes. Dummies are on ENEMIES, so they aren't nav obstacles.

### Death
On death:
- collision and hurtboxes are switched off (deferred, because death can happen inside a physics query);
- avoidance stops;
- the telegraph clears;
- the brain goes to `Dead`;
- **`Events.enemy_killed(net_id, killer_peer_id)`** fires (the hook for F016 points);
- a tip-over tween plays;
- the body is freed after `corpse_s` (counted by `step`).

### Spawning and tooling
- **`EnemySpawnPoint.spawn(data, parent, index)`:** spawns spread on rings around the marker. F019 will reuse it.
- **`EnemyRegistry`:** the container node in the map (spawn, clear, alive count).
- **Debug keys:** F10 spawns one acolyte, Shift+F10 spawns 30, F11 clears them all.
- **`AIStats`:** sums each enemy step's cost per physics tick. The F3 overlay shows the AI ms per tick (smoothed and peak) and the physics ms.

## Performance (AC)
- **Setup:** `test_acolyte_swarm` spawns 60 acolytes on 14–20 m rings around a stationary player, with pillars, and runs 6 s of real physics.
- **It asserts:**
  - every acolyte closed ≥ 3 m;
  - ≥ 90% end within 5 m;
  - avoidance spreads them (mean nearest-neighbour distance > 0.7 m, none stacked);
  - **the mean AI time per tick is < 4 ms** for all 60. That's a deliberately loose bar for CI.
- **Measured headless:** a mean of about 2.3–2.8 ms per tick, including each enemy's `move_and_slide`. The peak varies between runs, from 6 ms to about 55 ms on a single tick. The spike most likely comes from the first path queries or the async map sync; it hasn't been profiled yet and is for F055 to look at if it shows up as a hitch in play.
- **Rendering FPS** is a manual check (Shift+F10 twice in the sandbox).

## Consequences
- **F016:** awards points from `Combat.damage_applied` by `EnemyData.category` (ADR 0009). There is no kill bonus, and `enemy_killed` is left for stats and the director.
- **F019:** spawns via `EnemySpawnPoint` into the `EnemyRegistry`; wave modifiers scale `EnemyData` copies.
- **F023:** clients don't run `step()` (the authority guard). They render replicated transforms and brain paths (`StateMachine.apply_remote_state`). `net_id` becomes host-assigned.
- **F031:** traitor rules go in `AITargeting.is_valid_target`.
- **F043 and the specials:** extend `EnemyBase` and add states. Multi-attack enemies may later move the attack fields into an `EnemyAttack` sub-resource.
- **F055:** if profiling needs it, add distance LOD and tick-rate throttling, or a C# steering port (§12.4).
- **Testing note:** bodies moved by hand (teleports, or a manually stepped `move_and_slide` with no physics frame) aren't visible to physics queries until the next physics frame. Tests await a frame before a query that depends on new positions.
