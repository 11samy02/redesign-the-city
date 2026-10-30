extends RefCounted
## Static data for every tile type, taken from the concept document's tile set.

enum Kind { APT_S, APT_M, APT_L, AMENITY, PARK, TREES, ROAD }

const CAT_BUILDING := "Building"
const CAT_AMENITY := "Amenity"
const CAT_GREEN := "Green space"
const CAT_ROAD := "Road"

const AMENITY_VARIANTS := ["Café", "Clinic", "School", "Market"]
const AMENITY_ART := ["cafe", "clinic", "school", "market"]

## Tiles in the full construction site (the 6x6 grid).
const BAG_SIZE := 36

const DEFS := {
	Kind.APT_S: {
		"name": "Small apartment", "cost": 2, "qty": 4, "citizens": 1, "category": CAT_BUILDING,
		"effect": "Houses 1 citizen.",
		"objectives": ["O1", "O4"], "art": "apartment_small",
	},
	Kind.APT_M: {
		"name": "Medium apartment", "cost": 4, "qty": 4, "citizens": 2, "category": CAT_BUILDING,
		"effect": "Houses 2 citizens.",
		"objectives": ["O1", "O4"], "art": "apartment_medium",
	},
	Kind.APT_L: {
		"name": "Large apartment", "cost": 6, "qty": 3, "citizens": 3, "category": CAT_BUILDING,
		"effect": "Houses 3 citizens.",
		"objectives": ["O1", "O4"], "art": "apartment_large",
	},
	Kind.AMENITY: {
		"name": "Amenity", "cost": 4, "qty": 8, "citizens": 0, "category": CAT_AMENITY,
		"effect": "+1 happiness for every citizen connected to it by road. Costs 1 point at the end if no home reaches it.",
		"objectives": ["O1", "O4"], "art": "amenity_cafe",
	},
	Kind.PARK: {
		"name": "Park", "cost": 3, "qty": 4, "citizens": 0, "category": CAT_GREEN,
		"effect": "+1 happiness in its 3x3 area. Pollution -3. Shades adjacent roads.",
		"objectives": ["O3", "O4"], "art": "park",
	},
	Kind.TREES: {
		"name": "Trees", "cost": 1, "qty": 5, "citizens": 0, "category": CAT_GREEN,
		"effect": "+1 happiness for orthogonal neighbours. Pollution -1. Shades adjacent roads.",
		"objectives": ["O3", "O4"], "art": "trees",
	},
	Kind.ROAD: {
		"name": "Road", "cost": 1, "qty": 8, "citizens": 0, "category": CAT_ROAD,
		"effect": "Connects tiles so citizens can reach amenities.",
		"objectives": ["O1", "O4"], "art": "road_15",
	},
}


static func info(kind: int) -> Dictionary:
	return DEFS[kind]


static func cost(kind: int) -> int:
	return DEFS[kind]["cost"]


static func citizens(kind: int) -> int:
	return DEFS[kind]["citizens"]


static func is_apartment(kind: int) -> bool:
	return kind == Kind.APT_S or kind == Kind.APT_M or kind == Kind.APT_L


static func make(kind: int, variant := 0) -> Dictionary:
	return {"kind": kind, "variant": variant}


## Display name, including the amenity flavour (Café, Clinic...).
static func display_name(tile: Dictionary) -> String:
	if tile["kind"] == Kind.AMENITY:
		return AMENITY_VARIANTS[tile.get("variant", 0) % AMENITY_VARIANTS.size()]
	if tile.get("free", false):
		return "Free road"
	return DEFS[tile["kind"]]["name"]


static func art_path(tile: Dictionary, road_mask := 15) -> String:
	var kind: int = tile["kind"]
	var art: String = DEFS[kind]["art"]
	if kind == Kind.AMENITY:
		art = "amenity_" + AMENITY_ART[tile.get("variant", 0) % AMENITY_ART.size()]
	elif kind == Kind.ROAD:
		art = "road_%d" % road_mask
	return "res://assets/tiles/%s.svg" % art


## The 36 shop tiles. Amenities cycle through their four flavours.
static func full_bag() -> Array:
	var bag: Array = []
	for kind in DEFS:
		for i in DEFS[kind]["qty"]:
			bag.append(make(kind, i % AMENITY_VARIANTS.size() if kind == Kind.AMENITY else 0))
	return bag
