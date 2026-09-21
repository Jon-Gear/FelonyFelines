extends Reference
class_name DropWeights


# Rescales a drop-weight table so its integer weights sum to at most 100.
# A positive weight that would round away to zero is promoted to 1 so an item
# can never be rounded out of the drop table entirely.
#
# Pure: returns a new table of integer ticket counts and leaves the caller's
# table untouched.
static func normalize(weights: Dictionary) -> Dictionary:
	var total := 0
	for key in weights:
		total += int(round(weights[key]))

	var multiplier := 1.0
	if total > 100:
		multiplier = 100.0 / total

	var normalized := {}
	for key in weights:
		var weighted = multiplier * float(weights[key])
		if weighted > 0 and round(weighted) == 0:
			normalized[key] = 1
		else:
			normalized[key] = int(round(weighted))

	return normalized
