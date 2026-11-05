extends Control
## Entry scene. Placeholder until the main menu exists.


func _ready() -> void:
	var version: String = Engine.get_version_info()["string"]
	print("Vigil of Ash skeleton running on Godot %s" % version)
