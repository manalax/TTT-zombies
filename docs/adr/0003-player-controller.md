# ADR 0003 — First-Person Player Controller

- **Status:** Accepted (F010, 2026-11-06)
- **Code:** `src/player/` (`Player`, `PlayerCamera`, `input/`, `movement/`, `components/stamina_component.gd`), `src/data/player/player_defaults.gd`
- **Tests:** `tests/player/`. The integration tests drive the real `player.tscn` with `tests/player/fixtures/scripted_input_source.gd`.

## Context
F010 needs a responsive first-person body that every combat feature (F011–F015) builds on. In F031 the same movement must be simulated on the host from client input, so it can't be tied to the keyboard. The owner asked for a grounded, weighty feel and clear per-mode rules: no sprinting in the air or while strafing, crouch behaviour, exhaustion.

## Decisions

### Pipeline: input source → intent → movement HSM → motor
- **`PlayerInputSource`** (a Node) produces a `MoveIntent` once per physics step: move vector, sprint held, jump pressed (edge), and desired crouch.
  - `LocalInputSource` reads devices and local prefs. Hold vs toggle crouch is resolved here, so movement only sees the desired posture.
  - Tests use a scripted source, and F031 adds a network source. Movement code doesn't change.
- **`MovementMachine`** is a `StateMachine` (ADR 0001) in **MANUAL** tick mode, ticked by `Player.step()`:
  - `Grounded{Idle, Walk, Sprint, Crouch}` and `Airborne`.
  - Each state sets the motor parameters (target speed, accel, decel) and the posture, then requests transitions.
  - The allow-lists in `player.tscn` encode the legal moves.
- **`PlayerMotor`** holds the pure static math: `accelerate`, `apply_gravity`, `wish_direction`, `is_sprint_direction`. The player integrates it and calls `move_and_slide()`. **States never move the body.**
- **Fixed order per step:**
  1. Read the intent.
  2. Tick `JumpAssist` (coyote time and jump buffer).
  3. Tick stamina.
  4. Tick the machine.
  5. Run the motor.
  6. Move the eye height towards its target.
  
  `Player.step(delta)` is public, so tests and server-side simulation can call it directly.

### Rules (F010)
- **Sprint** requires the player to be grounded, to be moving within `sprint_max_angle_deg` (45°) of forward, and `stamina.can_sprint()`.
  - Sprinting drains stamina. Reaching 0 exhausts the player and locks sprint until stamina reaches `exhausted_recover_at` (30).
  - Jumping is free. Melee costs will use `try_spend` (F012).
- **Airborne:** horizontal speed carries at `max(walk_speed, takeoff speed)` with weak air control (`air_accel`) and no air drag. Sprint can't start in the air, but landing with sprint held resumes it.
- **Crouch:**
  - Standing up needs headroom: a `test_move` upward by `stand_height − crouch_height`.
  - Crouching mid-sprint sticks. A *fresh* sprint press cancels a toggled crouch, through `PlayerInputSource.cancel_crouch()`.
  - Crouching in the air is allowed (crouch-jumps).
- **Look:**
  - Yaw and pitch are stored on the `Player` and updated in `_process` every render frame.
  - The body takes the yaw at the start of each physics step.
  - The camera is `top_level` with physics interpolation **off**. It places itself at the head's *interpolated* position each frame (`physics/common/physics_interpolation` is on). This keeps look latency at zero and movement smooth on high-refresh displays.

### Data and preferences
- **Tunables** live in `PlayerDefaults` (GameData, `content/player/player_defaults/`). Nothing is hard-coded in the states.
- **Comfort settings** (sensitivity, invert Y, FOV, crouch mode) live in the `Settings` autoload. They are saved to `user://settings.cfg`, never replicated.

## Consequences
- **New movement modes** (dodge in F013, special-infected movement in F045) add `MovementState` subclasses and allow-list entries. The motor and input pipeline stay the same.
- **F031 replication:** add a network input source, run `step()` on the host, and mirror the state path with `StateMachine.apply_remote_state` for animation.
- **Stairs** need ramp colliders: `CharacterBody3D` has no step-up. Real step-up logic is out of scope until a map needs it.
