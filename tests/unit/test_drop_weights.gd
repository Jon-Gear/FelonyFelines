extends "res://addons/gut/test.gd"


func test_normalize_leaves_weights_that_already_sum_to_at_most_100():
	var normalized = DropWeights.normalize({"axe": 4, "medkit": 5})
	assert_eq(normalized["axe"], 4)
	assert_eq(normalized["medkit"], 5)


func test_normalize_scales_weights_that_sum_over_100():
	var normalized = DropWeights.normalize({"axe": 60, "shotgun": 60})
	assert_eq(normalized["axe"], 50)
	assert_eq(normalized["shotgun"], 50)


func test_normalize_promotes_positive_weight_that_would_round_to_zero():
	var normalized = DropWeights.normalize({"common": 1, "rare": 0.4})
	assert_eq(normalized["rare"], 1)


func test_normalize_keeps_zero_weight_at_zero():
	var normalized = DropWeights.normalize({"common": 1, "never": 0})
	assert_eq(normalized["never"], 0)


func test_normalize_does_not_mutate_its_input():
	var weights = {"axe": 60, "shotgun": 60}
	DropWeights.normalize(weights)
	assert_eq(weights["axe"], 60)
	assert_eq(weights["shotgun"], 60)
