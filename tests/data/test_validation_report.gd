extends GdUnitTestSuite
## F003: ValidationReport behaviour.


func test_errors_and_warnings_are_separated() -> void:
	var report := ValidationReport.new()
	assert_bool(report.is_empty()).is_true()
	report.warn("Src", "field", "hmm")
	assert_bool(report.has_errors()).is_false()
	report.error("Src", "field", "broken")
	assert_bool(report.has_errors()).is_true()
	assert_int(report.get_errors().size()).is_equal(1)
	assert_int(report.get_warnings().size()).is_equal(1)


func test_format_includes_source_and_field() -> void:
	var report := ValidationReport.new()
	report.error("WeaponData:sword", "reach_m", "must be > 0")
	report.warn("WeaponData:sword", "", "odd")
	assert_str(report.format()).is_equal(
		"ERROR WeaponData:sword.reach_m: must be > 0\nWARNING WeaponData:sword: odd"
	)


func test_check_helpers() -> void:
	var report := ValidationReport.new()
	report.check_positive("S", "a", 1.0)
	report.check_min("S", "b", 0.0, 0.0)
	report.check_range("S", "c", 0.5, 0.0, 1.0)
	assert_bool(report.is_empty()).is_true()
	report.check_positive("S", "d", 0.0)
	report.check_min("S", "e", -1.0, 0.0)
	report.check_range("S", "f", 2.0, 0.0, 1.0)
	assert_int(report.get_errors().size()).is_equal(3)
	assert_bool(report.mentions("S.f")).is_true()


func test_merge() -> void:
	var a := ValidationReport.new()
	var b := ValidationReport.new()
	a.warn("A", "", "w")
	b.error("B", "", "e")
	a.merge(b)
	assert_int(a.get_issues().size()).is_equal(2)
	assert_bool(a.has_errors()).is_true()
