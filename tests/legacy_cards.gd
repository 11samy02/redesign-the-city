extends RefCounted
## The cards that left the game in the cards rework (see the vault note "New Cards rework"), kept only for the tests: they
## exercise every effect the card rules can use (gold for everyone, stealing, transfers, loan relief, price changes, extra buys,
## losing tiles...), including ones that no card in the current decks uses. `ensure(id)` puts a card back into CardDefs for
## the length of a test run, so a test can play it like any other card.

const TileDefs = preload("res://scripts/core/tile_defs.gd")
const CardDefs = preload("res://scripts/core/card_defs.gd")

const K := TileDefs.Kind
const HOMES := CardDefs.HOMES
const SERVICES := CardDefs.SERVICES
const GREEN := CardDefs.GREEN
const SHOPS := CardDefs.SHOPS
const EATING := CardDefs.EATING
const STUDY := CardDefs.STUDY
const HEALTH := CardDefs.HEALTH
const STUDENT_HOMES := CardDefs.STUDENT_HOMES

const EVENT_DATA := [
	["government_funding", "Government funding", "Every player receives 4 gold.", "Nicosia sends a cheque to every neighbourhood board.", "government", "+4g",
		{"op": "gold_all", "n": 4}],
	["regional_grant", "Regional grant", "Every player receives 3 gold. You receive 3 more.", "Your application is the best-written one on the pile.", "government", "+3g",
		{"op": "all", "fxs": [{"op": "gold_all", "n": 3}, {"op": "gold_self", "n": 3}]}],
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
	["newcomers", "Newcomers", "Gain 5 gold and 1 point if you house 10 or more citizens.", "Moving vans line the street all week.", "housing", "+5g",
		{"op": "all", "fxs": [{"op": "gold_if", "cond": "citizens_min", "min": 10, "n": 5},
			{"op": "points_if", "cond": "citizens_min", "min": 10, "n": 1}]}],
	["debt_relief", "Debt relief", "Remove one of your loans, if you have one.", "The bank writes off a loan and sends flowers.", "bank", "-1 loan",
		{"op": "loan_relief"}],
	["road_crew", "Road crew", "You receive 2 extra free roads.", "The municipal crew has a few spare days.", "construction", "+2 roads",
		{"op": "free_roads", "n": 2}],
	["corner_shop_licence", "Corner shop licence", "You receive one free kiosk.", "Paperwork approved in a single afternoon. A first.", "shop", "free kiosk",
		{"op": "free_tile", "kind": K.KIOSK, "n": 1}],
	["cafe_startup", "Cafe start-up", "You receive one free coffee shop.", "A young barista needs a place to open.", "coffee", "free cafe",
		{"op": "free_tile", "kind": K.COFFEE_SHOP, "n": 1}],
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
	["healthy_city", "Healthy city", "Gain 2 points if you own a clinic or a hospital.", "Egkomi tops the regional health table.", "health", "+2",
		{"op": "points_if", "cond": "has_kind", "kinds": HEALTH, "n": 2}],
	["community_day", "Community day", "Every player who owns a coffee shop or restaurant gains 1 point.", "Everyone brings a dish and a chair.", "handshake", "+1",
		{"op": "points_all_if", "cond": "has_kind", "kinds": EATING, "n": 1}],
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
	["city_marathon", "City marathon", "Every player gains 2 gold. The player with the fewest points gains 2 points.", "Thousands run past your door, and the last one in still gets a medal.", "bike", "+2g",
		{"op": "all", "fxs": [{"op": "gold_all", "n": 2}, {"op": "points_stat", "stat": "score", "mode": "min", "n": 2}]}],
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
	["mayors_medal", "Mayor's medal", "Choose 2 points or 10 gold.", "A medal for your work, or an envelope. The mayor does not mind.", "trophy", "choose",
		{"op": "choice", "options": [
			{"label": "2 points", "fx": {"op": "points_self", "n": 2}},
			{"label": "10 gold", "fx": {"op": "gold_self", "n": 10}}]}],
]

const PENALTY_DATA := [
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
	["building_maintenance", "Building maintenance", "You pay 2 gold for each home you own (up to 4).", "Every lift in town breaks on the same day.", "repairs", "-2g each",
		{"op": "gold_per", "kinds": HOMES, "n": -2, "cap": 4}],
	["parking_fines", "Parking fines", "You pay 2 gold for each parking place you own (up to 4).", "Somebody has to pay the warden.", "fine", "-2g each",
		{"op": "gold_per", "kinds": [K.PARKING], "n": -2, "cap": 4}],
	["noise_complaints", "Noise complaints", "You pay 2 gold for each coffee shop and restaurant you own (up to 4).", "The neighbours want to sleep. Loudly.", "protest", "-2g each",
		{"op": "gold_per", "kinds": EATING, "n": -2, "cap": 4}],
	["pickpockets", "Pickpockets", "You lose 6 gold.", "A very polite thief in a very good hat.", "theft", "-6g",
		{"op": "gold_self", "n": -6}],
	["smog_scandal", "Smog scandal", "The player with the highest pollution loses 2 points.", "The evening news shows a very grey skyline.", "smog", "-2",
		{"op": "points_stat", "stat": "pollution", "mode": "max", "n": -2}],
	["bad_press", "Bad press", "You lose 2 points.", "A reporter asks one question too many.", "scandal", "-2",
		{"op": "points_self", "n": -2}],
	["overcrowded_flats", "Overcrowded flats", "Lose 1 point for each large apartment you own (up to 3).", "Six people, one bathroom.", "unhappy", "-1 each",
		{"op": "points_per", "kinds": [K.APT_L], "n": -1, "cap": 3}],
	["debt_scandal", "Debt scandal", "Lose 3 points if you have taken a loan.", "Your name is on the front page, next to the bank's.", "scandal", "-3",
		{"op": "points_if", "cond": "has_loans", "n": -3}],
	["shop_fire", "Shop fire", "Lose a kiosk, coffee shop or restaurant of your choice.", "A kitchen towel, a candle, and a long night.", "fire", "-1 shop",
		{"op": "lose_tile", "kinds": [K.KIOSK, K.COFFEE_SHOP, K.RESTAURANT], "n": 1}],
	["demolition_order", "Demolition order", "Pay 9 gold, or lose a commercial area of your choice.", "The permit was for a different building.", "demolition", "choose",
		{"op": "choice", "options": [
			{"label": "Pay 9 gold", "fx": {"op": "gold_self", "n": -9}},
			{"label": "Lose a commercial area", "fx": {"op": "lose_tile", "kinds": [K.COMMERCIAL], "n": 1}}]}],
	["general_strike", "General strike", "You may buy 1 fewer tile this turn.", "The cement lorries are parked in a long line.", "strike", "-1 buy",
		{"op": "buy_bonus", "n": -1}],
	["price_hike", "Price hike", "Every tile costs 2 gold more this turn.", "Bricks, bags and the builder's lunch: all dearer.", "price", "all +2g",
		{"op": "markup_all", "n": 2}],
	["material_shortage", "Material shortage", "Homes cost 3 gold more this turn.", "The steel shipment is stuck at the port.", "shortage", "homes +3g",
		{"op": "markup", "kinds": HOMES, "by": 3}],
	["import_duty", "Import duty", "Shops, cafes and services cost 2 gold more this turn.", "New customs rules for new shop fittings.", "price", "services +2g",
		{"op": "markup", "kinds": SERVICES, "by": 2}],
	["lost_permits", "Lost permits", "You lose one of your free roads.", "The folder was on the bus. Nobody saw it since.", "bureaucracy", "-1 free road",
		{"op": "lose_free_roads", "n": 1}],
	["planning_dispute", "Planning dispute", "You lose 2 of your free roads.", "Two neighbours, one boundary, a lot of lawyers.", "bureaucracy", "-2 free roads",
		{"op": "lose_free_roads", "n": 2}],
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
	["tenants_strike", "Tenants' strike", "Lose 1 point for each student residence you own (up to 2).", "The rent went up and the heating went down.", "strike", "-1 each",
		{"op": "points_per", "kinds": STUDENT_HOMES, "n": -1, "cap": 2}],
	["safety_audit", "Safety audit", "You pay 4 gold and lose 1 point.", "The inspector found one loose handrail. And a list.", "audit", "-4g -1",
		{"op": "all", "fxs": [{"op": "gold_self", "n": -4}, {"op": "points_self", "n": -1}]}],
	["diplomatic_incident", "Diplomatic incident", "Pay 6 gold, or lose a restaurant of your choice.", "A state dinner goes wrong and the embassy wants an apology.", "scandal", "choose",
		{"op": "choice", "options": [
			{"label": "Pay 6 gold", "fx": {"op": "gold_self", "n": -6}},
			{"label": "Lose a restaurant", "fx": {"op": "lose_tile", "kinds": [K.RESTAURANT], "n": 1}}]}],
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


## Makes sure card `id` can be played: cards of the current decks are always there, the others are added from the lists above.
static func ensure(id: String) -> void:
	if CardDefs.has_card(id):
		return
	for pair in [[CardDefs.EVENT, EVENT_DATA], [CardDefs.PENALTY, PENALTY_DATA]]:
		for e in pair[1]:
			if e[0] == id:
				CardDefs._by_id[id] = {
					"id": id, "type": pair[0], "title": e[1], "rule": e[2], "story": e[3], "motif": e[4],
					"badge": e[5], "fx": e[6], "number": 0, "tint": CardDefs.MOTIF_TINT[e[4]],
				}
				return
	push_error("no card with id %s" % id)
