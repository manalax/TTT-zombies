class_name RuntimeNavRegion
extends NavigationRegion3D
## Bakes its navigation mesh right after it enters the tree (docs/adr/0008-enemy-ai.md), from
## the collision geometry under [member source]: static colliders on WORLD (e.g. invisible stair
## ramps), bodies in the `nav_blockers` group anywhere in the scene (closed doors), and the
## collision faces of colliding CSG shapes (greybox), which the collider parser does not see.
## Visual meshes are never parsed (that would read them back from the GPU).
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

## Root of the geometry to bake from. Empty = this node's parent.
@export var source: NodePath
@export var bake_on_ready: bool = true
@export_range(0.25, 2.0, 0.25, "suffix:m") var agent_radius: float = 0.5
@export_range(0.5, 4.0, 0.25, "suffix:m") var agent_height: float = 1.75
@export_range(0.0, 1.0, 0.25, "suffix:m") var agent_max_climb: float = 0.25
@export_range(0.0, 89.0, 1.0, "suffix:°") var agent_max_slope: float = 45.0

var _ready_to_use: bool = false


func _ready() -> void:
	if bake_on_ready:
		bake_now.call_deferred()


## Parses and bakes on the calling thread, then emits [signal baked].
func bake_now() -> void:
	var root := get_node_or_null(source) if not source.is_empty() else get_parent()
	if root == null:
		push_error("RuntimeNavRegion '%s': source not found." % name)
		return
	var mesh := NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = PhysicsLayers.WORLD | PhysicsLayers.BARRIER
	mesh.cell_size = CELL_SIZE
	mesh.cell_height = CELL_HEIGHT
	mesh.agent_radius = agent_radius
	mesh.agent_height = agent_height
	mesh.agent_max_climb = agent_max_climb
	mesh.agent_max_slope = agent_max_slope
	var geometry := NavigationMeshSourceGeometryData3D.new()
	# Only body nodes go through the parser: its CSG handler reads visual meshes from the GPU.
	var bodies := root.find_children("*", "StaticBody3D", true, false)
	# Closed doors (and other blockers) count as walls wherever they are in the scene.
	if is_inside_tree():
		for node in get_tree().get_nodes_in_group(&"nav_blockers"):
			if node is StaticBody3D and not node in bodies:
				bodies.append(node)
	for body in bodies:
		body.add_to_group(PARSE_GROUP)
	mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_EXPLICIT
	mesh.geometry_source_group_name = PARSE_GROUP
	if not bodies.is_empty():
		NavigationServer3D.parse_source_geometry_data(mesh, geometry, root)
	for body in bodies:
		body.remove_from_group(PARSE_GROUP)
	_add_csg_faces(root, geometry)
	NavigationServer3D.bake_from_source_geometry_data(mesh, geometry)
	navigation_mesh = mesh
	_ready_to_use = mesh.get_polygon_count() > 0
	if not _ready_to_use:
		push_warning("RuntimeNavRegion '%s': baked an empty navigation mesh." % name)
	baked.emit()


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
