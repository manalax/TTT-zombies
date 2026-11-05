# Vigil of Ash (working title)

A first-person multiplayer horde brawler for Godot 4. Hunters hold out for 12 rounds against
waves of a demonic cult in a late-medieval / Victorian-gothic world, while a hidden traitor
works against them. Fallen Hunters rise again as the cult's special enemies. Includes a co-op
mode with no traitors. See [`docs/DESIGN.md`](docs/DESIGN.md) for the full design and
[`docs/PROGRESS.md`](docs/PROGRESS.md) for implementation status.

## Requirements
- **Godot 4.7.2** (the .NET/mono build is installed locally; C# is not used yet, so the
  standard build also works).
- **Python 3.10+** for lint/format tooling (gdtoolkit).

## Run
Open `project.godot` in Godot and press F5, or from a terminal:

```sh
GODOT=/Applications/Godot_4.7.2_mono.app/Contents/MacOS/Godot
$GODOT --path .            # run the game
$GODOT --path . --editor   # open the editor
```

## Tests
Tests use [gdUnit4](https://github.com/godot-gdunit-labs/gdUnit4) (v6.2.3, vendored in
`addons/gdUnit4`). Test suites live in `tests/`.

```sh
scripts/run_tests.sh                       # all tests, headless
scripts/run_tests.sh -a res://tests/test_smoke.gd
GODOT_BIN=/path/to/godot scripts/run_tests.sh
```

Reports are written to `reports/` (gitignored). Tests can also be run from the gdUnit4 panel in
the editor.

## Lint & format
```sh
python3 -m venv .venv && .venv/bin/pip install -r requirements-dev.txt
.venv/bin/gdformat src tests          # format
.venv/bin/gdlint src tests            # lint (config: .gdlintrc)
```

CI (GitHub Actions, `.github/workflows/ci.yml`) runs lint and the headless tests on every push
to `main` and on pull requests.

## Assets
Gameplay is built with greybox placeholders (DESIGN §13). Third-party asset sources (e.g. Synty
packs in `Source-Files/` and `*.zip`) are gitignored and must never be committed.
