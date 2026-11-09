class_name MeleeDebugDraw
extends MeshInstance3D
## F8 debug view of melee sweeps: blade segments (green), segments that hit (red) and clang
## points (yellow), each shown for LIFETIME_S. Add one instance to the scene; sweeps submit to it.

const LIFETIME_S := 1.0

static var enabled: bool = false
static var _instance: MeleeDebugDraw

var _lines: Array[Dictionary] = []
var _mesh := ImmediateMesh.new()


static func submit(step: MeleeSweep.Step) -> void:
	if not enabled or _instance == null or step.segments.is_empty():
		return
	for segment in step.segments:
		var color := Color.GREEN
		if segment.clang:
			color = Color.YELLOW
		elif segment.hit:
			color = Color.RED
		_instance._lines.append(
			{"from": segment.from, "to": segment.to, "color": color, "age": 0.0}
		)


func _ready() -> void:
	_instance = self
	mesh = _mesh
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = true
	material_override = material


func _exit_tree() -> void:
	if _instance == self:
		_instance = null


func _process(delta: float) -> void:
	_mesh.clear_surfaces()
	var kept: Array[Dictionary] = []
	for line in _lines:
		line["age"] = float(line["age"]) + delta
		if float(line["age"]) < LIFETIME_S:
			kept.append(line)
	_lines = kept
	if _lines.is_empty():
		return
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for line in _lines:
		_mesh.surface_set_color(line["color"])
		_mesh.surface_add_vertex(line["from"])
		_mesh.surface_add_vertex(line["to"])
	_mesh.surface_end()
