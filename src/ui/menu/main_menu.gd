class_name MainMenu
extends Control
## Placeholder start menu (F056): Play (disabled until the placeholder level exists), Test Arena
## (the dev sandbox) and Exit. Keyboard/controller focus starts on the first enabled button.

@onready var play_button: Button = %PlayButton
@onready var arena_button: Button = %TestArenaButton
@onready var exit_button: Button = %ExitButton
@onready var play_note: Label = %PlayNote
@onready var version_label: Label = %Version


func _ready() -> void:
	var playable := Game.PLAY_LEVEL != ""
	play_button.disabled = not playable
	play_note.visible = not playable
	play_button.pressed.connect(func() -> void: Game.load_level(Game.PLAY_LEVEL))
	arena_button.pressed.connect(func() -> void: Game.load_level(Game.TEST_ARENA))
	exit_button.pressed.connect(Game.quit)
	version_label.text = "Godot %s" % Engine.get_version_info()["string"]
	(play_button if playable else arena_button).grab_focus()
