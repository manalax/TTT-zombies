class_name TracerDraw
extends MeshInstance3D
## Short-lived bullet tracer lines (local feedback). One instance per scene; firearms submit to
## it through the static [method submit] (a no-op when no instance exists, e.g. in tests).

const LIFETIME_S := 0.08

static var _instance: TracerDraw

var _lines: Array[Dictionary] = []
var _mesh := ImmediateMesh.new()


static func submit(from: Vector3, to: Vector3) -> void:
	if _instance != null:
		_instance._lines.append({"from": from, "to": to, "age": 0.0})


func _ready() -> void:
	_instance = self
	mesh = _mesh
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.9, 0.6)
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
		_mesh.surface_add_vertex(line["from"])
		_mesh.surface_add_vertex(line["to"])
	_mesh.surface_end()
