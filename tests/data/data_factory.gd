extends RefCounted
## Builders for valid, embedded (non-standalone) data objects used across data tests.


static func enemy(p_id: String = "test_enemy") -> EnemyData:
	var data := EnemyData.new()
	data.id = StringName(p_id)
	data.display_name = "Test Enemy"
	return data


static func entry(p_enemy: EnemyData = null, lo: int = 3, hi: int = 5) -> WaveEntry:
	var data := WaveEntry.new()
	data.enemy = p_enemy if p_enemy != null else enemy()
	data.count_min = lo
	data.count_max = hi
	return data


static func wave() -> WaveData:
	var data := WaveData.new()
	data.entries = [entry()]
	return data


static func wave_set(count: int = 12, p_id: String = "custom_set") -> WaveSet:
	var data := WaveSet.new()
	data.id = StringName(p_id)
	data.display_name = "Custom Set"
	for i in count:
		data.waves.append(wave())
	return data


static func settings() -> MatchSettings:
	var data := MatchSettings.new()
	data.id = &"test_settings"
	data.display_name = "Test Settings"
	data.wave_set = wave_set()
	return data


static func melee_weapon() -> WeaponData:
	var data := WeaponData.new()
	data.id = &"test_blade"
	data.display_name = "Test Blade"
	data.slot = WeaponData.Slot.MELEE
	data.melee_stats = MeleeStats.new()
	return data


static func firearm() -> WeaponData:
	var data := WeaponData.new()
	data.id = &"test_gun"
	data.display_name = "Test Gun"
	data.slot = WeaponData.Slot.FIREARM
	data.firearm_stats = FirearmStats.new()
	return data
