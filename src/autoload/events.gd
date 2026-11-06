extends Node
## Global typed signal bus (DESIGN §12.3).
##
## Rules:
## - [b]Local to each peer, never networked.[/b] The authority emits after it has applied a state
##   change; clients emit after the RPC / synchronizer update that carries it has landed.
##   Never make an authoritative decision on a client because of one of these signals.
## - [b]Arguments are stable IDs and plain values, never node references.[/b]
##   [code]peer_id: int[/code] is the multiplayer peer id (1 = host, 0 = world / none).
##   [code]net_id: int[/code] is a replicated enemy/object id. Content ids are [StringName]s.
## - Secret information (roles) is only emitted on the peer that owns it.
## - Add new signals in the feature that first emits them, with a doc comment, and extend
##   tests/autoload/test_events.gd.

# --- Match flow (DESIGN §4) -----------------------------------------------------------------

## Match state machine moved between leaf states, e.g. &"Intermission" -> &"WaveActive".
signal match_state_changed(from_state: StringName, to_state: StringName)
signal intermission_started(round_number: int, duration_s: float)
signal round_started(round_number: int)
signal round_cleared(round_number: int)
## [param winning_side] is &"hunters" or &"cult".
signal match_ended(winning_side: StringName)

# --- Players --------------------------------------------------------------------------------

signal player_joined(peer_id: int)
signal player_left(peer_id: int)
## [param as_role] is the public role: &"hunter" or &"cultist" (traitors spawn as &"hunter").
signal player_spawned(peer_id: int, as_role: StringName)
signal player_damaged(peer_id: int, source_id: int, amount: float)
signal player_died(peer_id: int, killer_id: int, cause: StringName)
## A dead Hunter rose as a special enemy (Betrayal mode).
signal player_converted(peer_id: int, special_id: StringName)
## A dead Hunter returned as a Hunter (Vigil mode).
signal player_respawned(peer_id: int)

# --- Roles (DESIGN §5) ----------------------------------------------------------------------

## Only emitted on the owning peer. [param role] is &"hunter" or &"traitor".
signal local_role_assigned(role: StringName)
## [param reason] is &"witnessed" or &"silver_test".
signal player_exposed(peer_id: int, reason: StringName)

# --- Enemies --------------------------------------------------------------------------------

signal enemy_spawned(net_id: int, enemy_id: StringName)
signal enemy_killed(net_id: int, killer_id: int)

# --- Economy --------------------------------------------------------------------------------

signal points_changed(peer_id: int, total: int, delta: int)

# --- World ----------------------------------------------------------------------------------

signal door_opened(door_id: StringName, peer_id: int)
signal zone_unlocked(zone_id: StringName)
