# CLAUDE.md

Godot 4.7.2 multiplayer game: round-based zombie horde shooter-brawler with traitor dynamics.

- **Source of truth:** `docs/DESIGN.md`. Read §0 (quick reference), §12 (architecture) and the relevant feature in §14 before coding.
- Implement **one feature ID at a time** (F001, F002, …); track progress in `docs/PROGRESS.md`.
- GDScript by default, statically typed. No C# until a feature explicitly calls for it.
- Host-authoritative networking; secret role data is never replicated publicly. Use `Net.is_authority()` to guard state changes.
- State machines: use `StateMachine` + `State` (`src/core/state_machine/`); semantics in `docs/adr/0001-hierarchical-state-machine.md`.
- Cross-system communication goes through the `Events` autoload: local-only signals, IDs not node refs. Add new signals to `tests/autoload/test_events.gd` too.
- Test suites with >20 tests need `# gdlint:disable=max-public-methods` on line 1.
- Gameplay content lives in `/content` as `.tres` resources; greybox placeholders only. Rules in `docs/adr/0002-content-data-model.md`:
  - Path is `content/<category>/<id>/<id>.tres`, with a snake_case `id` equal to the file and folder name.
  - Look items up via `ContentDB.get_item(&"WeaponData", &"revolver")`.
  - `tests/data/test_content_db.gd::test_all_shipped_content_validates` must pass.
  - New data classes extend `GameData` (top-level) or `Resource` with `validate_into()` (sub-resources), and must be added to `DataSerializer.ALLOWED_TYPES` if they will be serialized.
  - When generating `.tres` from a script, reload saved items (`ResourceLoader.load`) before referencing them, or they get inlined as sub-resources.
- Player: `src/player/` per `docs/adr/0003-player-controller.md`. Input sources produce a `MoveIntent`; `MovementState`s set motor params and posture; only `Player.step()` moves the body. Tunables go in `PlayerDefaults`; local comfort prefs go in `Settings`.
- `main` boots straight into `maps/dev/sandbox_arena/` (F3 = debug overlay; add `get_debug_info()` + the `debug_info` group to show more).
- Damage: always `Combat.apply(DamageEvent)`; never change health directly. Stage order and rules: `docs/adr/0004-damage-pipeline.md` (parry, riposte and dodge stages in `0006-parry-dodge.md`). Points use `DamageResult.applied`.
- Combat timers (parry window, stun, i-frames) advance only through `tick(delta)` once per physics step. Owners of a `HealthComponent` must call `health.tick(delta)`; never use wall-clock time.
- Physics layers: use the `PhysicsLayers` constants (WORLD, PLAYERS, ENEMIES, HURTBOXES), never raw bits. Attacks query `PhysicsLayers.ATTACK_MASK`.
- Melee: `src/combat/melee/` per `docs/adr/0005-melee.md`. Hit detection is `MeleeSweep` (reuse it for AI melee); weapon states set `Player.set_combat_modifiers()` every tick.
- Weapons live in `Loadout` slots (`src/player/loadout/`); swap or buy through `Loadout.replace_slot()`. Ammo is only ever added through `Loadout.grant_ammo()` / `AmmoRules.grant()`, so `ammo_scarcity` and caps apply. Rules: `docs/adr/0007-firearms-loadout.md`.
- Enemies: `src/enemies/` per `docs/adr/0008-enemy-ai.md`. Extend `EnemyBase` (stats come from `EnemyData`; brain states only call its movement/attack helpers). AI picks targets only through `AITargeting`, and maps need a `RuntimeNavRegion`, an `EnemyRegistry` and `EnemySpawnPoint`s. Tests that move bodies by hand must await a physics frame before a physics query sees them; nav regions need a few frames to sync.
- Zones and doors: `src/world/zones/`, per `docs/adr/0010-doors-zones.md`. Anything usable gets an `Interactable` child; never add an ad-hoc group. Spawn points inside a `Zone` respect `is_active()`. Doors join `nav_blockers`, so they're baked as walls, and open through their `NavigationLink3D`.
- Points: only through `PointsComponent` (`award`, `try_spend`); damage points come from the `Economy` autoload via `PointRules` (`docs/adr/0009-points-economy.md`). Use `PointRules.door_price` / `shop_price` / `ammo_price` for every cost. There is no kill bonus.
- Debug keys (debug builds): F3 overlay, F5 reload scene, F6 hurt self, F7 test shot, F8 melee sweep draw, F9 swap melee weapon, F10 spawn acolyte (Shift+F10: 30), F11 clear enemies, F12 +1000 points.
- Ad-hoc headless scripts: pass `--remote-debug tcp://127.0.0.1:0` so a script error exits instead of hanging in the debugger.
- gdtoolkit treats `set` as a keyword: don't use it as a variable name.
- If a request conflicts with the design doc, ask the user and update the doc in the same change.

## Commands
- Godot binary: `/Applications/Godot_4.7.2_mono.app/Contents/MacOS/Godot` (override with `$GODOT_BIN`).
- Run game: `$GODOT_BIN --path .` · headless boot check: `$GODOT_BIN --headless --path . --quit-after 60`
- Tests (gdUnit4, headless): `scripts/run_tests.sh` (optionally `-a res://tests/<file>.gd`)
- Lint/format (gdtoolkit 4.5.0, `requirements-dev.txt`): `gdformat src tests`, `gdlint src tests` — line length 100.
- After adding/moving scripts, run `$GODOT_BIN --headless --path . --import` so `.uid` files are generated; commit them.

## Gotchas
- Don't use `addons/gdUnit4/runtest.sh`: it runs `dotnet build` on mono Godot and fails without a `.csproj`.
- `Source-Files/` (third-party Synty assets) has a `.gdignore`; never remove it, or Godot will write `.import` files into it. Never commit `Source-Files/` or `*.zip`.
