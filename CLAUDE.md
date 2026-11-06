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
