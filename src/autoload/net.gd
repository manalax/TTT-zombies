extends Node
## Networking facade (DESIGN §12.2).
##
## Owns the transport abstraction (ENet/Steam) once F020 lands. For now it only
## answers the authority question used by every state-changing system.


## True when this process may change authoritative game state: in single-player
## or offline (no peer set), or when this peer is the host/server.
func is_authority() -> bool:
	if not multiplayer.has_multiplayer_peer():
		return true
	return multiplayer.is_server()
