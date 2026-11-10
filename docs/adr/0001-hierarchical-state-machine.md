# ADR 0001 — Hierarchical State Machine

- **Status:** Accepted (F002, 2026-11-06)
- **Code:** `src/core/state_machine/state_machine.gd` (`StateMachine`), `src/core/state_machine/state.gd` (`State`)
- **Tests:** `tests/core/test_state_machine.gd`. Reference usage: `src/match/match_flow.tscn`.

## Context
Enemy AI and specials, weapon swing phases and match flow all need state machines. Specials have nested behaviour (Stalker: Hunting → Leap → Pin, plus shared "Alive"/"Staggered" logic), so the machine is hierarchical rather than flat. It must also support AI tick throttling (§12.5) and later be mirrored from the host to clients (§12.2), without containing any networking code itself.

## Decision
A **node-based hierarchical state machine**. A `StateMachine` node owns a tree of `State` child nodes. A `State` with `State` children is **compound**.

### Structure
- State **names must be unique per machine**. Transitions target a name; paths such as `"InMatch/WaveActive"` are used for reporting and mirroring.
- Only `State` children are part of the tree. A nested `StateMachine` under a state is an independent machine and is not traversed.
- The machine disables `_process` / `_physics_process` on its states. States implement the virtual hooks only:
  - `_enter(data)`, `_exit()`
  - `_update(delta)`, `_physics_update(delta)`
  - `_handle_event(event, data) -> bool`

### Entering
- Entering a compound state descends into its entry child, chosen in this order:
  1. The last active child, if `remember_last_child` is set (shallow history).
  2. Otherwise `initial_child`.
  3. Otherwise its first `State` child.
- This repeats until a leaf is reached.
- The active configuration is always a single chain from root to leaf.

### Transitions
1. **Lowest common ancestor (LCA).** Exit from the leaf upward until reaching the LCA of the current leaf and the target; the LCA itself is not exited. Then enter downward from below the LCA to the target, then descend into entry children.
2. **External self-transition.** If the target is the current leaf or an active ancestor, it is exited and re-entered.
3. **`data`** goes only to the target's `_enter`. States entered by descending get `{}`.
4. **Inherited allow-lists.** Each state has `allowed_transitions` (state names; empty = *no constraint*).
   - If no state in the active chain declares a list, any transition is allowed.
   - Otherwise the target must appear in **at least one** active state's list.
   - So a parent can grant a shared exit once (`InMatch → [Victory, Defeat]`) while children declare their local moves (`Intermission → [WaveActive]`).
   - Unknown or illegal targets: `push_warning`, emit `transition_rejected(from_path, target)`, return `false`.
5. **Run-to-completion.** A transition requested while another is in progress (from `_enter`/`_exit`) is queued and run afterwards. It is validated against the active chain at the moment it is requested. More than 32 chained transitions in one call trips a loop guard (`push_error`, queue dropped).

### Updates & events
- `tick` / `physics_tick` call every active state **root → leaf**. If a transition happens mid-tick, the old chain stops being ticked (chain-version check).
- `send_event` delivers to the **leaf first** and **bubbles** to ancestors until a handler returns `true`. It returns whether the event was consumed.
- `tick_mode`:
  - `AUTO` (default): the machine ticks itself from `_process` / `_physics_process`.
  - `MANUAL`: the owner calls `tick` / `physics_tick`, so an AI LOD scheduler can throttle ticks.

### Mirroring (networking hooks, no networking code)
- Each completed transition emits `state_changed(from_path, to_path)`. `from_path` is `""` on start and `to_path` is `""` on stop.
- `get_active_path()` returns the current path.
- `apply_remote_state(path)` runs the normal exit/enter sequence but **skips allow-lists**. Clients use it to follow the host. Wiring it to RPCs or synchronizers is F020+ work.

### Diagnostics
`get_history()` is a ring buffer of `history_size` entries in the form `"from -> to"`. `debug_log` prints each transition.

## Consequences
- States are scene-tree nodes, so they can be inspected in the editor and tuned with `@export`. This adds a few nodes per enemy, which is acceptable at the §12.5 targets.
- Name-based targets keep transition calls short. The cost is that names must be unique within each machine; duplicates are a `push_error` at init.
- State hooks must never perform authoritative game actions on clients. The authority drives the machine, and clients mirror it via `apply_remote_state`.
