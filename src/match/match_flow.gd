class_name MatchFlow
extends StateMachine
## Match lifecycle machine (DESIGN §4.1). Skeleton only: states carry no logic until F019.
##
## Lobby -> Loading -> InMatch{Intermission <-> WaveActive} -> Victory | Defeat -> Results -> Lobby.
## Re-emits every change as Events.match_state_changed using leaf state names.


func _ready() -> void:
	state_changed.connect(_on_state_changed)
	super()


func _on_state_changed(from_path: String, to_path: String) -> void:
	Events.match_state_changed.emit(_leaf_name(from_path), _leaf_name(to_path))


static func _leaf_name(path: String) -> StringName:
	if path.is_empty():
		return &""
	return StringName(path.get_slice("/", path.get_slice_count("/") - 1))
