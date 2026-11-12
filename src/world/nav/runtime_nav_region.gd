class_name RuntimeNavRegion
extends NavigationRegion3D
## Bakes its navigation mesh right after it enters the tree (docs/adr/0008-enemy-ai.md), from
## the collision geometry under [member source]: static colliders on WORLD (e.g. invisible stair
## ramps), bodies in the `nav_blockers` group anywhere in the scene (closed doors), and the
## collision faces of colliding CSG shapes (greybox), which the collider parser does not see.
## Visual meshes are never parsed (that would read them back from the GPU).
## Opening a door calls [method rebake] (async), so doorways become real navmesh corridors.
## Greybox maps stay editable without re-baking. The bake is deferred because CSG builds its
## shapes with a deferred call; it then runs synchronously in one go.
## Values are multiples of the cell size (0.25 m) and height (0.125 m) to avoid precision warnings.

signal baked

const CELL_SIZE := 0.25
## Finer than the cell size so a 0.5 m ledge is clearly above the 0.25 m climb. Must match
## project setting navigation/3d/default_cell_height.
const CELL_HEIGHT := 0.125
## Temporary group marking the body nodes handed to the geometry parser.
const PARSE_GROUP := &"_runtime_nav_parse"
const GROUP := &"nav_regions"
const NAV_BLOCKER_GROUP := &"nav_blockers"
const BAKE_MASK := PhysicsLayers.WORLD | PhysicsLayers.BARRIER

## Root of the geometry to bake from. Empty = this node's parent.
@export var source: NodePath
@export var bake_on_ready: bool = true
@export_range(0.25, 2.0, 0.25, "suffix:m") var agent_radius: float = 0.5
@export_range(0.5, 4.0, 0.25, "suffix:m") var agent_height: float = 1.75
@export_range(0.0, 1.0, 0.25, "suffix:m") var agent_max_climb: float = 0.25
@export_range(0.0, 89.0, 1.0, "suffix:°") var agent_max_slope: float = 45.0

var _ready_to_use: bool = false
var _static_geometry: NavigationMeshSourceGeometryData3D
var _baking: bool = false
var _dirty: bool = false


func _ready() -> void:
	add_to_group(GROUP)
	if bake_on_ready:
		bake_now.call_deferred()


## Parses and bakes on the calling thread, then emits [signal baked]. Caches the static
## geometry (everything but `nav_blockers`) for [method rebake].
func bake_now() -> void:
	var root := _source_root()
	if root == null:
		return
	var mesh := _new_mesh()
	var blockers := _blocker_bodies()
	var bodies: Array[Node] = []
	for body in root.find_children("*", "StaticBody3D", true, false):
		if not body.is_in_group(NAV_BLOCKER_GROUP):
			bodies.append(body)
	_static_geometry = NavigationMeshSourceGeometryData3D.new()
	_parse_bodies(mesh, _static_geometry, root, bodies)
	_add_csg_faces(root, _static_geometry)
	var geometry := _with_blockers(mesh, root, blockers)
	NavigationServer3D.bake_from_source_geometry_data(mesh, geometry)
	_apply(mesh)


## Re-bakes off the main thread from the cached static geometry plus the current
## `nav_blockers` (e.g. after a door opened), then swaps the mesh in and emits [signal baked].
## Calls during a bake are coalesced into one more bake; [signal baked] is emitted only once
## no request is pending, so the result reflects every change made before the call.
func rebake() -> void:
	if _static_geometry == null:
		bake_now()
		return
	if _baking:
		_dirty = true
		return
	var root := _source_root()
	if root == null:
		return
	_baking = true
	_dirty = false
	var mesh := _new_mesh()
	var geometry := _with_blockers(mesh, root, _blocker_bodies())
	var region: WeakRef = weakref(self)
	var done := func() -> void:
		var node := region.get_ref() as RuntimeNavRegion
		if node != null:
			node._on_rebaked(mesh)
	NavigationServer3D.bake_from_source_geometry_data_async(
		mesh, geometry, func() -> void: done.call_deferred()
	)


func is_rebaking() -> bool:
	return _baking


## [method rebake] on every RuntimeNavRegion in [param tree].
static func rebake_all(tree: SceneTree) -> Array[RuntimeNavRegion]:
	var regions: Array[RuntimeNavRegion] = []
	for node in tree.get_nodes_in_group(GROUP):
		var region := node as RuntimeNavRegion
		region.rebake()
		regions.append(region)
	return regions


func _on_rebaked(mesh: NavigationMesh) -> void:
	_baking = false
	if _dirty:
		rebake()
		return
	_apply(mesh)


func _apply(mesh: NavigationMesh) -> void:
	navigation_mesh = mesh
	_ready_to_use = mesh.get_polygon_count() > 0
	if not _ready_to_use:
		push_warning("RuntimeNavRegion '%s': baked an empty navigation mesh." % name)
	baked.emit()


func _source_root() -> Node:
	var root := get_node_or_null(source) if not source.is_empty() else get_parent()
	if root == null:
		push_error("RuntimeNavRegion '%s': source not found." % name)
	return root


func _new_mesh() -> NavigationMesh:
	var mesh := NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = BAKE_MASK
	mesh.cell_size = CELL_SIZE
	mesh.cell_height = CELL_HEIGHT
	mesh.agent_radius = agent_radius
	mesh.agent_height = agent_height
	mesh.agent_max_climb = agent_max_climb
	mesh.agent_max_slope = agent_max_slope
	mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_EXPLICIT
	mesh.geometry_source_group_name = PARSE_GROUP
	return mesh


## Bodies in `nav_blockers` (closed doors, barricades, stations) that still collide.
func _blocker_bodies() -> Array[Node]:
	var bodies: Array[Node] = []
	if not is_inside_tree():
		return bodies
	for node in get_tree().get_nodes_in_group(NAV_BLOCKER_GROUP):
		var body := node as StaticBody3D
		if body != null and (body.collision_layer & BAKE_MASK) != 0:
			bodies.append(body)
	return bodies


## The cached static geometry plus [param blockers].
func _with_blockers(
	mesh: NavigationMesh, root: Node, blockers: Array[Node]
) -> NavigationMeshSourceGeometryData3D:
	var geometry := NavigationMeshSourceGeometryData3D.new()
	geometry.merge(_static_geometry)
	_parse_bodies(mesh, geometry, root, blockers)
	return geometry


## Only body nodes go through the parser: its CSG handler reads visual meshes from the GPU.
static func _parse_bodies(
	mesh: NavigationMesh,
	geometry: NavigationMeshSourceGeometryData3D,
	root: Node,
	bodies: Array[Node]
) -> void:
	if bodies.is_empty():
		return
	for body in bodies:
		body.add_to_group(PARSE_GROUP)
	# The parser clears its output, so parse into a scratch copy and merge.
	var parsed := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh, parsed, root)
	geometry.merge(parsed)
	for body in bodies:
		body.remove_from_group(PARSE_GROUP)


## Colliding root CSG shapes under [param root] (their collision is internal, not a body node).
static func _add_csg_faces(root: Node, geometry: NavigationMeshSourceGeometryData3D) -> void:
	var shapes: Array[Node] = root.find_children("*", "CSGShape3D", true, false)
	if root is CSGShape3D:
		shapes.append(root)
	for node in shapes:
		var csg := node as CSGShape3D
		if not csg.is_root_shape() or not csg.use_collision:
			continue
		if (csg.collision_layer & PhysicsLayers.WORLD) == 0:
			continue
		var shape := csg.bake_collision_shape()
		if shape != null:
			geometry.add_faces(shape.get_faces(), csg.global_transform)


func is_baked() -> bool:
	return _ready_to_use


func polygon_count() -> int:
	return navigation_mesh.get_polygon_count() if navigation_mesh != null else 0
