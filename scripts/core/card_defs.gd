extends RefCounted
## The two turn decks: 64 event cards (good) and 64 penalty cards (bad). Before a planner buys their
## tiles, a coin flip picks a deck and the top card of it is drawn. Its effect happens at once.
##
## Every entry is [id, title, rule, story, motif, badge, effect]. "motif" gives the colour of the card
## (see MOTIF_TINT); every card has its own picture, assets/cards/<id>.svg. The effect is a dictionary that
## card_effects.gd knows how to carry out; see its header for the list of "op" values.

const TileDefs = preload("res://scripts/core/tile_defs.gd")

const EVENT := "event"
const PENALTY := "penalty"
const TYPES := [EVENT, PENALTY]
const DECK_SIZE := 64

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
	["government_funding", "Government funding", "Every player receives 4 gold.", "Nicosia sends a cheque to every neighbourhood board.", "government", "+4g",
		{"op": "gold_all", "n": 4}],
	["regional_grant", "Regional grant", "Every player receives 3 gold. You receive 3 more.", "Your application is the best-written one on the pile.", "government", "+3g",
		{"op": "all", "fxs": [{"op": "gold_all", "n": 3}, {"op": "gold_self", "n": 3}]}],
	["ramps_and_lifts", "Ramps and lifts", "Gain 2 gold for each clinic, hospital and park you own (up to 4).", "Every pavement gets a ramp and every building a lift that works.", "health", "+2g each",
		{"op": "gold_per", "kinds": HEALTH + [K.PARK], "n": 2, "cap": 4}],
	["lottery_win", "Lottery win", "You receive 8 gold.", "A scratch card from the kiosk on the corner pays out.", "ticket", "+8g",
		{"op": "gold_self", "n": 8}],
	["bank_bonus", "Bank bonus", "The player with the least money receives 6 gold.", "The bank looks after those who need it most.", "bank", "+6g",
		{"op": "gold_stat", "stat": "money", "mode": "min", "n": 6}],
	["solidarity_fund", "Solidarity fund", "The player with the least money receives 6 gold. You receive 2.", "Neighbours pass the hat around the square.", "handshake", "+6g",
		{"op": "all", "fxs": [{"op": "gold_stat", "stat": "money", "mode": "min", "n": 6}, {"op": "gold_self", "n": 2}]}],
	["tourist_tax", "Tourist tax", "Every other player pays you 2 gold.", "Visitors love your streets, and the guesthouses pay the levy.", "star", "+2g each",
		{"op": "steal", "from": "all", "n": 2}],
	["generous_donor", "Generous donor", "The richest player pays you 5 gold.", "A wealthy neighbour funds your next project.", "handshake", "+5g",
		{"op": "steal", "from": "richest", "n": 5}],
	["improved_circulation", "Improved circulation", "Gain 5 gold if your roads connect every home to a place it can use.", "Buses, bikes and walkers all find their way.", "roads", "+5g",
		{"op": "gold_if", "cond": "connected", "n": 5}],
	["clean_record", "Clean record", "Gain 5 gold if you have no loans.", "The bank rewards planners who pay their way.", "bank", "+5g",
		{"op": "gold_if", "cond": "no_loans", "n": 5}],
	["green_city_award", "Green city award", "Gain 2 gold for each park and trees tile you own (up to 5).", "A jury of schoolchildren tours your gardens.", "trees", "+2g each",
		{"op": "gold_per", "kinds": GREEN, "n": 2, "cap": 5}],
	["shopkeepers_guild", "Shopkeepers' guild", "Gain 2 gold for each commercial area you own (up to 4).", "The guild pays its members a loyalty bonus.", "shop", "+2g each",
		{"op": "gold_per", "kinds": [K.COMMERCIAL], "n": 2, "cap": 4}],
	["market_day", "Market day", "Gain 2 gold for each kiosk, market and supermarket you own (up to 4).", "The stalls are busy from dawn until the church bells ring.", "shop", "+2g each",
		{"op": "gold_per", "kinds": SHOPS, "n": 2, "cap": 4}],
	["campus_buzz", "Campus buzz", "Gain 3 gold for each university and library you own (up to 4), and 1 point if you own at least 2.", "Students fill the cafes and the money follows.", "campus", "+3g each",
		{"op": "all", "fxs": [{"op": "gold_per", "kinds": [K.UNIVERSITY, K.LIBRARY], "n": 3, "cap": 4},
			{"op": "points_if", "cond": "count_min", "kinds": [K.UNIVERSITY, K.LIBRARY], "min": 2, "n": 1}]}],
	["health_ministry_funding", "Health ministry funding", "Gain 3 gold for each clinic and hospital you own (up to 3), and 1 point if you own any.", "The ministry tops up every ward that keeps its doors open.", "health", "+3g each",
		{"op": "all", "fxs": [{"op": "gold_per", "kinds": HEALTH, "n": 3, "cap": 3},
			{"op": "points_if", "cond": "has_kind", "kinds": HEALTH, "n": 1}]}],
	["school_grant", "School grant", "Gain 3 gold for each school you own (up to 3), and 1 point if you own any.", "New desks, new books, new paint.", "school", "+3g each",
		{"op": "all", "fxs": [{"op": "gold_per", "kinds": [K.SCHOOL], "n": 3, "cap": 3},
			{"op": "points_if", "cond": "has_kind", "kinds": [K.SCHOOL], "n": 1}]}],
	["parking_revenue", "Parking revenue", "Gain 2 gold for each parking place you own (up to 5).", "Finally, a space. And a ticket machine that works.", "parking", "+2g each",
		{"op": "gold_per", "kinds": [K.PARKING], "n": 2, "cap": 5}],
	["coffee_festival", "Coffee festival", "Gain 2 gold for each coffee shop and restaurant you own (up to 4).", "The whole street smells of freshly roasted beans.", "coffee", "+2g each",
		{"op": "gold_per", "kinds": EATING, "n": 2, "cap": 4}],
	["newcomers", "Newcomers", "Gain 5 gold and 1 point if you house 10 or more citizens.", "Moving vans line the street all week.", "housing", "+5g",
		{"op": "all", "fxs": [{"op": "gold_if", "cond": "citizens_min", "min": 10, "n": 5},
			{"op": "points_if", "cond": "citizens_min", "min": 10, "n": 1}]}],
	["debt_relief", "Debt relief", "Remove one of your loans, if you have one.", "The bank writes off a loan and sends flowers.", "bank", "-1 loan",
		{"op": "loan_relief"}],
	["roads_or_greenery", "Roads or greenery", "Choose one free road tile or one free trees tile.", "Pave the way, or plant it. Your call.", "roads", "free tile",
		{"op": "choice", "options": [
			{"label": "A free road", "fx": {"op": "free_tile", "kind": K.ROAD, "n": 1}},
			{"label": "Free trees", "fx": {"op": "free_tile", "kind": K.TREES, "n": 1}}]}],
	["tree_planting_campaign", "Tree planting campaign", "Trees cost 0 gold this turn.", "Volunteers arrive with spades and saplings.", "trees", "trees 0g",
		{"op": "discount", "kinds": [K.TREES], "price": 0}],
	["road_crew", "Road crew", "You receive 2 extra free roads.", "The municipal crew has a few spare days.", "construction", "+2 roads",
		{"op": "free_roads", "n": 2}],
	["park_donation", "Park donation", "You receive one free park.", "A local family gives its orchard to the city.", "park", "free park",
		{"op": "free_tile", "kind": K.PARK, "n": 1}],
	["corner_shop_licence", "Corner shop licence", "You receive one free kiosk.", "Paperwork approved in a single afternoon. A first.", "shop", "free kiosk",
		{"op": "free_tile", "kind": K.KIOSK, "n": 1}],
	["cafe_startup", "Cafe start-up", "You receive one free coffee shop.", "A young barista needs a place to open.", "coffee", "free cafe",
		{"op": "free_tile", "kind": K.COFFEE_SHOP, "n": 1}],
	["bike_lane_gift", "Bike lane gift", "You receive one free bike lane.", "The cycling club paints the first stripes themselves.", "bike", "free lane",
		{"op": "free_tile", "kind": K.ROAD, "variant": 3, "n": 1}],
	["car_free_funding", "Car-free funding", "You receive one free pedestrian street.", "Children play where the cars used to park.", "roads", "free street",
		{"op": "free_tile", "kind": K.ROAD, "variant": 2, "n": 1}],
	["shade_programme", "Shade programme", "You receive one free shaded street.", "Cool, leafy and open for walkers.", "trees", "free street",
		{"op": "free_tile", "kind": K.ROAD, "variant": 1, "n": 1}],
	["parking_donation", "Parking donation", "You receive one free parking place.", "A supermarket donates part of its car park.", "parking", "free parking",
		{"op": "free_tile", "kind": K.PARKING, "n": 1}],
	["housing_subsidy", "Housing subsidy", "Homes cost 3 gold less this turn.", "The council wants more families in town.", "housing", "homes -3g",
		{"op": "discount", "kinds": HOMES, "by": 3}],
	["shop_sale", "Shop sale", "Shops, cafes and services cost 2 gold less this turn.", "Everything must go. The signs say so.", "shop", "services -2g",
		{"op": "discount", "kinds": SERVICES, "by": 2}],
	["embassy_reception", "Embassy reception", "Gain 2 gold for each restaurant and commercial area you own (up to 4), and 1 point if you own a restaurant.", "Diplomats, canapes and a very long guest list.", "handshake", "+2g each",
		{"op": "all", "fxs": [{"op": "gold_per", "kinds": [K.RESTAURANT, K.COMMERCIAL], "n": 2, "cap": 4},
			{"op": "points_if", "cond": "has_kind", "kinds": [K.RESTAURANT], "n": 1}]}],
	["student_housing_fund", "Student housing fund", "Student residences cost 3 gold less this turn.", "The university wants its students closer to class.", "campus", "residences -3g",
		{"op": "discount", "kinds": STUDENT_HOMES, "by": 3}],
	["builders_discount", "Builders' discount", "Every tile costs 2 gold less this turn.", "The builders' merchant is feeling generous.", "construction", "all -2g",
		{"op": "discount_all", "n": 2}],
	["extra_hands", "Extra hands", "You may buy 1 extra tile this turn.", "A second crew turns up with its own cement mixer.", "construction", "+1 buy",
		{"op": "buy_bonus", "n": 1}],
	["luxury_housing", "Luxury housing", "Gain 1 point for each large apartment you own (up to 3).", "Marble lobbies and a rooftop terrace.", "housing", "+1 each",
		{"op": "points_per", "kinds": [K.APT_L], "n": 1, "cap": 3}],
	["civic_pride", "Civic pride", "You gain 2 points.", "Flags in every window and a brass band in the square.", "star", "+2",
		{"op": "points_self", "n": 2}],
	["neighbourhood_prize", "Neighbourhood prize", "The player with the fewest points gains 3 points.", "A prize for the underdog who never gave up.", "trophy", "+3",
		{"op": "points_stat", "stat": "score", "mode": "min", "n": 3}],
	["student_town", "Student town", "Gain 1 point for each student residence you own (up to 3).", "Bicycles lean against every wall.", "campus", "+1 each",
		{"op": "points_per", "kinds": STUDENT_HOMES, "n": 1, "cap": 3}],
	["healthy_city", "Healthy city", "Gain 2 points if you own a clinic or a hospital.", "Egkomi tops the regional health table.", "health", "+2",
		{"op": "points_if", "cond": "has_kind", "kinds": HEALTH, "n": 2}],
	["green_lungs", "Green lungs", "Gain 2 points if your pollution is 7 or less.", "Birds return to the neighbourhood.", "park", "+2",
		{"op": "points_if", "cond": "pollution_max", "max": 7, "n": 2}],
	["community_day", "Community day", "Every player who owns a coffee shop or restaurant gains 1 point.", "Everyone brings a dish and a chair.", "handshake", "+1",
		{"op": "points_all_if", "cond": "has_kind", "kinds": EATING, "n": 1}],
	["smooth_traffic", "Smooth traffic", "Gain 2 points if your roads connect every home to a place it can use.", "Not one honked horn all morning.", "roads", "+2",
		{"op": "points_if", "cond": "connected", "n": 2}],
	["well_served", "Well served", "Gain 2 points if you own at least 3 services and none of them is unused.", "Every counter has a queue and every queue a smile.", "shop", "+2",
		{"op": "points_if", "cond": "no_unused", "n": 2}],
	["cultural_evening", "Cultural evening", "Gain 1 point for each bookshop, library and university you own (up to 4).", "Poetry, lectures and a very full programme.", "campus", "+1 each",
		{"op": "points_per", "kinds": STUDY, "n": 1, "cap": 4}],
	["solar_roofs", "Solar roofs", "Gain 4 gold and 1 point if your pollution is 7 or less.", "Every roof in the street turns a little bluer.", "star", "+4g",
		{"op": "all", "fxs": [{"op": "gold_if", "cond": "pollution_max", "max": 7, "n": 4},
			{"op": "points_if", "cond": "pollution_max", "max": 7, "n": 1}]}],
	["mayors_reward", "Mayor's reward", "Choose 5 gold or 1 point.", "The mayor shakes your hand and leaves the choice to you.", "trophy", "choose",
		{"op": "choice", "options": [
			{"label": "5 gold", "fx": {"op": "gold_self", "n": 5}},
			{"label": "1 point", "fx": {"op": "points_self", "n": 1}}]}],
	["planners_pick", "Planner's pick", "Choose a free park or 6 gold.", "Greenery now, or cash for later.", "park", "choose",
		{"op": "choice", "options": [
			{"label": "A free park", "fx": {"op": "free_tile", "kind": K.PARK, "n": 1}},
			{"label": "6 gold", "fx": {"op": "gold_self", "n": 6}}]}],
	["smart_investment", "Smart investment", "Choose 4 gold or a free coffee shop.", "A little money now, or a business that earns it back.", "gold", "choose",
		{"op": "choice", "options": [
			{"label": "4 gold", "fx": {"op": "gold_self", "n": 4}},
			{"label": "A free coffee shop", "fx": {"op": "free_tile", "kind": K.COFFEE_SHOP, "n": 1}}]}],
	# --- added later: more cards that give points, alone or together with gold
	["festival_of_lights", "Festival of lights", "You gain 2 points. The player with the fewest points gains 1.", "Lanterns line every street and nobody wants to go home.", "festival", "+2",
		{"op": "all", "fxs": [{"op": "points_self", "n": 2}, {"op": "points_stat", "stat": "score", "mode": "min", "n": 1}]}],
	["ribbon_cutting", "Ribbon cutting", "Gain 1 point and 4 gold.", "The mayor holds the scissors. Everyone else holds a camera.", "rosette", "+4g +1",
		{"op": "all", "fxs": [{"op": "points_self", "n": 1}, {"op": "gold_self", "n": 4}]}],
	["heritage_prize", "Heritage prize", "Gain 2 points if you own at least 2 parks.", "The jury loves a city with room to breathe.", "rosette", "+2",
		{"op": "points_if", "cond": "count_min", "kinds": [K.PARK], "min": 2, "n": 2}],
	["clean_air_award", "Clean air award", "Gain 1 point and 4 gold if your pollution is 5 or less.", "The air monitor on the town hall has never been so green.", "trees", "+4g +1",
		{"op": "all", "fxs": [{"op": "points_if", "cond": "pollution_max", "max": 5, "n": 1}, {"op": "gold_if", "cond": "pollution_max", "max": 5, "n": 4}]}],
	["bus_network", "New bus network", "Gain 1 point and 4 gold if your roads connect every home to a place it can use.", "A bus every ten minutes, and it is even on time.", "bus", "+4g +1",
		{"op": "all", "fxs": [{"op": "points_if", "cond": "connected", "n": 1}, {"op": "gold_if", "cond": "connected", "n": 4}]}],
	["city_marathon", "City marathon", "Every player gains 2 gold. The player with the fewest points gains 2 points.", "Thousands run past your door, and the last one in still gets a medal.", "bike", "+2g",
		{"op": "all", "fxs": [{"op": "gold_all", "n": 2}, {"op": "points_stat", "stat": "score", "mode": "min", "n": 2}]}],
	["open_air_concert", "Open-air concert", "Gain 1 point for each park you own (up to 3).", "Blankets on the grass and a very good brass section.", "festival", "+1 each",
		{"op": "points_per", "kinds": [K.PARK], "n": 1, "cap": 3}],
	["rookie_boost", "Rookie boost", "The player with the fewest citizens gains 2 points.", "A warm welcome for the newest neighbourhood.", "housing", "+2",
		{"op": "points_stat", "stat": "citizens", "mode": "min", "n": 2}],
	["food_fair", "Food fair", "Gain 1 point for each coffee shop and restaurant you own (up to 2).", "Every stall has a queue and a story.", "coffee", "+1 each",
		{"op": "points_per", "kinds": EATING, "n": 1, "cap": 2}],
	["grand_opening", "Grand opening", "Gain 5 gold and 1 point if you own a market or a supermarket.", "Balloons, a brass band and free olives for the first hundred.", "shop", "+5g",
		{"op": "all", "fxs": [{"op": "gold_if", "cond": "has_kind", "kinds": [K.MARKET, K.SUPERMARKET], "n": 5},
			{"op": "points_if", "cond": "has_kind", "kinds": [K.MARKET, K.SUPERMARKET], "n": 1}]}],
	["scholarship_fund", "Scholarship fund", "Gain 1 point for each school and university you own (up to 3).", "A donor pays for every bright child in town.", "school", "+1 each",
		{"op": "points_per", "kinds": [K.SCHOOL, K.UNIVERSITY], "n": 1, "cap": 3}],
	["sponsor_deal", "Sponsor deal", "Gain 2 gold for each home you own (up to 4).", "A local bank sponsors the new house numbers.", "housing", "+2g each",
		{"op": "gold_per", "kinds": HOMES, "n": 2, "cap": 4}],
	["community_garden", "Community garden", "Every player who owns a park gains 1 point.", "Tomatoes, beans and some very strong opinions about compost.", "park", "+1",
		{"op": "points_all_if", "cond": "has_kind", "kinds": [K.PARK], "n": 1}],
	["mayors_medal", "Mayor's medal", "Choose 2 points or 10 gold.", "A medal for your work, or an envelope. The mayor does not mind.", "trophy", "choose",
		{"op": "choice", "options": [
			{"label": "2 points", "fx": {"op": "points_self", "n": 2}},
			{"label": "10 gold", "fx": {"op": "gold_self", "n": 10}}]}],
]

# --------------------------------------------------------------------------- penalties

const PENALTY_DATA := [
	["environmental_fine", "Environmental fine", "The player with the highest pollution pays 7 gold.", "The inspectors hold their noses.", "smog", "-7g",
		{"op": "gold_stat", "stat": "pollution", "mode": "max", "n": -7}],
	["administrative_fee", "Administrative fee", "Every player pays 5 gold.", "A form for every form, and a fee for every stamp.", "bureaucracy", "-5g",
		{"op": "gold_all", "n": -5}],
	["tax_audit", "Tax audit", "You pay 1 gold for every 3 tiles you own (up to 12).", "The auditor has brought her own pen.", "audit", "-1g per 3",
		{"op": "gold_stat_per", "stat": "tiles", "per": -1, "every": 3, "cap": 12}],
	["wealth_levy", "Wealth levy", "The richest player pays 8 gold.", "Whoever has the most is asked to share.", "tax", "-8g",
		{"op": "gold_stat", "stat": "money", "mode": "max", "n": -8}],
	["emergency_repairs", "Emergency repairs", "You pay 1 gold for every 2 citizens you house (up to 10).", "Something is leaking, and nobody knows from where.", "repairs", "-1g per 2",
		{"op": "gold_stat_per", "stat": "citizens", "per": -1, "every": 2, "cap": 10}],
	["loan_inspection", "Loan inspection", "The player with the most loans pays 8 gold.", "The bank wants to see the books. All of them.", "audit", "-8g",
		{"op": "gold_stat", "stat": "loans", "mode": "max", "n": -8}],
	["construction_delays", "Construction delays", "You pay 1 gold for every 2 roads you own (up to 8).", "The diversion sign has been here since spring.", "traffic", "-1g per 2",
		{"op": "gold_stat_per", "stat": "roads", "per": -1, "every": 2, "cap": 8}],
	["building_maintenance", "Building maintenance", "You pay 2 gold for each home you own (up to 4).", "Every lift in town breaks on the same day.", "repairs", "-2g each",
		{"op": "gold_per", "kinds": HOMES, "n": -2, "cap": 4}],
	["parking_fines", "Parking fines", "You pay 2 gold for each parking place you own (up to 4).", "Somebody has to pay the warden.", "fine", "-2g each",
		{"op": "gold_per", "kinds": [K.PARKING], "n": -2, "cap": 4}],
	["noise_complaints", "Noise complaints", "You pay 2 gold for each coffee shop and restaurant you own (up to 4).", "The neighbours want to sleep. Loudly.", "protest", "-2g each",
		{"op": "gold_per", "kinds": EATING, "n": -2, "cap": 4}],
	["pickpockets", "Pickpockets", "You lose 6 gold.", "A very polite thief in a very good hat.", "theft", "-6g",
		{"op": "gold_self", "n": -6}],
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
	["smog_scandal", "Smog scandal", "The player with the highest pollution loses 2 points.", "The evening news shows a very grey skyline.", "smog", "-2",
		{"op": "points_stat", "stat": "pollution", "mode": "max", "n": -2}],
	["public_protest", "Public protest", "The player with the most unhappy citizens loses 2 points.", "Banners fill the high street.", "protest", "-2",
		{"op": "points_stat", "stat": "unhappy", "mode": "max", "n": -2}],
	["bad_press", "Bad press", "You lose 2 points.", "A reporter asks one question too many.", "scandal", "-2",
		{"op": "points_self", "n": -2}],
	["failed_inspection", "Failed inspection", "Lose 1 point for each unused service you own (up to 3).", "Empty counters and dusty shelves.", "audit", "-1 each",
		{"op": "points_stat_per", "stat": "unused", "per": -1, "cap": 3}],
	["overcrowded_flats", "Overcrowded flats", "Lose 1 point for each large apartment you own (up to 3).", "Six people, one bathroom.", "unhappy", "-1 each",
		{"op": "points_per", "kinds": [K.APT_L], "n": -1, "cap": 3}],
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
	["debt_scandal", "Debt scandal", "Lose 3 points if you have taken a loan.", "Your name is on the front page, next to the bank's.", "scandal", "-3",
		{"op": "points_if", "cond": "has_loans", "n": -3}],
	["sinkhole", "Sinkhole", "Lose a road tile of your choice.", "The street opens like a mouth.", "sinkhole", "-1 road",
		{"op": "lose_roads", "n": 1}],
	["storm_damage", "Storm damage", "Lose one trees tile.", "Last night's wind took the oldest tree.", "storm", "-1 trees",
		{"op": "lose_tile", "kinds": [K.TREES], "n": 1}],
	["shop_fire", "Shop fire", "Lose a kiosk, coffee shop or restaurant of your choice.", "A kitchen towel, a candle, and a long night.", "fire", "-1 shop",
		{"op": "lose_tile", "kinds": [K.KIOSK, K.COFFEE_SHOP, K.RESTAURANT], "n": 1}],
	["vandals", "Vandals", "Lose a parking place of your choice.", "The barrier is gone and so is the sign.", "theft", "-1 parking",
		{"op": "lose_tile", "kinds": [K.PARKING], "n": 1}],
	["flooded_streets", "Flooded streets", "Lose 2 road tiles.", "The drains were last cleaned in 1998.", "flood", "-2 roads",
		{"op": "lose_roads", "n": 2}],
	["landslide", "Landslide", "Lose 3 road tiles.", "The hillside gives up all at once.", "sinkhole", "-3 roads",
		{"op": "lose_roads", "n": 3}],
	["demolition_order", "Demolition order", "Pay 9 gold, or lose a commercial area of your choice.", "The permit was for a different building.", "demolition", "choose",
		{"op": "choice", "options": [
			{"label": "Pay 9 gold", "fx": {"op": "gold_self", "n": -9}},
			{"label": "Lose a commercial area", "fx": {"op": "lose_tile", "kinds": [K.COMMERCIAL], "n": 1}}]}],
	["beetle_attack", "Beetle attack", "Lose 2 trees tiles.", "Tiny bugs, enormous appetite.", "pests", "-2 trees",
		{"op": "lose_tile", "kinds": [K.TREES], "n": 2}],
	["park_closure", "Park closure", "Pay 7 gold, or lose a park of your choice.", "The council cannot afford to keep the gates open.", "storm", "choose",
		{"op": "choice", "options": [
			{"label": "Pay 7 gold", "fx": {"op": "gold_self", "n": -7}},
			{"label": "Lose a park", "fx": {"op": "lose_tile", "kinds": [K.PARK], "n": 1}}]}],
	["general_strike", "General strike", "You may buy 1 fewer tile this turn.", "The cement lorries are parked in a long line.", "strike", "-1 buy",
		{"op": "buy_bonus", "n": -1}],
	["price_hike", "Price hike", "Every tile costs 2 gold more this turn.", "Bricks, bags and the builder's lunch: all dearer.", "price", "all +2g",
		{"op": "markup_all", "n": 2}],
	["material_shortage", "Material shortage", "Homes cost 3 gold more this turn.", "The steel shipment is stuck at the port.", "shortage", "homes +3g",
		{"op": "markup", "kinds": HOMES, "by": 3}],
	["plant_shortage", "Plant shortage", "Parks and trees cost 3 gold more this turn.", "The nursery has sold out of everything green.", "pests", "green +3g",
		{"op": "markup", "kinds": GREEN, "by": 3}],
	["import_duty", "Import duty", "Shops, cafes and services cost 2 gold more this turn.", "New customs rules for new shop fittings.", "price", "services +2g",
		{"op": "markup", "kinds": SERVICES, "by": 2}],
	["lost_permits", "Lost permits", "You lose one of your free roads.", "The folder was on the bus. Nobody saw it since.", "bureaucracy", "-1 free road",
		{"op": "lose_free_roads", "n": 1}],
	["planning_dispute", "Planning dispute", "You lose 2 of your free roads.", "Two neighbours, one boundary, a lot of lawyers.", "bureaucracy", "-2 free roads",
		{"op": "lose_free_roads", "n": 2}],
	["burst_pipe", "Burst pipe", "Pay 5 gold, or lose 2 road tiles of your choice.", "Water everywhere, and the plumber is on holiday.", "flood", "choose",
		{"op": "choice", "options": [
			{"label": "Pay 5 gold", "fx": {"op": "gold_self", "n": -5}},
			{"label": "Lose 2 road tiles", "fx": {"op": "lose_roads", "n": 2}}]}],
	["empty_shelves", "Empty shelves", "Lose 2 points if you own no supermarket or market.", "Residents shop two villages away.", "shortage", "-2",
		{"op": "points_if", "cond": "lacks_kind", "kinds": [K.SUPERMARKET, K.MARKET], "n": -2}],
	["bribery_scandal", "Bribery scandal", "Pay 6 gold or lose 2 points.", "An envelope was found in the wrong drawer.", "scandal", "choose",
		{"op": "choice", "options": [
			{"label": "Pay 6 gold", "fx": {"op": "gold_self", "n": -6}},
			{"label": "Lose 2 points", "fx": {"op": "points_self", "n": -2}}]}],
	["contractor_demands", "Contractor demands", "Pay 5 gold, or buy 1 fewer tile this turn.", "The foreman has opinions about the schedule.", "strike", "choose",
		{"op": "choice", "options": [
			{"label": "Pay 5 gold", "fx": {"op": "gold_self", "n": -5}},
			{"label": "Buy 1 fewer tile", "fx": {"op": "buy_bonus", "n": -1}}]}],
	["protest_march", "Protest march", "Pay 8 gold or lose 3 points.", "A thousand placards, one town hall.", "protest", "choose",
		{"op": "choice", "options": [
			{"label": "Pay 8 gold", "fx": {"op": "gold_self", "n": -8}},
			{"label": "Lose 3 points", "fx": {"op": "points_self", "n": -3}}]}],
	["rival_developer", "Rival developer", "The richest player gives 4 gold to the poorest.", "A clever lawyer moves money from one pocket to another.", "tax", "-4g",
		{"op": "transfer", "n": 4}],
	["bad_day", "Bad day at the office", "You pay 5 gold and lose 1 point.", "Wrong stamp, wrong day, wrong desk.", "bureaucracy", "-5g -1",
		{"op": "all", "fxs": [{"op": "gold_self", "n": -5}, {"op": "points_self", "n": -1}]}],
	# --- added later: heavier cards with points, and cards aimed at whoever is ahead
	["power_cut", "Power cut", "The player with the most homes pays 5 gold and loses 1 point.", "The whole street sits in the dark and complains by candlelight.", "blackout", "-5g",
		{"op": "all", "fxs": [{"op": "gold_stat", "stat": "homes", "mode": "max", "n": -5}, {"op": "points_stat", "stat": "homes", "mode": "max", "n": -1}]}],
	["flu_season", "Flu season", "Every player without a clinic or hospital loses 1 point.", "Half the town is sneezing, and the nearest doctor is a long walk away.", "shortage", "-1",
		{"op": "points_all_if", "cond": "lacks_kind", "kinds": HEALTH, "n": -1}],
	["tenants_strike", "Tenants' strike", "Lose 1 point for each student residence you own (up to 2).", "The rent went up and the heating went down.", "strike", "-1 each",
		{"op": "points_per", "kinds": STUDENT_HOMES, "n": -1, "cap": 2}],
	["safety_audit", "Safety audit", "You pay 4 gold and lose 1 point.", "The inspector found one loose handrail. And a list.", "audit", "-4g -1",
		{"op": "all", "fxs": [{"op": "gold_self", "n": -4}, {"op": "points_self", "n": -1}]}],
	["diplomatic_incident", "Diplomatic incident", "Pay 6 gold, or lose a restaurant of your choice.", "A state dinner goes wrong and the embassy wants an apology.", "scandal", "choose",
		{"op": "choice", "options": [
			{"label": "Pay 6 gold", "fx": {"op": "gold_self", "n": -6}},
			{"label": "Lose a restaurant", "fx": {"op": "lose_tile", "kinds": [K.RESTAURANT], "n": 1}}]}],
	["gas_leak", "Gas leak", "Lose 2 points if your pollution is 8 or more.", "The whole district smells like a bad egg.", "smog", "-2",
		{"op": "points_if", "cond": "pollution_min", "min": 8, "n": -2}],
	["gridlock", "Gridlock", "Lose 2 points if any home has no route to a place it can use.", "The bus has been stuck behind the same lorry since breakfast.", "traffic", "-2",
		{"op": "points_if", "cond": "not_connected", "n": -2}],
	["interest_due", "Interest due", "Pay 5 gold for each loan you have (up to 2).", "The bank sends a polite reminder in very large letters.", "tax", "-5g each",
		{"op": "gold_stat_per", "stat": "loans", "per": -5, "cap": 2}],
	["property_tax", "Property tax", "You pay 4 gold for each large apartment you own (up to 3).", "Big views, big bills.", "tax", "-4g each",
		{"op": "gold_per", "kinds": [K.APT_L], "n": -4, "cap": 3}],
	["stormy_night", "Stormy night", "Every player pays 3 gold. The player with the most unhappy citizens loses 1 point.", "Shutters bang and nobody gets any sleep.", "storm", "-3g",
		{"op": "all", "fxs": [{"op": "gold_all", "n": -3}, {"op": "points_stat", "stat": "unhappy", "mode": "max", "n": -1}]}],
	["rent_hike", "Rent hike", "Pay 4 gold or lose 1 point.", "The landlord has discovered the word inflation.", "price", "choose",
		{"op": "choice", "options": [
			{"label": "Pay 4 gold", "fx": {"op": "gold_self", "n": -4}},
			{"label": "Lose 1 point", "fx": {"op": "points_self", "n": -1}}]}],
	["greedy_headline", "Greedy headline", "The player with the most gold loses 2 points.", "NEWSPAPER: Who has all the gold in Egkomi?", "scandal", "-2",
		{"op": "points_stat", "stat": "money", "mode": "max", "n": -2}],
	["crumbling_school", "Crumbling school", "Pay 6 gold, or lose a school of your choice.", "The roof of the gym has opinions about gravity.", "demolition", "choose",
		{"op": "choice", "options": [
			{"label": "Pay 6 gold", "fx": {"op": "gold_self", "n": -6}},
			{"label": "Lose a school", "fx": {"op": "lose_tile", "kinds": [K.SCHOOL], "n": 1}}]}],
	["overdue_taxes", "Overdue taxes", "The player with the most gold pays 6 gold and loses 1 point.", "The tax office remembers the biggest wallet.", "tax", "-6g",
		{"op": "all", "fxs": [{"op": "gold_stat", "stat": "money", "mode": "max", "n": -6}, {"op": "points_stat", "stat": "money", "mode": "max", "n": -1}]}],
]

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


static func art_path(id: String) -> String:
	return "res://assets/cards/%s.svg" % id


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
