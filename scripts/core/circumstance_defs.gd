extends RefCounted
## Static data and rules for the 32 hidden circumstance cards. One card is revealed at the start
## of each round; a game draws 8 of the 32.

const TileDefs = preload("res://scripts/core/tile_defs.gd")

## Every card hits everyone and changes only happiness, points or gold, never tiles.
## Happiness effects stay on until the end of the game; gold effects happen once, when revealed.

const FAMILY_WEATHER := "Weather"
const FAMILY_CITY := "City"

const BUDGET_CUT := 8
const GRANT_BASE := 6
const GRANT_PER_GREEN := 2
## Dust storm: a city with pollution above this level loses 1 more per citizen.
const DUST_SAFE_LEVEL := 8
## Attractor cards: a place that serves at least this many homes gives +1 point.
const ATTRACTOR_MIN_HOMES := 3
## Open day: a university that serves at least this many student homes gives +1 point.
const OPEN_DAY_MIN_STUDENT_HOMES := 2
const BUSINESS_GOLD_PER_COMMERCIAL := 2
const TAX_REFUND := 8
## Smog alert: with pollution above this level every citizen without a park loses 1 happiness.
const SMOG_LEVEL := 5
## Farmers' market: a market or supermarket this many roads away or closer pleases a citizen.
const MARKET_REACH := 2
## Road subsidy pays for this many road tiles at most, pipe repairs for this many homes.
const ROAD_SUBSIDY_CAP := 8
const PIPE_REPAIR_CAP := 6

const IDS := ["heatwave", "flash_flood", "dust_storm", "nice_weather", "budget_cut", "grant",
	"road_works", "new_attractor", "population_growth",
	"exam_season", "flu_wave", "supply_shortage", "back_to_school", "parking_shortage",
	"traffic_jam", "drought", "tourist_season", "health_campaign", "open_day",
	"business_boom", "tax_refund", "bike_week", "street_festival", "remote_work",
	"autumn_rain", "smog_alert", "cold_snap", "farmers_market", "science_fair", "road_subsidy", "bus_strike", "pipe_repairs"]

## Which complaint a card that hurts a citizen counts towards (see Scoring._member).
const NEED_CARDS := ["exam_season", "flu_wave", "supply_shortage", "back_to_school", "parking_shortage"]
const WALK_CARDS := ["heatwave", "flash_flood", "road_works", "bus_strike"]
const GREEN_CARDS := ["drought", "cold_snap"]

## "rule" is what the card does, "story" the Egkomi flavour, "tip" what it rewards or punishes,
## "badge" the short number printed in the corner of the card ("g" means gold), "key" the words of
## the rule that are highlighted on the card, "icon" the small picture (in assets/ui) shown next to them.
const DEFS := {
	"heatwave": {
		"title": "Heatwave", "family": FAMILY_WEATHER, "art": "circumstance_heatwave", "badge": "-1", "key": "1 extra happiness", "icon": "citizen", "tint": "#E8743B",
		"story": "40 degrees over Nicosia. The sun-baked streets are empty at noon.",
		"rule": "Citizens with a long walk and no shade lose 1 extra happiness.",
		"tip": "Punishes unshaded walks of 3 or more roads.",
	},
	"flash_flood": {
		"title": "Flash flood", "family": FAMILY_WEATHER, "art": "circumstance_flash_flood", "badge": "-1", "key": "lose 1 happiness", "icon": "citizen", "tint": "#3A8DDE",
		"story": "A winter downpour sends water down the streets of Egkomi.",
		"rule": "Citizens with a long walk and no park or trees next to their home lose 1 happiness.",
		"tip": "Green space soaks up the water. Long walks suffer.",
	},
	"dust_storm": {
		"title": "Dust storm", "family": FAMILY_WEATHER, "art": "circumstance_dust_storm", "badge": "-1", "key": "loses 1 happiness", "icon": "citizen", "tint": "#C9A25B",
		"story": "Sahara dust turns the sky orange and nobody wants to be outside.",
		"rule": "If your pollution is above 8, every citizen loses 1 happiness.",
		"tip": "Rewards a city with plenty of parks and trees.",
	},
	"nice_weather": {
		"title": "Nice weather", "family": FAMILY_WEATHER, "art": "circumstance_nice_weather", "badge": "+1", "key": "gain 1 happiness", "icon": "citizen", "tint": "#7FB346",
		"story": "A mild spring week. Everyone wants to walk.",
		"rule": "Citizens with a shaded route to a place they use gain 1 happiness.",
		"tip": "Rewards shaded walking routes.",
	},
	"budget_cut": {
		"title": "Budget cut", "family": FAMILY_CITY, "art": "circumstance_budget_cut", "badge": "-8g", "key": "loses 8 gold", "icon": "coin", "tint": "#B9810F",
		"story": "The municipality tightens its belt. Nobody saw it coming.",
		"rule": "Every planner loses 8 gold.",
		"tip": "Rewards planners who keep some gold in reserve.",
	},
	"grant": {
		"title": "Green grant", "family": FAMILY_CITY, "art": "circumstance_grant", "badge": "+6g", "key": "6 gold, plus 2 gold", "icon": "coin", "tint": "#5E9B3A",
		"story": "A national fund pays for greener, more walkable streets.",
		"rule": "Every planner gets 6 gold, plus 2 gold for each park and tree on their mat.",
		"tip": "Rewards planners who already built green space.",
	},
	"road_works": {
		"title": "Road works", "family": FAMILY_CITY, "art": "circumstance_road_works", "badge": "-1", "key": "lose 1 happiness", "icon": "citizen", "tint": "#E0A030",
		"story": "The main street is dug up and every trip takes longer.",
		"rule": "Citizens whose nearest place is 3 or more roads away lose 1 happiness.",
		"tip": "Rewards places right next to the homes.",
	},
	"new_attractor": {
		"title": "New attractor", "family": FAMILY_CITY, "art": "circumstance_new_attractor", "badge": "+1", "key": "+1 point", "icon": "trophy", "tint": "#D6337A",
		"story": "A new attraction draws crowds from across the neighbourhood.",
		"rule": "Every place that serves 3 or more homes gives +1 point.",
		"tip": "Rewards places that many homes can reach.",
	},
	"population_growth": {
		"title": "Population growth", "family": FAMILY_CITY, "art": "circumstance_population_growth", "badge": "+1", "key": "gain 1 happiness", "icon": "citizen", "tint": "#2A6496",
		"story": "Newcomers move in and the streets come alive.",
		"rule": "Citizens who are already happy gain 1 happiness (up to +3).",
		"tip": "Rewards citizens who are already well served.",
	},
	"exam_season": {
		"title": "Exam season", "family": FAMILY_CITY, "art": "circumstance_exam_season", "badge": "-1", "key": "lose 1 happiness", "icon": "citizen", "tint": "#4F8BEA",
		"story": "Finals week at the university. Every student is hunting for a quiet desk.",
		"rule": "Students with no library within reach lose 1 happiness.",
		"tip": "Rewards cities that gave their students a library.",
	},
	"flu_wave": {
		"title": "Flu wave", "family": FAMILY_CITY, "art": "circumstance_flu_wave", "badge": "-1", "key": "lose 1 happiness", "icon": "citizen", "tint": "#3BA27A",
		"story": "A nasty winter flu sweeps through Egkomi and the waiting rooms fill up.",
		"rule": "Older residents, children and residents with a disability with no clinic or hospital within reach lose 1 happiness.",
		"tip": "Rewards cities with health care close to the homes.",
	},
	"supply_shortage": {
		"title": "Supply shortage", "family": FAMILY_CITY, "art": "circumstance_supply_shortage", "badge": "-1", "key": "lose 1 happiness", "icon": "citizen", "tint": "#C9742E",
		"story": "The delivery trucks are late and the shelves run empty.",
		"rule": "Workers and older residents with no supermarket or market within 2 roads lose 1 happiness.",
		"tip": "Rewards groceries close to the homes.",
	},
	"back_to_school": {
		"title": "Back to school", "family": FAMILY_CITY, "art": "circumstance_back_to_school", "badge": "-1", "key": "lose 1 happiness", "icon": "citizen", "tint": "#E2569C",
		"story": "The September bell rings and every child needs a classroom.",
		"rule": "Children with no school within reach lose 1 happiness.",
		"tip": "Rewards cities with a school for their families.",
	},
	"parking_shortage": {
		"title": "Parking shortage", "family": FAMILY_CITY, "art": "circumstance_parking_shortage", "badge": "-1", "key": "lose 1 happiness", "icon": "citizen", "tint": "#5C6BC0",
		"story": "Cars circle the block looking for a space. Egkomi has been asking for parking for years.",
		"rule": "Citizens other than children with no parking place within reach lose 1 happiness.",
		"tip": "Rewards cities that gave Egkomi its parking.",
	},
	"traffic_jam": {
		"title": "Traffic jam", "family": FAMILY_CITY, "art": "circumstance_traffic_jam", "badge": "-1", "key": "lose 1 happiness", "icon": "citizen", "tint": "#B5483A",
		"story": "A broken-down lorry blocks the main road at rush hour.",
		"rule": "Citizens whose home is right next to a parking place lose 1 happiness.",
		"tip": "Punishes homes squeezed against parking.",
	},
	"drought": {
		"title": "Drought", "family": FAMILY_WEATHER, "art": "circumstance_drought", "badge": "-1", "key": "lose 1 happiness", "icon": "citizen", "tint": "#D9A441",
		"story": "No rain for months. The trees are thirsty and the grass has turned brown.",
		"rule": "Citizens with trees but no park near their home lose 1 happiness.",
		"tip": "Rewards a real park over a few lonely trees.",
	},
	"tourist_season": {
		"title": "Tourist season", "family": FAMILY_CITY, "art": "circumstance_tourist_season", "badge": "+1", "key": "+1 point", "icon": "trophy", "tint": "#2A9DB5",
		"story": "Visitors fill the old town and every terrace.",
		"rule": "Every coffee shop and restaurant that serves 3 or more homes gives +1 point.",
		"tip": "Rewards busy coffee shops and restaurants.",
	},
	"health_campaign": {
		"title": "Health campaign", "family": FAMILY_CITY, "art": "circumstance_health_campaign", "badge": "+1", "key": "+1 point", "icon": "trophy", "tint": "#3BA27A",
		"story": "The ministry runs a free check-up week and the queues are long.",
		"rule": "Every clinic and hospital that serves 3 or more homes gives +1 point.",
		"tip": "Rewards health care that many homes can reach.",
	},
	"open_day": {
		"title": "Open day", "family": FAMILY_CITY, "art": "circumstance_open_day", "badge": "+1", "key": "+1 point", "icon": "trophy", "tint": "#4F8BEA",
		"story": "The university opens its doors to the whole neighbourhood.",
		"rule": "Every university that serves 2 or more student homes gives +1 point.",
		"tip": "Rewards universities with student housing around them.",
	},
	"business_boom": {
		"title": "Business boom", "family": FAMILY_CITY, "art": "circumstance_business_boom", "badge": "+2g", "key": "2 gold for each commercial area", "icon": "coin", "tint": "#D4A017",
		"story": "New shops open and the tills ring all over town.",
		"rule": "Every planner gets 2 gold for each commercial area on their mat.",
		"tip": "Rewards planners who built commercial areas.",
	},
	"tax_refund": {
		"title": "Tax refund", "family": FAMILY_CITY, "art": "circumstance_tax_refund", "badge": "+8g", "key": "8 gold", "icon": "coin", "tint": "#5E9B3A",
		"story": "The tax office finally sends the overpayments back.",
		"rule": "Every planner gets 8 gold.",
		"tip": "A welcome surprise for everyone.",
	},
	"bike_week": {
		"title": "Bike week", "family": FAMILY_CITY, "art": "circumstance_bike_week", "badge": "+1", "key": "gain 1 happiness", "icon": "citizen", "tint": "#2FA36B",
		"story": "The municipality hands out free helmets and the bike lanes fill up.",
		"rule": "Citizens whose route uses a bike lane gain 1 happiness.",
		"tip": "Rewards routes along bike lanes.",
	},
	"street_festival": {
		"title": "Street festival", "family": FAMILY_CITY, "art": "circumstance_street_festival", "badge": "+1", "key": "gain 1 happiness", "icon": "citizen", "tint": "#E87D3E",
		"story": "Neighbours put tables out on the car-free streets and share dinner.",
		"rule": "Citizens whose route uses a pedestrian street gain 1 happiness.",
		"tip": "Rewards routes along pedestrian streets.",
	},
	"remote_work": {
		"title": "Remote work wave", "family": FAMILY_CITY, "art": "circumstance_remote_work", "badge": "+1", "key": "gain 1 happiness", "icon": "citizen", "tint": "#8C6CC4",
		"story": "More people work from the corner cafe, laptop open and coffee in hand.",
		"rule": "Workers with a coffee shop or kiosk within reach gain 1 happiness.",
		"tip": "Rewards coffee shops and kiosks near workers.",
	},
	"autumn_rain": {
		"title": "Autumn rain", "family": FAMILY_WEATHER, "art": "circumstance_autumn_rain", "badge": "+1", "key": "gain 1 happiness", "icon": "citizen", "tint": "#4F9BD0",
		"story": "The first rain after a dry summer. Every garden drinks it in.",
		"rule": "Citizens with a park next to their home gain 1 happiness.",
		"tip": "Rewards homes beside a park.",
	},
	"smog_alert": {
		"title": "Smog alert", "family": FAMILY_WEATHER, "art": "circumstance_smog_alert", "badge": "-1", "key": "lose 1 happiness", "icon": "citizen", "tint": "#7A7F88",
		"story": "A grey lid sits over the roofs and the town hall tells everyone to stay in.",
		"rule": "If your pollution is above 5, citizens with no park next to their home lose 1 happiness.",
		"tip": "Rewards a clean city and homes beside a park.",
	},
	"cold_snap": {
		"title": "Cold snap", "family": FAMILY_WEATHER, "art": "circumstance_cold_snap", "badge": "-1", "key": "lose 1 happiness", "icon": "citizen", "tint": "#6BB4E8",
		"story": "Frost on the Troodos road and snow in the forecast. Grandma wants the heater on.",
		"rule": "Older citizens, children and residents with a disability with no park or trees next to their home lose 1 happiness.",
		"tip": "Trees and parks break the wind around homes.",
	},
	"farmers_market": {
		"title": "Farmers' market", "family": FAMILY_CITY, "art": "circumstance_farmers_market", "badge": "+1", "key": "gain 1 happiness", "icon": "citizen", "tint": "#6FAE3A",
		"story": "Halloumi, lemons and loud bargaining on the square every Saturday.",
		"rule": "Citizens with a market or supermarket within 2 roads gain 1 happiness.",
		"tip": "Rewards homes close to a market or supermarket.",
	},
	"science_fair": {
		"title": "Science fair", "family": FAMILY_CITY, "art": "circumstance_science_fair", "badge": "+1", "key": "+1 point", "icon": "trophy", "tint": "#2A9DB5",
		"story": "Volcanoes made of baking soda and one very proud ten-year-old.",
		"rule": "Every school that serves 3 or more homes gives +1 point.",
		"tip": "Rewards schools with plenty of homes around them.",
	},
	"road_subsidy": {
		"title": "Road subsidy", "family": FAMILY_CITY, "art": "circumstance_road_subsidy", "badge": "+1g", "key": "1 gold for each road tile", "icon": "coin", "tint": "#4C8C6B",
		"story": "The ministry pays for fresh asphalt, and for once the cones are in the right place.",
		"rule": "Every planner gets 1 gold for each road tile on their mat (up to 8).",
		"tip": "Rewards planners who built plenty of roads.",
	},
	"bus_strike": {
		"title": "Bus strike", "family": FAMILY_CITY, "art": "circumstance_bus_strike", "badge": "-1", "key": "lose 1 happiness", "icon": "citizen", "tint": "#C0512F",
		"story": "The drivers parked the buses in a row and went for coffee. All of them.",
		"rule": "Citizens with a long walk and no parking place within reach lose 1 happiness.",
		"tip": "Punishes long walks with no parking nearby.",
	},
	"pipe_repairs": {
		"title": "Pipe repairs", "family": FAMILY_CITY, "art": "circumstance_pipe_repairs", "badge": "-1g", "key": "1 gold for each home", "icon": "coin", "tint": "#A0701A",
		"story": "The water board digs up the main street. Again. The bill goes to every house.",
		"rule": "Every planner pays 1 gold for each home on their mat (up to 6).",
		"tip": "Costs planners with many homes the most.",
	},
}


static func info(id: String) -> Dictionary:
	return DEFS[id]


static func title(id: String) -> String:
	return DEFS[id]["title"]


static func art_path(id: String) -> String:
	return "res://assets/circumstances/%s.svg" % DEFS[id]["art"]


static func badge(id: String) -> String:
	return DEFS[id]["badge"]


## Good cards (a "+" badge) get a green corner badge, bad ones a red one.
static func is_good(id: String) -> bool:
	return DEFS[id]["badge"].begins_with("+")


## 1-based position of the card in the deck, printed in the footer ("Card 3 of 32").
static func number(id: String) -> int:
	return IDS.find(id) + 1


## Small icon shown next to the highlighted words of the rule.
static func icon_path(id: String) -> String:
	return "res://assets/ui/%s.svg" % DEFS[id]["icon"]


static func tint(id: String) -> Color:
	return Color(DEFS[id]["tint"])


## Gold one planner gains (positive) or loses (negative) when `id` is revealed, before the
## floor at zero. Only budget cut, grant, business boom, tax refund, road subsidy and pipe repairs touch gold.
static func gold_change(id: String, cells: Array) -> int:
	match id:
		"budget_cut":
			return -BUDGET_CUT
		"grant":
			var green := 0
			for t in cells:
				if t != null and (t["kind"] == TileDefs.Kind.PARK or TileDefs.is_tree_like(t)):
					green += 1
			return GRANT_BASE + GRANT_PER_GREEN * green
		"business_boom":
			var shops := 0
			for t in cells:
				if t != null and t["kind"] == TileDefs.Kind.COMMERCIAL:
					shops += 1
			return BUSINESS_GOLD_PER_COMMERCIAL * shops
		"tax_refund":
			return TAX_REFUND
		"road_subsidy":
			return mini(_count(cells, [TileDefs.Kind.ROAD]), ROAD_SUBSIDY_CAP)
		"pipe_repairs":
			var homes := 0
			for tile in cells:
				if tile != null and TileDefs.is_home(tile["kind"]):
					homes += 1
			return -mini(homes, PIPE_REPAIR_CAP)
	return 0


## How one citizen's happiness changes under card `id`. `m` describes the citizen (see
## Scoring._context): role, needs {need id: met}, routes {service: {length, shaded, kind}},
## nearest_kind {tile kind: shortest route}, heat, green, has_park, pollution, parking_adjacent,
## bike_route, pedestrian_route, long_route and so_far (happiness before this card).
static func member_effect(id: String, m: Dictionary) -> int:
	var long_route: int = m["long_route"]
	var routes: Dictionary = m["routes"]
	var nearest: Dictionary = m["nearest_kind"]
	var needs: Dictionary = m["needs"]
	var role: String = m["role"]
	match id:
		"heatwave":
			return -1 if m["heat"] > 0 else 0
		"flash_flood":
			return -1 if _has_long_walk(routes, long_route) and m["green"] == 0 else 0
		"dust_storm":
			return -1 if m["pollution"] > DUST_SAFE_LEVEL else 0
		"nice_weather":
			for r in routes.values():
				if r["shaded"]:
					return 1
			return 0
		"road_works":
			if routes.is_empty():
				return 0
			var closest := 99
			for r in routes.values():
				closest = mini(closest, r["length"])
			return -1 if closest >= long_route else 0
		"population_growth":
			return 1 if clampi(m["so_far"], -3, 3) > 0 else 0
		"exam_season":
			return -1 if role == "student" and needs.get("library", true) == false else 0
		"flu_wave":
			if role != "older" and role != "child" and role != "access":
				return 0
			return -1 if not (nearest.has(TileDefs.Kind.CLINIC) or nearest.has(TileDefs.Kind.HOSPITAL)) else 0
		"supply_shortage":
			if not needs.has("groceries"):
				return 0
			var closest := mini(nearest.get(TileDefs.Kind.SUPERMARKET, 99), nearest.get(TileDefs.Kind.MARKET, 99))
			return -1 if closest > 2 else 0
		"back_to_school":
			return -1 if role == "child" and needs.get("school", true) == false else 0
		"parking_shortage":
			if role == "child":
				return 0
			return -1 if not nearest.has(TileDefs.Kind.PARKING) else 0
		"traffic_jam":
			return -1 if m["parking_adjacent"] else 0
		"drought":
			return -1 if m["green"] > 0 and not m["has_park"] else 0
		"bike_week":
			return 1 if m["bike_route"] else 0
		"street_festival":
			return 1 if m["pedestrian_route"] else 0
		"remote_work":
			if role != "worker":
				return 0
			return 1 if nearest.has(TileDefs.Kind.COFFEE_SHOP) or nearest.has(TileDefs.Kind.KIOSK) else 0
		"autumn_rain":
			return 1 if m["has_park"] else 0
		"smog_alert":
			return -1 if m["pollution"] > SMOG_LEVEL and not m["has_park"] else 0
		"cold_snap":
			return -1 if (role == "older" or role == "child" or role == "access") and m["green"] == 0 else 0
		"farmers_market":
			var nearest_shop := mini(nearest.get(TileDefs.Kind.SUPERMARKET, 99), nearest.get(TileDefs.Kind.MARKET, 99))
			return 1 if nearest_shop <= MARKET_REACH else 0
		"bus_strike":
			return -1 if _has_long_walk(routes, long_route) and not nearest.has(TileDefs.Kind.PARKING) else 0
	return 0


static func _count(cells: Array, kinds: Array) -> int:
	var n := 0
	for tile in cells:
		if tile != null and tile["kind"] in kinds:
			n += 1
	return n


static func _has_long_walk(routes: Dictionary, long_route: int) -> bool:
	for r in routes.values():
		if r["length"] >= long_route:
			return true
	return false


## Cells that earn +1 point under card `id`. `stats`: cells, served_homes {service: homes that
## reach it} and served_student_homes {service: student homes that reach it}.
static func point_bonus(id: String, stats: Dictionary) -> Array[int]:
	var out: Array[int] = []
	var cells: Array = stats["cells"]
	for m in stats["served_homes"]:
		var kind: int = cells[m]["kind"]
		var homes: int = stats["served_homes"][m]
		match id:
			"new_attractor":
				if homes >= ATTRACTOR_MIN_HOMES:
					out.append(m)
			"tourist_season":
				if homes >= ATTRACTOR_MIN_HOMES and (kind == TileDefs.Kind.COFFEE_SHOP or kind == TileDefs.Kind.RESTAURANT):
					out.append(m)
			"health_campaign":
				if homes >= ATTRACTOR_MIN_HOMES and (kind == TileDefs.Kind.CLINIC or kind == TileDefs.Kind.HOSPITAL):
					out.append(m)
			"science_fair":
				if homes >= ATTRACTOR_MIN_HOMES and kind == TileDefs.Kind.SCHOOL:
					out.append(m)
			"open_day":
				if kind == TileDefs.Kind.UNIVERSITY and stats["served_student_homes"].get(m, 0) >= OPEN_DAY_MIN_STUDENT_HOMES:
					out.append(m)
	out.sort()
	return out
