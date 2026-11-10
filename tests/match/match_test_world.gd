extends RefCounted
## A flat 80 m world for the F019 suites: a player at the origin (physics stepped by hand), an
## EnemyRegistry, three spawn points (one too close: 5 m; two far: 20 m, 25 m), and a
## MatchManager with its own MatchSettings copy (test_short waves, short intermission).

const World := preload("res://tests/enemies/enemy_test_world.gd")


static func build(wave_set_path: String, intermission_s: float = 0.5) -> Dictionary:
	var root := World.world(80.0)
	var registry := EnemyRegistry.new()
	registry.name = "Enemies"
	root.add_child(registry)
	for at: Vector3 in [Vector3(5, 0.05, 0), Vector3(20, 0.05, 0), Vector3(0, 0.05, -25)]:
		var point := EnemySpawnPoint.new()
		point.position = at
		root.add_child(point)
	var spawn := Marker3D.new()
	spawn.name = "PlayerSpawn"
	spawn.position = Vector3(0, 0.05, 2)
	root.add_child(spawn)
	var manager := MatchManager.new()
	manager.name = "MatchManager"
	var settings := Settings.match_settings.duplicate() as MatchSettings
	settings.wave_set = load(wave_set_path)
	settings.intermission_s = intermission_s
	settings.match_seed = 42
	manager.settings = settings
	manager.player_spawn = ^"../PlayerSpawn"
	root.add_child(manager)
	return {"root": root, "registry": registry, "manager": manager, "settings": settings}
