extends Reference
class_name IdUtils


# Stable, case-insensitive identifier derived from a display/asset name.
# This is the single source of the normalize-IDs contract documented in
# docs/CONVENTIONS.md and resources/README.md:
#     name.strip_edges().to_lower().replace(" ", "-")
static func normalize(name: String) -> String:
	return name.strip_edges().to_lower().replace(" ", "-")
