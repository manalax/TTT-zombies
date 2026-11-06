class_name State
extends Node
## One state in a hierarchical [StateMachine].
## Semantics: docs/adr/0001-hierarchical-state-machine.md.
##
## A State with State children is a compound state. Subclasses override the virtual hooks
## ([method _enter], [method _exit], [method _update], [method _physics_update],
## [method _handle_event]). Do not override [code]_process[/code] / [code]_physics_process[/code];
## the machine drives ticks so it can throttle them.

## Child entered when this compound state is entered. Empty = first State child.
@export var initial_child: NodePath
## When re-entered, resume the child that was active when this state was last exited.
@export var remember_last_child: bool = false
## Names of states reachable from this state or any of its descendants. Empty = no constraint.
@export var allowed_transitions: Array[StringName] = []

## Set by the owning machine.
var machine: StateMachine
## Parent state, or null for top-level states. Set by the owning machine.
var parent_state: State

var _last_child: State
var _active: bool = false


## Called when the state becomes active. [param data] is only passed to the transition target.
func _enter(_data: Dictionary) -> void:
	pass


## Called when the state stops being active.
func _exit() -> void:
	pass


## Per-frame update. Called on every active state, parent before child.
func _update(_delta: float) -> void:
	pass


## Per-physics-frame update. Called on every active state, parent before child.
func _physics_update(_delta: float) -> void:
	pass


## Handle an event sent via [method StateMachine.send_event]. Return true to consume it;
## unconsumed events bubble to the parent state.
func _handle_event(_event: StringName, _data: Dictionary) -> bool:
	return false


## Request a transition on the owning machine. Returns false if it was rejected.
func transition_to(target: StringName, data: Dictionary = {}) -> bool:
	if machine == null:
		push_error("State '%s' is not owned by a StateMachine." % name)
		return false
	return machine.transition_to(target, data)


func is_active() -> bool:
	return _active


func is_compound() -> bool:
	return not get_child_states().is_empty()


func get_child_states() -> Array[State]:
	var result: Array[State] = []
	for child in get_children():
		if child is State:
			result.append(child as State)
	return result


## Path relative to the machine, e.g. "InMatch/WaveActive".
func get_path_in_machine() -> String:
	var parts := PackedStringArray()
	var state: State = self
	while state != null:
		parts.insert(0, String(state.name))
		state = state.parent_state
	return "/".join(parts)


## The child to enter when this compound state is entered (history, then initial, then first).
func get_entry_child() -> State:
	if remember_last_child and _last_child != null:
		return _last_child
	if not initial_child.is_empty():
		var node := get_node_or_null(initial_child)
		if node is State:
			return node as State
		push_warning("State '%s': initial_child '%s' is not a State." % [name, initial_child])
	var children := get_child_states()
	return children[0] if not children.is_empty() else null
