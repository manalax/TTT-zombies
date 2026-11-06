class_name StateMachine
extends Node
## Hierarchical state machine. Semantics: docs/adr/0001-hierarchical-state-machine.md.
##
## Children that are [State] nodes form the state tree; state names must be unique per machine.
## Updates run root -> leaf over the active chain; events go to the leaf and bubble up.
## Transitions are validated against the inherited allow-lists of the active chain and run to
## completion (requests made during enter/exit are queued). The machine contains no networking
## code: clients mirror host state with [method apply_remote_state].

## Emitted after every completed transition. Paths are relative, e.g. "InMatch/WaveActive";
## [param from_path] is "" on start and [param to_path] is "" on stop.
signal state_changed(from_path: String, to_path: String)
## Emitted when a requested transition is unknown or not allowed.
signal transition_rejected(from_path: String, target: StringName)

enum TickMode { AUTO, MANUAL }

## Guards against transitions that keep re-triggering each other.
const MAX_CHAINED_TRANSITIONS := 32

## AUTO: the machine ticks itself. MANUAL: the owner calls tick() / physics_tick().
@export var tick_mode: TickMode = TickMode.AUTO:
	set(value):
		tick_mode = value
		_apply_tick_mode()
## Top-level state entered on start. Empty = first State child.
@export var initial_state: NodePath
@export var autostart: bool = true
## Print every transition.
@export var debug_log: bool = false
## Number of "from -> to" entries kept by get_history().
@export var history_size: int = 16

var _states: Dictionary[StringName, State] = {}
var _active_chain: Array[State] = []
var _running: bool = false
var _transitioning: bool = false
var _pending: Array[PendingTransition] = []
var _chain_version: int = 0
var _history: Array[String] = []
var _collected: bool = false


class PendingTransition:
	var target: State
	var data: Dictionary

	func _init(p_target: State, p_data: Dictionary) -> void:
		target = p_target
		data = p_data


func _ready() -> void:
	_collect_states()
	_apply_tick_mode()
	if autostart:
		start()


func _process(delta: float) -> void:
	tick(delta)


func _physics_process(delta: float) -> void:
	physics_tick(delta)


## Enter the initial state. No-op if already running.
func start(data: Dictionary = {}) -> void:
	if _running:
		return
	_collect_states()
	var root := _get_initial_root()
	if root == null:
		push_error("StateMachine '%s' has no State children." % name)
		return
	_running = true
	_request(root, data)


## Exit every active state.
func stop() -> void:
	if not _running:
		return
	var from_path := get_active_path()
	_exit_until(null)
	_running = false
	_chain_version += 1
	_record(from_path, "")


func is_running() -> bool:
	return _running


## Request a transition to the state named [param target]. Returns false if the target is unknown
## or not permitted by the active chain's allow-lists. Requests made while a transition is in
## progress are queued and run after it completes.
func transition_to(target: StringName, data: Dictionary = {}) -> bool:
	var from_path := get_active_path()
	if not _running:
		push_warning("StateMachine '%s': transition to '%s' while stopped." % [name, target])
		return false
	if not _states.has(target):
		push_warning("StateMachine '%s': unknown state '%s'." % [name, target])
		transition_rejected.emit(from_path, target)
		return false
	if not _is_allowed(target):
		push_warning("StateMachine '%s': '%s' -> '%s' not allowed." % [name, from_path, target])
		transition_rejected.emit(from_path, target)
		return false
	_request(_states[target], data)
	return true


## Mirror a state path reported by the authority (e.g. "InMatch/WaveActive"). Skips allow-lists.
func apply_remote_state(path: String, data: Dictionary = {}) -> void:
	_collect_states()
	var leaf_name := StringName(path.get_slice("/", path.get_slice_count("/") - 1))
	if not _states.has(leaf_name) or _states[leaf_name].get_path_in_machine() != path:
		push_warning("StateMachine '%s': unknown remote state path '%s'." % [name, path])
		return
	_running = true
	_request(_states[leaf_name], data)


## Send an event to the active leaf; it bubbles to ancestors until one consumes it.
func send_event(event: StringName, data: Dictionary = {}) -> bool:
	var version := _chain_version
	var chain := _active_chain.duplicate()
	for i in range(chain.size() - 1, -1, -1):
		var state: State = chain[i]
		if state._handle_event(event, data):
			return true
		if _chain_version != version:
			return false
	return false


func tick(delta: float) -> void:
	var version := _chain_version
	for state: State in _active_chain.duplicate():
		state._update(delta)
		if _chain_version != version:
			return


func physics_tick(delta: float) -> void:
	var version := _chain_version
	for state: State in _active_chain.duplicate():
		state._physics_update(delta)
		if _chain_version != version:
			return


func get_state(state_name: StringName) -> State:
	return _states.get(state_name)


func get_active_leaf() -> State:
	return _active_chain.back() if not _active_chain.is_empty() else null


## Active leaf path relative to the machine, e.g. "InMatch/WaveActive". "" when stopped.
func get_active_path() -> String:
	var leaf := get_active_leaf()
	return leaf.get_path_in_machine() if leaf != null else ""


## True if [param state_name] is the active leaf or one of its ancestors.
func is_in_state(state_name: StringName) -> bool:
	return _states.has(state_name) and _states[state_name].is_active()


## Most recent transitions, oldest first, as "from -> to".
func get_history() -> Array[String]:
	return _history.duplicate()


func _collect_states() -> void:
	if _collected:
		return
	_collected = true
	_states.clear()
	for child in get_children():
		if child is State:
			_register(child as State, null)


func _register(state: State, parent: State) -> void:
	if _states.has(state.name):
		push_error("StateMachine '%s': duplicate state name '%s'." % [name, state.name])
	_states[state.name] = state
	state.machine = self
	state.parent_state = parent
	state.set_process(false)
	state.set_physics_process(false)
	for child in state.get_child_states():
		_register(child, state)


func _apply_tick_mode() -> void:
	var auto := tick_mode == TickMode.AUTO
	set_process(auto)
	set_physics_process(auto)


func _get_initial_root() -> State:
	if not initial_state.is_empty():
		var node := get_node_or_null(initial_state)
		if node is State:
			return node as State
		push_warning("StateMachine '%s': initial_state is not a State." % name)
	for child in get_children():
		if child is State:
			return child as State
	return null


func _is_allowed(target: StringName) -> bool:
	var constrained := false
	for state in _active_chain:
		if state.allowed_transitions.is_empty():
			continue
		constrained = true
		if target in state.allowed_transitions:
			return true
	return not constrained


func _request(target: State, data: Dictionary) -> void:
	_pending.append(PendingTransition.new(target, data))
	if _transitioning:
		return
	_transitioning = true
	var performed := 0
	while not _pending.is_empty():
		performed += 1
		if performed > MAX_CHAINED_TRANSITIONS:
			push_error("StateMachine '%s': transition loop detected; dropping queue." % name)
			_pending.clear()
			break
		var next: PendingTransition = _pending.pop_front()
		_perform(next.target, next.data)
	_transitioning = false


func _perform(target: State, data: Dictionary) -> void:
	var from_path := get_active_path()
	var leaf := get_active_leaf()
	var keep: State = null  # deepest state that stays active
	if leaf != null:
		var lca := _lowest_common_ancestor(leaf, target)
		# Target is the leaf or an active ancestor: external self-transition, re-enter it.
		keep = target.parent_state if lca == target else lca
	_exit_until(keep)

	var entering: Array[State] = []
	var state := target
	while state != keep:
		entering.push_front(state)
		state = state.parent_state
	for entered in entering:
		_enter_state(entered, data if entered == target else {})

	var current := target
	while current.is_compound():
		var child := current.get_entry_child()
		if child == null:
			break
		_enter_state(child, {})
		current = child

	_chain_version += 1
	_record(from_path, get_active_path())


func _enter_state(state: State, data: Dictionary) -> void:
	_active_chain.append(state)
	state._active = true
	state._enter(data)


## Exit active states from the leaf upward, stopping before [param keep] (null = exit all).
func _exit_until(keep: State) -> void:
	while not _active_chain.is_empty() and _active_chain.back() != keep:
		var state: State = _active_chain.pop_back()
		state._exit()
		state._active = false
		if state.parent_state != null:
			state.parent_state._last_child = state


func _lowest_common_ancestor(a: State, b: State) -> State:
	var ancestors := {}
	var state := a
	while state != null:
		ancestors[state] = true
		state = state.parent_state
	state = b
	while state != null:
		if ancestors.has(state):
			return state
		state = state.parent_state
	return null


func _record(from_path: String, to_path: String) -> void:
	_history.append("%s -> %s" % [from_path, to_path])
	while _history.size() > maxi(history_size, 0):
		_history.pop_front()
	if debug_log:
		print("[%s] %s -> %s" % [name, from_path, to_path])
	state_changed.emit(from_path, to_path)
