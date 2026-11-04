extends RefCounted
## The two turn decks: 32 event cards (good) and 32 penalty cards (bad). Before a planner buys their
## tiles, a coin flip picks a deck and the top card of it is drawn. Its effect happens at once.
##
## Every card answers at least one of the game's four objectives (see UiKit.OBJECTIVES and OBJECTIVES below),
## and the card shows them.
##
## Every entry is [id, title, rule, story, motif, badge, effect]. "motif" gives the colour of the card
## (see MOTIF_TINT); every card has its own picture, assets/cards/<id>.svg. The effect is a dictionary that
## card_effects.gd knows how to carry out; see its header for the list of "op" values.

const TileDefs = preload("res://scripts/core/tile_defs.gd")

const EVENT := "event"
const PENALTY := "penalty"
const TYPES := [EVENT, PENALTY]
const DECK_SIZE := 32

const K := TileDefs.Kind
const HOMES := [K.APT_S, K.APT_M, K.APT_L, K.STUDENT_S, K.STUDENT_L]
const SERVICES := [K.COMMERCIAL, K.UNIVERSITY, K.LIBRARY, K.BOOKSHOP, K.PRINT_SHOP, K.COFFEE_SHOP, K.KIOSK,
	K.RESTAURANT, K.SUPERMARKET, K.MARKET, K.HOSPITAL, K.CLINIC, K.SCHOOL, K.PARKING]
const GREEN := [K.PARK, K.TREES]
const SHOPS := [K.KIOSK, K.MARKET, K.SUPERMARKET]
const EATING := [K.COFFEE_SHOP, K.RESTAURANT]
const STUDY := [K.UNIVERSITY, K.LIBRARY, K.BOOKSHOP]
const HEALTH := [K.CLINIC, K.HOSPITAL]
const STUDENT_HOMES := [K.STUDENT_S, K.STUDENT_L]

## Colour theme of each picture. Events lean green, gold and teal; penalties red, plum and rust.
const MOTIF_TINT := {
	"gold": "#D4A017", "government": "#3A7BD5", "bank": "#C98A1A", "roads": "#4C8C6B", "trees": "#3F9A4A",
	"park": "#5E9B3A", "shop": "#E5A12B", "campus": "#4F8BEA", "health": "#2FA37A", "school": "#2A9DB5",
	"parking": "#3E7FC8", "coffee": "#B8742F", "bike": "#2FA36B", "housing": "#6D8FD0", "trophy": "#D9A62A",
	"gift": "#C8509A", "construction": "#E0922B", "handshake": "#3F9A8C", "star": "#E1B52E", "ticket": "#8BAE2F",
	"fine": "#C8402A", "audit": "#8C3A6E", "storm": "#5B5FA8", "fire": "#D0602A", "flood": "#3C78B4",
	"sinkhole": "#8A5A3A", "smog": "#6B6F76", "strike": "#B5483A", "protest": "#C0512F", "pests": "#8E7A2C",
	"price": "#B03A48", "bureaucracy": "#7A4E9C", "repairs": "#A06A2A", "theft": "#5A4A6E", "unhappy": "#C45A7A",
	"traffic": "#A8442F", "demolition": "#8A4B3A", "scandal": "#9A3A5A", "tax": "#A5382E", "shortage": "#9A7B3A",
	"festival": "#D6527A", "rosette": "#3F7FD0", "bus": "#2E9AA8", "blackout": "#4A4F6E",
}

const EVENT_MOTIFS := ["gold", "government", "bank", "roads", "trees", "park", "shop", "campus", "health", "school",
	"parking", "coffee", "bike", "housing", "trophy", "gift", "construction", "handshake", "star", "ticket", "festival", "rosette", "bus"]
const PENALTY_MOTIFS := ["fine", "audit", "storm", "fire", "flood", "sinkhole", "smog", "strike", "protest", "pests",
	"price", "bureaucracy", "repairs", "theft", "unhappy", "traffic", "demolition", "scandal", "tax", "shortage", "blackout"]

# --------------------------------------------------------------------------- events

const EVENT_DATA := [
	["ramps_and_lifts", "Ramps and lifts", "Gain 2 gold for each clinic, hospital and park you own (up to 4).", "Every pavement gets a ramp and every building a lift that works.", "health", "+2g each",
		{"op": "gold_per", "kinds": HEALTH + [K.PARK], "n": 2, "cap": 4}],
	["improved_circulation", "Improved circulation", "Gain 5 gold if your roads connect every home to a place it can use.", "Buses, bikes and walkers all find their way.", "roads", "+5g",
		{"op": "gold_if", "cond": "connected", "n": 5}],
	["clean_record", "Clean record", "Gain 5 gold if you have no loans.", "The bank rewards planners who pay their way.", "bank", "+5g",
		{"op": "gold_if", "cond": "no_loans", "n": 5}],
	["green_city_award", "Green city award", "Gain 2 gold for each park and trees tile you own (up to 5).", "A jury of schoolchildren tours your gardens.", "trees", "+2g each",
		{"op": "gold_per", "kinds": GREEN, "n": 2, "cap": 5}],
	["parking_revenue", "Parking revenue", "Gain 2 gold for each parking place you own (up to 5).", "Finally, a space. And a ticket machine that works.", "parking", "+2g each",
		{"op": "gold_per", "kinds": [K.PARKING], "n": 2, "cap": 5}],
	["coffee_festival", "Coffee festival", "Gain 2 gold for each coffee shop and restaurant you own (up to 4).", "The whole street smells of freshly roasted beans.", "coffee", "+2g each",
		{"op": "gold_per", "kinds": EATING, "n": 2, "cap": 4}],
	["roads_or_greenery", "Roads or greenery", "Choose one free road tile or one free trees tile.", "Pave the way, or plant it. Your call.", "roads", "free tile",
		{"op": "choice", "options": [
			{"label": "A free road", "fx": {"op": "free_tile", "kind": K.ROAD, "n": 1}},
			{"label": "Free trees", "fx": {"op": "free_tile", "kind": K.TREES, "n": 1}}]}],
	["tree_planting_campaign", "Tree planting campaign", "Trees cost 0 gold this turn.", "Volunteers arrive with spades and saplings.", "trees", "trees 0g",
		{"op": "discount", "kinds": [K.TREES], "price": 0}],
	["park_donation", "Park donation", "You receive one free park.", "A local family gives its orchard to the city.", "park", "free park",
		{"op": "free_tile", "kind": K.PARK, "n": 1}],
	["bike_lane_gift", "Bike lane gift", "You receive one free bike lane.", "The cycling club paints the first stripes themselves.", "bike", "free lane",
		{"op": "free_tile", "kind": K.ROAD, "variant": 3, "n": 1}],
	["car_free_funding", "Car-free funding", "You receive one free pedestrian street.", "Children play where the cars used to park.", "roads", "free street",
		{"op": "free_tile", "kind": K.ROAD, "variant": 2, "n": 1}],
	["shade_programme", "Shade programme", "You receive one free shaded street.", "Cool, leafy and open for walkers.", "trees", "free street",
		{"op": "free_tile", "kind": K.ROAD, "variant": 1, "n": 1}],
	["student_town", "Student town", "Gain 1 point for each student residence you own (up to 3).", "Bicycles lean against every wall.", "campus", "+1 each",
		{"op": "points_per", "kinds": STUDENT_HOMES, "n": 1, "cap": 3}],
	["green_lungs", "Green lungs", "Gain 2 points if your pollution is 7 or less.", "Birds return to the neighbourhood.", "park", "+2",
		{"op": "points_if", "cond": "pollution_max", "max": 7, "n": 2}],
	["smooth_traffic", "Smooth traffic", "Gain 2 points if your roads connect every home to a place it can use.", "Not one honked horn all morning.", "roads", "+2",
		{"op": "points_if", "cond": "connected", "n": 2}],
	["well_served", "Well served", "Gain 2 points if you own at least 3 services and none of them is unused.", "Every counter has a queue and every queue a smile.", "shop", "+2",
		{"op": "points_if", "cond": "no_unused", "n": 2}],
	["clean_air_award", "Clean air award", "Gain 1 point and 4 gold if your pollution is 5 or less.", "The air monitor on the town hall has never been so green.", "trees", "+4g +1",
		{"op": "all", "fxs": [{"op": "points_if", "cond": "pollution_max", "max": 5, "n": 1}, {"op": "gold_if", "cond": "pollution_max", "max": 5, "n": 4}]}],
	["bus_network", "New bus network", "Gain 1 point and 4 gold if your roads connect every home to a place it can use.", "A bus every ten minutes, and it is even on time.", "bus", "+4g +1",
		{"op": "all", "fxs": [{"op": "points_if", "cond": "connected", "n": 1}, {"op": "gold_if", "cond": "connected", "n": 4}]}],
	["open_air_concert", "Open-air concert", "Gain 1 point for each park you own (up to 3).", "Blankets on the grass and a very good brass section.", "festival", "+1 each",
		{"op": "points_per", "kinds": [K.PARK], "n": 1, "cap": 3}],
	["community_garden", "Community garden", "Every player who owns a park gains 1 point.", "Tomatoes, beans and some very strong opinions about compost.", "park", "+1",
		{"op": "points_all_if", "cond": "has_kind", "kinds": [K.PARK], "n": 1}],
	["cool_walkways", "Cool walkways", "Gain 2 points if no citizen in your city has a long walk with no shade.", "Trees along every route keep the pavements cool.", "trees", "+2",
		{"op": "points_if", "cond": "no_hot", "n": 2}],
	["nobody_left_out", "Nobody left out", "Gain 2 points if every citizen has everything they need within reach.", "Every home, every need, one short walk.", "star", "+2",
		{"op": "points_if", "cond": "all_met", "n": 2}],
	["fresh_asphalt", "Fresh asphalt", "Roads cost 0 gold this turn.", "The council resurfaces the whole neighbourhood in one weekend.", "roads", "roads 0g",
		{"op": "discount", "kinds": [K.ROAD], "price": 0}],
	["accessible_routes", "Accessible routes", "Gain 1 point for each clinic, hospital and school you own (up to 3).", "Step-free paths lead to every doctor and classroom.", "health", "+1 each",
		{"op": "points_per", "kinds": HEALTH + [K.SCHOOL], "n": 1, "cap": 3}],
	["busy_streets", "Busy streets", "Gain 1 gold for every 2 citizens you house (up to 5).", "Where people walk, shops and cafes thrive.", "shop", "+1g each",
		{"op": "gold_stat_per", "stat": "citizens", "per": 1, "every": 2, "cap": 5}],
	["school_run_on_foot", "School run on foot", "Gain 1 point if you own a park and 1 point if you own a school.", "Children walk to school through the park.", "school", "+1 +1",
		{"op": "all", "fxs": [{"op": "points_if", "cond": "has_kind", "kinds": [K.PARK], "n": 1},
			{"op": "points_if", "cond": "has_kind", "kinds": [K.SCHOOL], "n": 1}]}],
	["pedestrian_day", "Pedestrian day", "You receive one free pedestrian street and one free trees tile.", "For one day the cars stay home and the street belongs to people.", "roads", "free tiles",
		{"op": "all", "fxs": [{"op": "free_tile", "kind": K.ROAD, "variant": 2, "n": 1}, {"op": "free_tile", "kind": K.TREES, "n": 1}]}],
	["residents_survey", "Residents' survey", "Gain 3 gold if none of your citizens is unhappy.", "Neighbours tell the council what works. Nobody complains.", "handshake", "+3g",
		{"op": "gold_if", "cond": "no_unhappy", "n": 3}],
	["shared_plaza", "Shared plaza", "Every player who owns at least 2 parks or coffee shops gains 1 point.", "A square with shade, benches and a coffee: everyone's living room.", "park", "+1",
		{"op": "points_all_if", "cond": "count_min", "kinds": [K.PARK, K.COFFEE_SHOP], "min": 2, "n": 1}],
	["improvement_budget", "Improvement budget", "Choose 3 gold or one free road tile.", "Fix what is broken, or build what is missing.", "construction", "choose",
		{"op": "choice", "options": [
			{"label": "3 gold", "fx": {"op": "gold_self", "n": 3}},
			{"label": "A free road", "fx": {"op": "free_tile", "kind": K.ROAD, "n": 1}}]}],
	["pocket_parks", "Pocket parks", "Parks cost 2 gold less this turn.", "Every empty corner becomes a place to sit.", "park", "parks -2g",
		{"op": "discount", "kinds": [K.PARK], "by": 2}],
	["community_map", "Community map", "The player with the most unhappy citizens receives 3 gold.", "Residents mark the problem spots, and the council listens.", "handshake", "+3g",
		{"op": "gold_stat", "stat": "unhappy", "mode": "max", "n": 3}],
]

# --------------------------------------------------------------------------- penalties

const PENALTY_DATA := [
	["environmental_fine", "Environmental fine", "The player with the highest pollution pays 7 gold.", "The inspectors hold their noses.", "smog", "-7g",
		{"op": "gold_stat", "stat": "pollution", "mode": "max", "n": -7}],
	["construction_delays", "Construction delays", "You pay 1 gold for every 2 roads you own (up to 8).", "The diversion sign has been here since spring.", "traffic", "-1g per 2",
		{"op": "gold_stat_per", "stat": "roads", "per": -1, "every": 2, "cap": 8}],
	["road_toll_dispute", "Road toll dispute", "Give each other player 2 gold, or lose 3 road tiles.", "Your neighbours want a share of the tolls.", "traffic", "choose",
		{"op": "choice", "options": [
			{"label": "Pay each player 2 gold", "fx": {"op": "pay_each", "n": 2}},
			{"label": "Lose 3 road tiles", "fx": {"op": "lose_roads", "n": 3}}]}],
	["illegal_tree_recovery", "Illegal tree recovery", "Lose one trees tile, or pay 4 gold to protect it.", "Someone has been digging up the saplings overnight.", "pests", "choose",
		{"op": "choice", "options": [
			{"label": "Pay 4 gold", "fx": {"op": "gold_self", "n": -4}},
			{"label": "Lose a trees tile", "fx": {"op": "lose_tile", "kinds": [K.TREES], "n": 1}}]}],
	["community_complaints", "Community complaints", "The player with the fewest services loses 2 points.", "Residents queue at the town hall with petitions.", "protest", "-2",
		{"op": "points_stat", "stat": "services", "mode": "min", "n": -2}],
	["public_protest", "Public protest", "The player with the most unhappy citizens loses 2 points.", "Banners fill the high street.", "protest", "-2",
		{"op": "points_stat", "stat": "unhappy", "mode": "max", "n": -2}],
	["failed_inspection", "Failed inspection", "Lose 1 point for each unused service you own (up to 3).", "Empty counters and dusty shelves.", "audit", "-1 each",
		{"op": "points_stat_per", "stat": "unused", "per": -1, "cap": 3}],
	["green_shortfall", "Green shortfall", "Lose 2 points if you own no park.", "The nearest swing is an hour away.", "pests", "-2",
		{"op": "points_if", "cond": "lacks_kind", "kinds": [K.PARK], "n": -2}],
	["school_shortage", "School shortage", "Lose 2 points if you own no school.", "Forty children in a classroom for twenty.", "shortage", "-2",
		{"op": "points_if", "cond": "lacks_kind", "kinds": [K.SCHOOL], "n": -2}],
	["waiting_lists", "Waiting lists", "Lose 2 points if you own no clinic or hospital.", "The queue starts at five in the morning.", "shortage", "-2",
		{"op": "points_if", "cond": "lacks_kind", "kinds": HEALTH, "n": -2}],
	["lift_repairs", "Lift repairs", "You pay 2 gold for each clinic, hospital and school you own (up to 4).", "Every public building has a lift, and every lift is out of order.", "repairs", "-2g each",
		{"op": "gold_per", "kinds": HEALTH + [K.SCHOOL], "n": -2, "cap": 4}],
	["unemployment", "Unemployment", "Lose 2 points if you own no commercial area.", "The job centre has a line round the block.", "shortage", "-2",
		{"op": "points_if", "cond": "lacks_kind", "kinds": [K.COMMERCIAL], "n": -2}],
	["traffic_chaos", "Traffic chaos", "Lose 1 point for each parking place you own (up to 3).", "Everyone wants to park in the same spot.", "traffic", "-1 each",
		{"op": "points_per", "kinds": [K.PARKING], "n": -1, "cap": 3}],
	["heat_advisory", "Heat advisory", "Every player who owns no park or trees loses 2 points.", "40 degrees and no shade anywhere.", "fire", "-2",
		{"op": "points_all_if", "cond": "lacks_kind", "kinds": GREEN, "n": -2}],
	["sinkhole", "Sinkhole", "Lose a road tile of your choice.", "The street opens like a mouth.", "sinkhole", "-1 road",
		{"op": "lose_roads", "n": 1}],
	["storm_damage", "Storm damage", "Lose one trees tile.", "Last night's wind took the oldest tree.", "storm", "-1 trees",
		{"op": "lose_tile", "kinds": [K.TREES], "n": 1}],
	["vandals", "Vandals", "Lose a parking place of your choice.", "The barrier is gone and so is the sign.", "theft", "-1 parking",
		{"op": "lose_tile", "kinds": [K.PARKING], "n": 1}],
	["flooded_streets", "Flooded streets", "Lose 2 road tiles.", "The drains were last cleaned in 1998.", "flood", "-2 roads",
		{"op": "lose_roads", "n": 2}],
	["landslide", "Landslide", "Lose 3 road tiles.", "The hillside gives up all at once.", "sinkhole", "-3 roads",
		{"op": "lose_roads", "n": 3}],
	["beetle_attack", "Beetle attack", "Lose 2 trees tiles.", "Tiny bugs, enormous appetite.", "pests", "-2 trees",
		{"op": "lose_tile", "kinds": [K.TREES], "n": 2}],
	["park_closure", "Park closure", "Pay 7 gold, or lose a park of your choice.", "The council cannot afford to keep the gates open.", "storm", "choose",
		{"op": "choice", "options": [
			{"label": "Pay 7 gold", "fx": {"op": "gold_self", "n": -7}},
			{"label": "Lose a park", "fx": {"op": "lose_tile", "kinds": [K.PARK], "n": 1}}]}],
	["plant_shortage", "Plant shortage", "Parks and trees cost 3 gold more this turn.", "The nursery has sold out of everything green.", "pests", "green +3g",
		{"op": "markup", "kinds": GREEN, "by": 3}],
	["burst_pipe", "Burst pipe", "Pay 5 gold, or lose 2 road tiles of your choice.", "Water everywhere, and the plumber is on holiday.", "flood", "choose",
		{"op": "choice", "options": [
			{"label": "Pay 5 gold", "fx": {"op": "gold_self", "n": -5}},
			{"label": "Lose 2 road tiles", "fx": {"op": "lose_roads", "n": 2}}]}],
	["empty_shelves", "Empty shelves", "Lose 2 points if you own no supermarket or market.", "Residents shop two villages away.", "shortage", "-2",
		{"op": "points_if", "cond": "lacks_kind", "kinds": [K.SUPERMARKET, K.MARKET], "n": -2}],
	["flu_season", "Flu season", "Every player without a clinic or hospital loses 1 point.", "Half the town is sneezing, and the nearest doctor is a long walk away.", "shortage", "-1",
		{"op": "points_all_if", "cond": "lacks_kind", "kinds": HEALTH, "n": -1}],
	["gas_leak", "Gas leak", "Lose 2 points if your pollution is 8 or more.", "The whole district smells like a bad egg.", "smog", "-2",
		{"op": "points_if", "cond": "pollution_min", "min": 8, "n": -2}],
	["gridlock", "Gridlock", "Lose 2 points if any home has no route to a place it can use.", "The bus has been stuck behind the same lorry since breakfast.", "traffic", "-2",
		{"op": "points_if", "cond": "not_connected", "n": -2}],
	["bare_pavements", "Bare pavements", "Lose 2 points if you own no trees tile.", "Not one shady spot on the walk home.", "smog", "-2",
		{"op": "points_if", "cond": "lacks_kind", "kinds": [K.TREES], "n": -2}],
	["hot_pavements", "Hot pavements", "Lose 1 point for each citizen with a long walk and no shade (up to 3).", "The tarmac burns. Nobody dares to walk.", "fire", "-1 each",
		{"op": "points_stat_per", "stat": "hot", "per": -1, "cap": 3}],
	["missing_links", "Missing links", "Lose 1 point for each citizen who cannot reach something they need (up to 3).", "The road stops two blocks short.", "traffic", "-1 each",
		{"op": "points_stat_per", "stat": "unmet", "per": -1, "cap": 3}],
	["smog_warning", "Smog warning", "The player with the highest pollution loses 2 points.", "A grey haze hangs over the city.", "smog", "-2",
		{"op": "points_stat", "stat": "pollution", "mode": "max", "n": -2}],
	["dull_streets", "Dull streets", "The player with the fewest parks and trees loses 1 point.", "Concrete as far as the eye can see.", "unhappy", "-1",
		{"op": "points_stat", "stat": "green", "mode": "min", "n": -1}],
]


## New cards reuse the picture of a card that left the game: card id -> the id whose assets/cards picture it uses.
const ART_FROM := {
	"cool_walkways": "solar_roofs", "nobody_left_out": "community_day", "fresh_asphalt": "road_crew",
	"accessible_routes": "health_ministry_funding", "busy_streets": "market_day", "school_run_on_foot": "school_grant",
	"pedestrian_day": "city_marathon", "residents_survey": "neighbourhood_prize", "shared_plaza": "cultural_evening",
	"improvement_budget": "smart_investment", "pocket_parks": "ribbon_cutting", "community_map": "planners_pick",
	"bare_pavements": "demolition_order", "hot_pavements": "power_cut", "missing_links": "lost_permits",
	"smog_warning": "smog_scandal", "dull_streets": "noise_complaints",
}

## The objectives every card answers (see UiKit.OBJECTIVES): O1 circulation and everyday life, O2 how spaces could
## be improved, O3 where greenery could improve pedestrian routes, O4 how movement, vegetation, accessibility and
## spaces shape everyday life in Egkomi. A card answers one or more, or all four.
const OBJECTIVES := {
	# events
	"ramps_and_lifts": ["O1", "O4"], "improved_circulation": ["O1"], "clean_record": ["O2"],
	"green_city_award": ["O3"], "parking_revenue": ["O1"], "coffee_festival": ["O4"],
	"roads_or_greenery": ["O1", "O3"], "tree_planting_campaign": ["O3"], "park_donation": ["O3"],
	"bike_lane_gift": ["O1"], "car_free_funding": ["O1", "O3"], "shade_programme": ["O3"],
	"student_town": ["O4"], "green_lungs": ["O3"], "smooth_traffic": ["O1"], "well_served": ["O2", "O4"],
	"clean_air_award": ["O3"], "bus_network": ["O1"], "open_air_concert": ["O3", "O4"],
	"community_garden": ["O3", "O4"], "cool_walkways": ["O1", "O3"], "nobody_left_out": ["O1", "O2", "O3", "O4"],
	"fresh_asphalt": ["O1", "O2"], "accessible_routes": ["O4"], "busy_streets": ["O1", "O4"],
	"school_run_on_foot": ["O3", "O4"], "pedestrian_day": ["O1", "O3"], "residents_survey": ["O2", "O4"],
	"shared_plaza": ["O1", "O2", "O3", "O4"], "improvement_budget": ["O1", "O2"], "pocket_parks": ["O3"],
	"community_map": ["O2", "O4"],
	# penalties
	"environmental_fine": ["O3", "O4"], "road_toll_dispute": ["O1"], "illegal_tree_recovery": ["O3"],
	"community_complaints": ["O4"], "public_protest": ["O2", "O4"], "failed_inspection": ["O2"],
	"green_shortfall": ["O3"], "school_shortage": ["O4"], "waiting_lists": ["O4"], "lift_repairs": ["O2", "O4"],
	"traffic_chaos": ["O1"], "heat_advisory": ["O3", "O4"], "sinkhole": ["O1", "O2"], "storm_damage": ["O3"],
	"vandals": ["O1"], "flooded_streets": ["O1"], "landslide": ["O1"], "beetle_attack": ["O3"],
	"park_closure": ["O3"], "plant_shortage": ["O3"], "construction_delays": ["O1", "O2"],
	"burst_pipe": ["O1", "O2"], "empty_shelves": ["O4"], "flu_season": ["O4"], "gas_leak": ["O3", "O4"],
	"gridlock": ["O1"], "unemployment": ["O4"], "bare_pavements": ["O1", "O3"], "hot_pavements": ["O1", "O3"],
	"missing_links": ["O1", "O4"], "smog_warning": ["O3", "O4"], "dull_streets": ["O2", "O3"],
}

static var _by_id := {}
static var _ids := {EVENT: [], PENALTY: []}


static func _build() -> void:
	if not _by_id.is_empty():
		return
	for pair in [[EVENT, EVENT_DATA], [PENALTY, PENALTY_DATA]]:
		var type: String = pair[0]
		var list: Array = pair[1]
		for i in list.size():
			var e: Array = list[i]
			_by_id[e[0]] = {
				"id": e[0], "type": type, "title": e[1], "rule": e[2], "story": e[3], "motif": e[4],
				"badge": e[5], "fx": e[6], "number": i + 1, "tint": MOTIF_TINT[e[4]],
			}
			_ids[type].append(e[0])


static func ids(type: String) -> Array:
	_build()
	return _ids[type].duplicate()


static func info(id: String) -> Dictionary:
	_build()
	return _by_id[id]


static func has_card(id: String) -> bool:
	_build()
	return _by_id.has(id)


static func type_of(id: String) -> String:
	return info(id)["type"]


static func title(id: String) -> String:
	return info(id)["title"]


## The cards added in the cards rework (3.0), in deck order: they are the ones with a borrowed picture.
static func new_ids(type: String) -> Array:
	var out: Array = []
	for id in ids(type):
		if ART_FROM.has(id):
			out.append(id)
	return out


static func art_path(id: String) -> String:
	return "res://assets/cards/%s.svg" % ART_FROM.get(id, id)


## The objectives the card answers, as ids "O1" to "O4".
static func objectives(id: String) -> Array:
	return OBJECTIVES[id]


static func tint(id: String) -> Color:
	return Color(info(id)["tint"])


static func is_event(id: String) -> bool:
	return info(id)["type"] == EVENT


## The words of the rule that the card face highlights: the first amount ("3 gold", "2 points"),
## else the first "free ..." phrase, else the first words. Always a part of the rule.
static func key_words(id: String) -> String:
	var rule: String = info(id)["rule"]
	for pattern in ["\\d+ (?:extra )?(?:gold|points?|road tiles?|roads|trees tiles?|free roads?)", "\\d+ extra free roads", "free [a-z]+(?: [a-z]+)?", "\\d+ fewer tile", "\\d+ extra tile", "Choose", "Every [a-z]+ [a-z]+"]:
		var re := RegEx.create_from_string(pattern)
		var m := re.search(rule)
		if m != null:
			return m.get_string()
	var words := rule.split(" ")
	return " ".join(words.slice(0, mini(3, words.size())))


## Small picture next to the highlighted words: a coin for gold, a trophy for points, else a citizen.
static func icon_name(id: String) -> String:
	var fx: Dictionary = info(id)["fx"]
	var op := _first_op(fx)
	if op.begins_with("gold") or op in ["steal", "pay_each", "transfer", "discount", "discount_all", "markup", "markup_all"]:
		return "coin"
	if op.begins_with("points"):
		return "trophy"
	return "citizen"


static func icon_path(id: String) -> String:
	return "res://assets/ui/%s.svg" % icon_name(id)


static func _first_op(fx: Dictionary) -> String:
	if fx["op"] == "all":
		return _first_op(fx["fxs"][0])
	if fx["op"] == "choice":
		return "choice"
	return fx["op"]
