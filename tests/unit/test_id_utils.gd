extends "res://addons/gut/test.gd"


func test_normalize_lowercases_the_name():
	assert_eq(IdUtils.normalize("Axe"), "axe")


func test_normalize_replaces_spaces_with_dashes():
	assert_eq(IdUtils.normalize("Assault Rifle"), "assault-rifle")


func test_normalize_trims_surrounding_whitespace():
	assert_eq(IdUtils.normalize("  Shotgun  "), "shotgun")


func test_normalize_is_idempotent():
	var once = IdUtils.normalize("Assault Rifle")
	assert_eq(IdUtils.normalize(once), once)


func test_normalize_is_case_insensitive():
	assert_eq(IdUtils.normalize("Axe"), IdUtils.normalize("AXE"))
