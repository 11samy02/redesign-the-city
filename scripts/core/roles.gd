extends RefCounted
## The six kinds of citizen. A home's household decides which roles live in it (see
## TileDefs.HOUSEHOLDS), and each role has its own needs, likes and dislike.

const TileDefs = preload("res://scripts/core/tile_defs.gd")

const STUDENT := "student"
const WORKER := "worker"
const CHILD := "child"
const OLDER := "older"
## A resident with a disability: needs care and green space close by, long walks hurt more.
const ACCESS := "access"
## Someone who moved to Egkomi for work, from an embassy or an international company.
const EXPAT := "expat"
const IDS := [STUDENT, WORKER, CHILD, OLDER, ACCESS, EXPAT]

## "needs": two need ids (see NEEDS); a met need lifts happiness, an unmet one drags it down and
## becomes the citizen's complaint. "like_kinds" / "like_streets": reaching one of them adds +1
## (once). "dislike_kind": a tile of that kind right next to the home costs 1 (-1 for none).
## "heat_factor": how hard a long walk with no shade hits this role.
const DEFS := {
	STUDENT: {
		"name": "Student", "plural": "Students", "color": "#4F8BEA", "icon": "res://assets/ui/role_student.svg",
		"needs": ["university", "library"],
		"like_kinds": [TileDefs.Kind.COFFEE_SHOP, TileDefs.Kind.PRINT_SHOP, TileDefs.Kind.BOOKSHOP, TileDefs.Kind.PARKING],
		"like_streets": [TileDefs.STREET_BIKE],
		"dislike_kind": -1, "heat_factor": 1,
	},
	WORKER: {
		"name": "Worker", "plural": "Workers", "color": "#E5A12B", "icon": "res://assets/ui/role_worker.svg",
		"needs": ["work", "groceries"],
		"like_kinds": [TileDefs.Kind.COFFEE_SHOP, TileDefs.Kind.RESTAURANT, TileDefs.Kind.KIOSK, TileDefs.Kind.PARKING],
		"like_streets": [TileDefs.STREET_BIKE],
		"dislike_kind": -1, "heat_factor": 1,
	},
	CHILD: {
		"name": "Child", "plural": "Children", "color": "#E2569C", "icon": "res://assets/ui/role_child.svg",
		"needs": ["school", "park"],
		"like_kinds": [TileDefs.Kind.LIBRARY, TileDefs.Kind.BOOKSHOP],
		"like_streets": [TileDefs.STREET_PEDESTRIAN],
		"dislike_kind": TileDefs.Kind.PARKING, "heat_factor": 1,
	},
	OLDER: {
		"name": "Older resident", "plural": "Older residents", "color": "#8C6CC4", "icon": "res://assets/ui/role_older.svg",
		"needs": ["health", "groceries"],
		"like_kinds": [TileDefs.Kind.COFFEE_SHOP, TileDefs.Kind.KIOSK, TileDefs.Kind.PARKING],
		"like_streets": [TileDefs.STREET_SHADED, TileDefs.STREET_PEDESTRIAN],
		"dislike_kind": TileDefs.Kind.RESTAURANT, "heat_factor": 2,
	},
	ACCESS: {
		"name": "Resident with a disability", "plural": "Residents with a disability", "color": "#2FA3A0", "icon": "res://assets/ui/role_access.svg",
		"needs": ["health", "park"],
		"like_kinds": [TileDefs.Kind.KIOSK, TileDefs.Kind.PARKING],
		"like_streets": [TileDefs.STREET_PEDESTRIAN, TileDefs.STREET_SHADED],
		"dislike_kind": -1, "heat_factor": 2,
	},
	EXPAT: {
		"name": "Expat", "plural": "Expats", "color": "#D8682B", "icon": "res://assets/ui/role_expat.svg",
		"needs": ["work", "dining"],
		"like_kinds": [TileDefs.Kind.COFFEE_SHOP, TileDefs.Kind.PARKING, TileDefs.Kind.SCHOOL],
		"like_streets": [TileDefs.STREET_BIKE],
		"dislike_kind": -1, "heat_factor": 1,
	},
}

## What can satisfy each need. "area" needs are met by a tile in the home's 3x3 area (the park
## rule), the others by a road route to a tile of one of the kinds.
const NEEDS := {
	"university": {"name": "University", "kinds": [TileDefs.Kind.UNIVERSITY], "area": false, "missing": "No university within reach"},
	"library": {"name": "Library", "kinds": [TileDefs.Kind.LIBRARY], "area": false, "missing": "No library within reach"},
	"work": {"name": "Commercial area", "kinds": [TileDefs.Kind.COMMERCIAL], "area": false, "missing": "No workplace within reach"},
	"groceries": {"name": "Supermarket or market", "kinds": [TileDefs.Kind.SUPERMARKET, TileDefs.Kind.MARKET], "area": false, "missing": "No supermarket or market within reach"},
	"school": {"name": "School", "kinds": [TileDefs.Kind.SCHOOL], "area": false, "missing": "No school within reach"},
	"health": {"name": "Clinic or hospital", "kinds": [TileDefs.Kind.CLINIC, TileDefs.Kind.HOSPITAL], "area": false, "missing": "No clinic or hospital within reach"},
	"dining": {"name": "Restaurant", "kinds": [TileDefs.Kind.RESTAURANT], "area": false, "missing": "No restaurant within reach"},
	"park": {"name": "Park","kinds": [TileDefs.Kind.PARK], "area": true, "missing": "No park nearby"},
}


static func need_kinds(need_id: String) -> Array:
	return NEEDS[need_id]["kinds"].duplicate()


static func missing_text(need_id: String) -> String:
	return NEEDS[need_id]["missing"]


static func role_color(role: String) -> Color:
	return Color(DEFS[role]["color"])
