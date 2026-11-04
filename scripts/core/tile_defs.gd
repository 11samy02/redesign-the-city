extends RefCounted
## Static data for every tile type: homes with their households, the services citizens need,
## green space and streets. Quantities are for the 4-player construction site.

## Order matters: homes first, then services (COMMERCIAL..PARKING), then green and roads.
enum Kind {
	APT_S, APT_M, APT_L, STUDENT_S, STUDENT_L,
	COMMERCIAL, UNIVERSITY, LIBRARY, BOOKSHOP, PRINT_SHOP, COFFEE_SHOP, KIOSK, RESTAURANT,
	SUPERMARKET, MARKET, HOSPITAL, CLINIC, SCHOOL, PARKING,
	PARK, TREES, ROAD,
}

## Tiles that cover 2x2 squares of the 14x14 mat. Every other tile (and every road you can buy) covers 1x1.
const BIG_KINDS := [
	Kind.APT_L, Kind.STUDENT_L, Kind.UNIVERSITY, Kind.LIBRARY, Kind.HOSPITAL, Kind.SCHOOL,
	Kind.SUPERMARKET, Kind.RESTAURANT, Kind.PARK, Kind.PARKING,
]

const CAT_BUILDING := "Building"
const CAT_AMENITY := "Amenity"
const CAT_GREEN := "Green space"
const CAT_ROAD := "Road"

## Road tiles come in four street types, stored as the tile's "variant". All of them connect
## tiles like a plain road. "art" is the file prefix in assets/tiles. Variant 0 is the normal
## road (and the free roads). "suits" lists the roles (see roles.gd) that like the street.
const STREET_SHADED := 1
const STREET_PEDESTRIAN := 2
const STREET_BIKE := 3
const STREETS := [
	{"name": "Road", "cost": 1, "art": "road", "suits": [],
		"note": "", "effect": "Connects tiles so citizens can reach what they need."},
	{"name": "Shaded street", "cost": 3, "art": "road_shaded", "suits": ["older"],
		"note": "A road with trees built in.",
		"effect": "A road that counts as trees: it is always shaded and shades the roads next to it, +1 happiness for the homes beside it, pollution -1. Older residents like it."},
	{"name": "Pedestrian street", "cost": 2, "art": "road_pedestrian", "suits": ["child", "older"],
		"note": "A car-free street.",
		"effect": "Connects tiles like a road. Children and older residents like to walk along it."},
	{"name": "Bike lane", "cost": 2, "art": "road_bike", "suits": ["worker", "student"],
		"note": "A street with a bike lane.",
		"effect": "Connects tiles like a road. Workers and students like to cycle along it."},
]
## Variant of each of the 38 roads in the shop: 24 plain, 5 shaded, 5 pedestrian, 4 bike lanes.
const STREET_BAG := [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 3, 3, 3, 3]

## Tiles in the full construction site for four players. Planners buy 128 of them, so the rest keep
## the last picks of a round from being left with scraps (a smaller shop made 4-player games far harsher).
const BAG_SIZE := 222

## Households a home tile can hold. The tile's "variant" is the index into its list.
## "members" are the citizens' roles (see roles.gd), "qty" how many of that tile are in the shop and
## "art" the picture in assets/tiles: every household has its own building, so you can tell who lives
## there at a glance. Students live in the student residences (and one shared house), everyone else
## has homes of their own, and no home type repeats the household of another.
const HOUSEHOLDS := {
	Kind.APT_S: [
		{"name": "Worker", "members": ["worker"], "qty": 4, "art": "home_small_worker"},
		{"name": "Older person", "members": ["older"], "qty": 4, "art": "home_small_older"},
		{"name": "Resident with a disability", "members": ["access"], "qty": 5, "art": "home_small_access"},
		{"name": "International resident", "members": ["expat"], "qty": 5, "art": "home_small_expat"},
	],
	Kind.APT_M: [
		{"name": "Working couple", "members": ["worker", "worker"], "qty": 3, "art": "home_medium_working_couple"},
		{"name": "Older couple", "members": ["older", "older"], "qty": 3, "art": "home_medium_older_couple"},
		{"name": "Parent and child", "members": ["worker", "child"], "qty": 4, "art": "home_medium_parent_child"},
		{"name": "Carer and resident", "members": ["worker", "access"], "qty": 4, "art": "home_medium_carer"},
		{"name": "International couple", "members": ["expat", "expat"], "qty": 4, "art": "home_medium_expat_couple"},
	],
	Kind.APT_L: [
		{"name": "Family", "members": ["worker", "worker", "child"], "qty": 4, "art": "home_large_family"},
		{"name": "Three generations", "members": ["older", "worker", "child"], "qty": 4, "art": "home_large_three_generations"},
		{"name": "Shared house", "members": ["student", "access", "expat"], "qty": 3, "art": "home_large_shared_house"},
		{"name": "International family", "members": ["expat", "expat", "child"], "qty": 3, "art": "home_large_expat_family"},
	],
	Kind.STUDENT_S: [
		{"name": "Students", "members": ["student"], "qty": 8, "art": "student_small"},
	],
	Kind.STUDENT_L: [
		{"name": "Students", "members": ["student", "student"], "qty": 8, "art": "student_large"},
	],
}

const DEFS := {
	Kind.APT_S: {
		"name": "Small apartment", "cost": 3, "qty": 18, "citizens": 1, "category": CAT_BUILDING,
		"effect": "Houses 1 citizen. Check who lives there before you buy.",
		"objectives": ["O1", "O4"], "art": "home_small_worker",
	},
	Kind.APT_M: {
		"name": "Medium apartment", "cost": 5, "qty": 18, "citizens": 2, "category": CAT_BUILDING,
		"effect": "Houses 2 citizens. Check who lives there before you buy.",
		"objectives": ["O1", "O4"], "art": "home_medium_working_couple",
	},
	Kind.APT_L: {
		"name": "Large apartment", "cost": 7, "qty": 14, "citizens": 3, "category": CAT_BUILDING,
		"effect": "Houses 3 citizens. Check who lives there before you buy.",
		"objectives": ["O1", "O4"], "art": "home_large_family",
	},
	Kind.STUDENT_S: {
		"name": "Student residence (small)", "cost": 3, "qty": 8, "citizens": 1, "category": CAT_BUILDING,
		"effect": "Student housing for 1 student. Students need a university and a library.",
		"objectives": ["O1", "O4"], "art": "student_small",
	},
	Kind.STUDENT_L: {
		"name": "Student residence (large)", "cost": 5, "qty": 8, "citizens": 2, "category": CAT_BUILDING,
		"effect": "Student housing for 2 students. Students need a university and a library.",
		"objectives": ["O1", "O4"], "art": "student_large",
	},
	Kind.COMMERCIAL: {
		"name": "Commercial area", "cost": 5, "qty": 10, "citizens": 0, "category": CAT_AMENITY,
		"effect": "Shops, offices and trade. Workers need one within reach to get to work.",
		"objectives": ["O1", "O4"], "art": "commercial",
	},
	Kind.UNIVERSITY: {
		"name": "University", "cost": 8, "qty": 5, "citizens": 0, "category": CAT_AMENITY,
		"effect": "Lecture halls and labs. Students need one within reach.",
		"objectives": ["O1", "O4"], "art": "university",
	},
	Kind.LIBRARY: {
		"name": "Library", "cost": 5, "qty": 8, "citizens": 0, "category": CAT_AMENITY,
		"effect": "Quiet study space. Students need one within reach. Children like it too.",
		"objectives": ["O1", "O4"], "art": "library",
	},
	Kind.BOOKSHOP: {
		"name": "Bookshop", "cost": 4, "qty": 5, "citizens": 0, "category": CAT_AMENITY,
		"effect": "Students and children like having one within reach.",
		"objectives": ["O1", "O4"], "art": "bookshop",
	},
	Kind.PRINT_SHOP: {
		"name": "Print shop", "cost": 3, "qty": 5, "citizens": 0, "category": CAT_AMENITY,
		"effect": "Printing and copying. Students like having one within reach.",
		"objectives": ["O1", "O4"], "art": "print_shop",
	},
	Kind.COFFEE_SHOP: {
		"name": "Coffee shop", "cost": 3, "qty": 10, "citizens": 0, "category": CAT_AMENITY,
		"effect": "Students, workers and older residents like having one within reach.",
		"objectives": ["O1", "O4"], "art": "amenity_cafe",
	},
	Kind.KIOSK: {
		"name": "Kiosk", "cost": 2, "qty": 8, "citizens": 0, "category": CAT_AMENITY,
		"effect": "A corner shop. Workers and older residents like having one within reach.",
		"objectives": ["O1", "O4"], "art": "kiosk",
	},
	Kind.RESTAURANT: {
		"name": "Restaurant", "cost": 4, "qty": 8, "citizens": 0, "category": CAT_AMENITY,
		"effect": "Workers like having one within reach. Older residents dislike one right next door (noise).",
		"objectives": ["O1", "O4"], "art": "restaurant",
	},
	Kind.SUPERMARKET: {
		"name": "Supermarket", "cost": 5, "qty": 8, "citizens": 0, "category": CAT_AMENITY,
		"effect": "Groceries. Workers and older residents need a supermarket or a market within reach. A supermarket also gives +1 happiness to each citizen it serves.",
		"objectives": ["O1", "O4"], "art": "supermarket",
	},
	Kind.MARKET: {
		"name": "Market", "cost": 3, "qty": 5, "citizens": 0, "category": CAT_AMENITY,
		"effect": "Groceries. Meets the same need as a supermarket, but without its +1 happiness.",
		"objectives": ["O1", "O4"], "art": "amenity_market",
	},
	Kind.HOSPITAL: {
		"name": "Hospital", "cost": 8, "qty": 5, "citizens": 0, "category": CAT_AMENITY,
		"effect": "Health care. Older residents and residents with a disability need a clinic or a hospital within reach. A hospital also gives +1 happiness to each citizen it serves.",
		"objectives": ["O1", "O4"], "art": "hospital",
	},
	Kind.CLINIC: {
		"name": "Clinic", "cost": 4, "qty": 6, "citizens": 0, "category": CAT_AMENITY,
		"effect": "Health care. Meets the same need as a hospital, but without its +1 happiness.",
		"objectives": ["O1", "O4"], "art": "amenity_clinic",
	},
	Kind.SCHOOL: {
		"name": "School", "cost": 5, "qty": 8, "citizens": 0, "category": CAT_AMENITY,
		"effect": "Children need a school within reach.",
		"objectives": ["O1", "O4"], "art": "amenity_school",
	},
	Kind.PARKING: {
		"name": "Parking place", "cost": 2, "qty": 10, "citizens": 0, "category": CAT_AMENITY,
		"effect": "Everyone in Egkomi wants parking. Students, workers and older residents like one within reach. Children dislike it right next door (traffic).",
		"objectives": ["O1", "O4"], "art": "parking",
	},
	Kind.PARK: {
		"name": "Park", "cost": 4, "qty": 8, "citizens": 0, "category": CAT_GREEN,
		"effect": "+1 happiness for homes within 2 squares of it. Pollution -3. Shades adjacent roads. Children need a park within 2 squares of their home.",
		"objectives": ["O3", "O4"], "art": "park",
	},
	Kind.TREES: {
		"name": "Trees", "cost": 1, "qty": 9, "citizens": 0, "category": CAT_GREEN,
		"effect": "+1 happiness for orthogonal neighbours. Pollution -1. Shades adjacent roads.",
		"objectives": ["O3", "O4"], "art": "trees",
	},
	Kind.ROAD: {
		"name": "Road", "cost": 1, "qty": 38, "citizens": 0, "category": CAT_ROAD,
		"effect": "Connects tiles so citizens can reach what they need.",
		"objectives": ["O1", "O4"], "art": "road_15",
	},
}

## Shop sections, in the order they are shown. Every kind is in exactly one.
const GROUPS := [
	{"name": "Homes", "kinds": [Kind.APT_S, Kind.APT_M, Kind.APT_L, Kind.STUDENT_S, Kind.STUDENT_L]},
	{"name": "Study", "kinds": [Kind.UNIVERSITY, Kind.LIBRARY, Kind.BOOKSHOP, Kind.PRINT_SHOP]},
	{"name": "Care and school", "kinds": [Kind.HOSPITAL, Kind.CLINIC, Kind.SCHOOL]},
	{"name": "Work and shops", "kinds": [Kind.COMMERCIAL, Kind.SUPERMARKET, Kind.MARKET, Kind.KIOSK, Kind.COFFEE_SHOP, Kind.RESTAURANT]},
	{"name": "Green", "kinds": [Kind.PARK, Kind.TREES]},
	{"name": "Streets", "kinds": [Kind.ROAD, Kind.PARKING]},
]


static func info(kind: int) -> Dictionary:
	return DEFS[kind]


static func cost(kind: int) -> int:
	return DEFS[kind]["cost"]


## What a placed or shop tile costs: like cost(), but a street type has its own price.
static func tile_cost(tile: Dictionary) -> int:
	if tile["kind"] == Kind.ROAD:
		return STREETS[tile.get("variant", 0)]["cost"]
	return DEFS[tile["kind"]]["cost"]


static func is_special_street(tile: Dictionary) -> bool:
	return tile["kind"] == Kind.ROAD and tile.get("variant", 0) > 0


## Trees, and the shaded street, which has trees built in: they cut pollution by 1, cheer up
## the 4 homes next to them and shade the roads next to them.
static func is_tree_like(tile) -> bool:
	if tile == null:
		return false
	return tile["kind"] == Kind.TREES or (tile["kind"] == Kind.ROAD and tile.get("variant", 0) == STREET_SHADED)


## Roles that will like this street (empty for everything but the special streets).
static func street_suits(tile: Dictionary) -> Array:
	if tile["kind"] != Kind.ROAD:
		return []
	return STREETS[tile.get("variant", 0)]["suits"]


## How many squares of the mat a kind covers along each side: 1 (a 1:1 tile) or 2 (a 2:2 tile).
static func kind_size(kind: int) -> int:
	return 2 if kind in BIG_KINDS else 1


## The same for a tile. Only a prefixed street can be a 2:2 road ("big").
static func footprint(tile: Dictionary) -> int:
	if tile.get("big", false):
		return 2
	return kind_size(tile["kind"])


## "1:1" or "2:2".
static func size_label(tile: Dictionary) -> String:
	var n := footprint(tile)
	return "%d:%d" % [n, n]


static func citizens(kind: int) -> int:
	return DEFS[kind]["citizens"]


static func is_home(kind: int) -> bool:
	return kind >= Kind.APT_S and kind <= Kind.STUDENT_L


## A building citizens walk to: shops, study places, health, school, workplaces and parking.
static func is_service(kind: int) -> bool:
	return kind >= Kind.COMMERCIAL and kind <= Kind.PARKING


## Roles of the citizens living in a home tile, one entry per citizen.
static func members(tile: Dictionary) -> Array:
	var list: Array = HOUSEHOLDS.get(tile["kind"], [])
	if list.is_empty():
		return []
	return list[clampi(tile.get("variant", 0), 0, list.size() - 1)]["members"]


static func household_name(tile: Dictionary) -> String:
	var list: Array = HOUSEHOLDS.get(tile["kind"], [])
	if list.is_empty():
		return ""
	return list[clampi(tile.get("variant", 0), 0, list.size() - 1)]["name"]


static func make(kind: int, variant := 0) -> Dictionary:
	return {"kind": kind, "variant": variant}


## Display name: the building (Coffee shop, Hospital...), a street type, or "Free road".
static func display_name(tile: Dictionary) -> String:
	if tile.get("free", false):
		return "Free road"
	if tile["kind"] == Kind.ROAD:
		return STREETS[tile.get("variant", 0)]["name"]
	return DEFS[tile["kind"]]["name"]


static func art_path(tile: Dictionary, road_mask := 15) -> String:
	var kind: int = tile["kind"]
	var art: String = DEFS[kind]["art"]
	if HOUSEHOLDS.has(kind):
		var list: Array = HOUSEHOLDS[kind]
		art = list[clampi(tile.get("variant", 0), 0, list.size() - 1)]["art"]
	if kind == Kind.ROAD:
		art = "%s_%d" % [STREETS[tile.get("variant", 0)]["art"], road_mask]
	return "res://assets/tiles/%s.svg" % art


static func group_of(kind: int) -> int:
	for g in GROUPS.size():
		if kind in GROUPS[g]["kinds"]:
			return g
	return GROUPS.size()


## Sorts tiles into shop order: by section, by position inside the section, then by variant.
static func sort_key(tile: Dictionary) -> int:
	var g := group_of(tile["kind"])
	var pos := 0
	if g < GROUPS.size():
		pos = GROUPS[g]["kinds"].find(tile["kind"])
	return g * 100000 + pos * 1000 + tile.get("variant", 0)


## The 144 shop tiles: every household and street type in the quantities above.
static func full_bag() -> Array:
	var bag: Array = []
	for kind in DEFS:
		if HOUSEHOLDS.has(kind):
			var list: Array = HOUSEHOLDS[kind]
			for v in list.size():
				for i in list[v]["qty"]:
					bag.append(make(kind, v))
		elif kind == Kind.ROAD:
			for variant in STREET_BAG:
				bag.append(make(kind, variant))
		else:
			for i in DEFS[kind]["qty"]:
				bag.append(make(kind))
	return bag
