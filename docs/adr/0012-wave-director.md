# ADR 0012 — Wave Director v1 & Round Loop

- **Status:** Accepted (F019, 2026-11-10)
- **Code:**
  - `src/match/`: `MatchManager`, `WaveDirector`, `WaveRules`; `MatchFlow` (F002, unchanged);
  - `EnemyRegistry.spawn_one`, `Player.respawn`;
  - `content/waves/sets/dev_twelve`;
  - `TempHud` (round, timer, banners);
  - `DebugActions.start_match` (F4).
- **Tests:**
  - `tests/match/test_twelve_wave_run.gd` (the AC) + `fixtures/test_bot.gd`;
  - `tests/match/test_wave_rules.gd`, `test_wave_director.gd`, `test_match_manager.gd` (+ `match_test_world.gd`);
  - UI and debug updates.

## Context
DESIGN §4.1 sets the lifecycle: Intermission ⇄ WaveActive up to round N, then Victory/Defeat → Results. §8.1 defines `WaveData` and §8.3 the director rules.

**AC:** a bot-assisted run completes 12 waves headless.

`MatchFlow` (F002) already models the lifecycle but has no logic. F044 owns the full director constraints (visibility, special caps, breathers, ambient spawns); F045 the real 12-wave set.

## Decisions

### Split: manager drives a dumb flow; the director is pure
- **`MatchFlow`** stays a plain lifecycle machine (its F002 tests are untouched).
- **`MatchManager`** (one node per map, authority only, in group `match_manager`) is the only thing that transitions it.
  - `step(delta)` comes from `_physics_process`, and tests call it by hand.
  - It counts down, runs the director, spawns, and decides the end.
- **`WaveDirector`** (RefCounted) decides **what and when**. `WaveRules` (static) decides counts, the final round and spawn points. Neither touches the scene, so both are unit-tested without one.
- The manager spawns through `EnemyRegistry.spawn_one(data, point)` and reports back with `notify_spawned` / `notify_died` (from `Events.enemy_killed`).

### Wave semantics
- **Total:** each `WaveEntry` rolls `count_min..count_max` with the match RNG. That's scaled by `MatchSettings.player_scale[living Hunters]` and rounded (≥ 1 if the roll is > 0). The sum is the wave's total.
- **Alive cap:** `budget_points` caps the summed `EnemyData.budget_cost` of **this wave's living** enemies. A spawn is allowed while `alive + pending + cost ≤ budget_points`, or when nothing is alive, so a tiny budget can't stall.
- **Pacing:** `spawn_rate` per second via an accumulator. The first spawn is immediate, and catch-up is capped at one second's worth. `delay_s` holds an entry back from the wave start, and `weight` biases the pick among eligible entries.
- **Clear:**
  - `KILL_ALL`: nothing left to spawn and none alive;
  - `KILL_QUOTA`: this wave's kills ≥ `kill_quota`;
  - `SURVIVE_TIME`: elapsed ≥ `survive_time_s`;
  - any wave with `timeout_s > 0` also clears at the timeout.
- **Leftovers** (from quota and time waves) **stay alive** into the intermission and later waves. Their deaths don't count for the new wave.
- **No stat scaling yet:** the `enemy_*_mult` settings and `WaveModifier` aren't applied (F044/F045). `special_cap` and `boss` are unused (no specials exist yet).

### Spawn points
- Only **active** points (F017: unlocked zones) at least `min_spawn_distance_m` (15 m) horizontally from **every** living Hunter, picked at random (seeded by `match_seed`; 0 = random).
- If none qualifies, the point **farthest from its nearest Hunter** is used, so a wave never stalls.
- Repeated spawns at one point use its ring jitter.
- **Deferred to F044:** camera-frustum and line-of-sight visibility, and `ambient_spawns_in_closed_zones`.

### Round loop
- **`start_match()`** (Lobby only) captures each player's transform, seeds the RNG, goes Loading → InMatch (Intermission), and emits `intermission_started(1, intermission_s)`.
- **Intermission** is a plain countdown: no skip vote and no regen yet (`intermission_skip_vote` and `regen_mode` are for later). Shops and doors work at all times.
- **Wave start:** `round += 1`, `director.start(...)`, WaveActive, `round_started(n)`.
- **Wave clear:** `round_cleared(n)`. Then either Victory after round `min(final_round, set length)`, or Intermission with `intermission_started(n + 1)`.
- **Defeat:** no living Hunter during InMatch. Hunters are the `ai_targets` that `AITargeting.is_valid_target` accepts, so F031 will exclude traitors.
- **End:** `match_ended(&"hunters"` / `&"cult")` → Results for 5 s → **sandbox reset** → Lobby.
  - Enemies are cleared.
  - Each player gets `Player.respawn()` at `player_spawn` (or its match-start transform): full health (perks kept), stamina, starting points, the starting loadout, and out of Dead.
  - Doors and perks persist (F5 reloads everything).

### Content
- **`dev_twelve`:** 12 acolyte rounds, counts 6 → 40, alive cap 6 → 24, rate 1 → 3/s. Round 6 is a kill quota (14) and round 9 a 45 s survival, so all conditions run in the AC.
- The Betrayal and Vigil presets use it until F045. `test_short` stays for tests.

### HUD (local)
- `ROUND r / N` top centre, plus "Next round in m:ss" during intermission.
- 2.5 s centre banners: `ROUND n`, `ROUND CLEARED`, `VICTORY` / `DEFEAT` (from Events).
- F3 shows the phase, round, countdown and director counters.

### AC approach
`test_twelve_wave_run` runs the real manager and director on an 80 m test map with `dev_twelve` and a 0.2 s intermission.
- **The TestBot** kills each spawned enemy 0.5 s after it appears through `Combat.apply` (a real hit, so points, `enemy_killed` and the bookkeeping all run). Time is stepped at 60 Hz, with a frame yield every 300 steps.
- **It asserts:**
  - `round_started` and `round_cleared` 1..12 in order;
  - `match_ended(hunters)`;
  - the alive cap is never exceeded (with more than one alive);
  - every kill-all wave spawned its full planned total.
- **Measured:** about 8,900 steps (≈ 148 s of game time) and 240 kills, in about 0.4 s of real time.

## Consequences
- **F021/F023:** only the host runs `MatchManager.step`. Clients mirror the phase via `MatchFlow.apply_remote_state` and the round Events.
- **F034/F038:** death, conversion and co-op respawn replace the sandbox reset during a match. `Player.respawn` is the shared primitive.
- **F044:** spawn visibility, special caps and cooldowns, breathers, ambient spawns, and stat and modifier scaling plug into `WaveRules` and the director.
- **F045:** the real 12-wave set, plus presets.
- **Intermission extras** (skip vote, regen per `regen_mode`) are small additions to `MatchManager`.
