extends GdUnitTestSuite
## F003: LootEntry / LootTable validation and weighted picks.

const DataFactory := preload("res://tests/data/data_factory.gd")


func _table(weights: Array[float]) -> LootTable:
	var table := LootTable.new()
	table.id = &"test_loot"
	table.display_name = "Test Loot"
	for weight in weights:
		var entry := LootEntry.new()
		entry.kind = LootEntry.Kind.POINTS
		entry.weight = weight
		table.entries.append(entry)
	return table


func test_valid_table() -> void:
	assert_bool(_table([1.0, 2.0]).validate().is_empty()).is_true()


func test_table_errors() -> void:
	assert_bool(_table([]).validate().mentions("needs at least one entry")).is_true()
	assert_bool(_table([0.0, 0.0]).validate().mentions("total weight")).is_true()


func test_entry_rules() -> void:
	var table := _table([1.0])
	table.entries[0].kind = LootEntry.Kind.WEAPON
	assert_bool(table.validate().mentions("weapon: required")).is_true()
	table.entries[0].kind = LootEntry.Kind.AMMO
	table.entries[0].weapon = DataFactory.firearm()
	assert_bool(table.validate().mentions("is ignored")).is_true()
	table.entries[0].weapon = null
	table.entries[0].qty_min = 5
	table.entries[0].qty_max = 1
	assert_bool(table.validate().mentions("qty_min")).is_true()


func test_pick_follows_weights() -> void:
	var table := _table([5.0, 3.0, 1.0, 0.0])
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var counts := [0, 0, 0, 0]
	var rolls := 10000
	for i in rolls:
		counts[table.entries.find(table.pick(rng))] += 1
	assert_float(float(counts[0]) / rolls).is_equal_approx(5.0 / 9.0, 0.02)
	assert_float(float(counts[1]) / rolls).is_equal_approx(3.0 / 9.0, 0.02)
	assert_float(float(counts[2]) / rolls).is_equal_approx(1.0 / 9.0, 0.02)
	assert_int(counts[3]).is_equal(0)


func test_pick_is_deterministic_for_seed() -> void:
	var table := _table([1.0, 1.0, 1.0])
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = 99
	b.seed = 99
	for i in 50:
		assert_object(table.pick(a)).is_same(table.pick(b))


func test_shipped_table_is_valid() -> void:
	var table: LootTable = load("res://content/world/loot/crypt_common/crypt_common.tres")
	var report := table.validate()
	assert_bool(report.is_empty()).override_failure_message(report.format()).is_true()
