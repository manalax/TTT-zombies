extends State
## Test fixture: records every hook call into a shared log and can trigger transitions.

## Shared log (arrays are references, so every state in a test appends to the same one).
var log_ref: Array[String] = []
## Events this state consumes in _handle_event.
var consumes: Array[StringName] = []
## If set, request this transition from _enter / _update.
var transition_on_enter: StringName = &""
var transition_on_update: StringName = &""


func _enter(data: Dictionary) -> void:
	log_ref.append("enter:%s" % name)
	if data.has("tag"):
		log_ref.append("data:%s:%s" % [name, data["tag"]])
	if transition_on_enter != &"":
		transition_to(transition_on_enter)


func _exit() -> void:
	log_ref.append("exit:%s" % name)


func _update(_delta: float) -> void:
	log_ref.append("update:%s" % name)
	if transition_on_update != &"":
		transition_to(transition_on_update)


func _physics_update(_delta: float) -> void:
	log_ref.append("physics:%s" % name)


func _handle_event(event: StringName, _data: Dictionary) -> bool:
	log_ref.append("event:%s:%s" % [name, event])
	return event in consumes
