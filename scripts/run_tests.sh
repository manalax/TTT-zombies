#!/usr/bin/env bash
# Runs the gdUnit4 test suite headless.
# Usage: scripts/run_tests.sh [extra gdUnit4 args]   (default: -a res://tests)
# Godot binary: $GODOT_BIN, else the macOS 4.7.2 mono install.
#
# We call GdUnitCmdTool directly instead of addons/gdUnit4/runtest.sh, because that
# script runs `dotnet build` on mono builds and this project has no C# yet.
set -euo pipefail

GODOT_BIN="${GODOT_BIN:-/Applications/Godot_4.7.2_mono.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.."

if [ ! -d .godot ]; then
	"$GODOT_BIN" --headless --path . --import >/dev/null 2>&1 || true
fi

args=("$@")
if [ ${#args[@]} -eq 0 ]; then
	args=(-a res://tests)
fi

set +e
# --remote-debug to an unbound port stops Godot's interactive debugger hanging on errors.
"$GODOT_BIN" --headless --path . -s -d --remote-debug tcp://127.0.0.1:0 \
	res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode "${args[@]}"
exit_code=$?
set -e

"$GODOT_BIN" --headless --path . --quiet -s res://addons/gdUnit4/bin/GdUnitCopyLog.gd "${args[@]}" >/dev/null 2>&1 || true
echo "Tests finished with exit code $exit_code"
exit $exit_code
