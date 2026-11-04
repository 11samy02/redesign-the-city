extends "res://tests/test_base.gd"

const Scoring = preload("res://scripts/core/scoring.gd")
const CircumstanceDefs = preload("res://scripts/core/circumstance_defs.gd")

const CLEAN := "PPP...."
const EMPTY := "......."
const K := TileDefs.Kind


## A citizen with nothing special going on; tests override what the card looks at.
func _ctx(over := {}) -> Dictionary:
	var c := {
		"role": "worker", "needs": {}, "routes": {}, "nearest_kind": {}, "heat": 0, "green": 0,
		"has_park": false, "pollution": 4, "parking_adjacent": false, "bike_route": false,
		"pedestrian_route": false, "so_far": 0, "long_route": 3, "like": false, "dislike": false,
	}
	c.merge(over, true)
	return c


func _member(cells: Array, circumstances: Array, home := 0, member := 0) -> Dictionary:
	for a in Scoring.evaluate(cells, 0, circumstances)["apartments"]:
		if a["index"] == at(home):
			return a["members"][member]
	return {}


func test_deck_has_32_unique_cards_with_text_and_a_family() -> void:
	eq(CircumstanceDefs.IDS.size(), 24, "deck size")
	var seen := {}
	for id in CircumstanceDefs.IDS:
		check(not seen.has(id), "%s is unique" % id)
		seen[id] = true
		var d: Dictionary = CircumstanceDefs.info(id)
		for k in ["title", "family", "art", "badge", "key", "icon", "tint", "story", "rule", "tip"]:
			check(d.has(k) and String(d[k]) != "", "%s has %s" % [id, k])
		check(String(d["rule"]).contains(d["key"]), "%s: the key words appear in the rule" % id)
		check(d["family"] in [CircumstanceDefs.FAMILY_WEATHER, CircumstanceDefs.FAMILY_CITY], "%s family" % id)
		eq(CircumstanceDefs.number(id), CircumstanceDefs.IDS.find(id) + 1, "%s number" % id)


func test_the_deck_is_half_good_and_half_bad() -> void:
	var good := 0
	for id in CircumstanceDefs.IDS:
		var badge: String = CircumstanceDefs.badge(id)
		check(badge.begins_with("+") or badge.begins_with("-"), "%s badge has a sign" % id)
		if CircumstanceDefs.is_good(id):
			good += 1
	eq(good, 10, "good cards: the 17 old cards lean bad, so the 7 new ones lean good")


func test_old_cards_are_rebalanced() -> void:
	eq(CircumstanceDefs.BUDGET_CUT, 8, "budget cut")
	eq(CircumstanceDefs.GRANT_BASE, 6, "grant base")
	eq(CircumstanceDefs.GRANT_PER_GREEN, 2, "grant per green")
	eq(CircumstanceDefs.ATTRACTOR_MIN_HOMES, 3, "attractor homes")


func test_gold_changes() -> void:
	var green := mat(["PPT....", EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY])
	var shops := mat(["CCC....", EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY])
	var none := mat([EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY])
	eq(CircumstanceDefs.gold_change("budget_cut", none), -8, "budget cut")
	eq(CircumstanceDefs.gold_change("grant", none), 6, "grant on an empty mat")
	eq(CircumstanceDefs.gold_change("grant", green), 12, "grant with 2 parks and 1 tree")
	eq(CircumstanceDefs.gold_change("business_boom", shops), 6, "business boom with 3 commercial areas")
	eq(CircumstanceDefs.gold_change("business_boom", none), 0, "business boom without any")
	eq(CircumstanceDefs.gold_change("tax_refund", none), 8, "tax refund")
	for id in ["heatwave", "exam_season", "bike_week", "new_attractor", "science_fair", "farmers_market"]:
		eq(CircumstanceDefs.gold_change(id, green), 0, "%s does not touch gold" % id)
	var roads := mat(["RRRRRRR", EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY])
	var homes := mat(["ssmmllu", "u......", EMPTY, EMPTY, EMPTY, EMPTY, EMPTY])
	eq(CircumstanceDefs.gold_change("road_subsidy", none), 0, "road subsidy without roads")
	eq(CircumstanceDefs.gold_change("road_subsidy", roads), 7, "road subsidy: 1 gold for each of the 7 roads on the row")
	var many := mat(["RRRRRRR", "RRR....", EMPTY, EMPTY, EMPTY, EMPTY, EMPTY])
	eq(CircumstanceDefs.gold_change("road_subsidy", many), 8, "road subsidy stops at 8 roads")
	eq(CircumstanceDefs.gold_change("pipe_repairs", none), 0, "pipe repairs without homes")
	eq(CircumstanceDefs.gold_change("pipe_repairs", homes), -6, "pipe repairs stop at 6 homes")
	eq(CircumstanceDefs.gold_change("pipe_repairs", shops), 0, "shops do not count as homes")


# each case: [card, role, context overrides, expected change when it applies]
func test_every_happiness_card_applies_where_it_should() -> void:
	var long_shaded := {1: {"length": 3, "shaded": true, "kind": K.SUPERMARKET}}
	var long_bare := {1: {"length": 3, "shaded": false, "kind": K.SUPERMARKET}}
	var cases := [
		["heatwave", "worker", {"heat": 1}, -1],
		["flash_flood", "worker", {"routes": long_bare, "green": 0}, -1],
		["dust_storm", "worker", {"pollution": 9}, -1],
		["nice_weather", "worker", {"routes": long_shaded}, 1],
		["road_works", "worker", {"routes": long_bare}, -1],
		["population_growth", "worker", {"so_far": 1}, 1],
		["exam_season", "student", {"needs": {"library": false}}, -1],
		["flu_wave", "older", {"nearest_kind": {}}, -1],
		["flu_wave", "child", {"nearest_kind": {}}, -1],
		["flu_wave", "access", {"nearest_kind": {}}, -1],
		["parking_shortage", "expat", {"nearest_kind": {}}, -1],
		["parking_shortage", "access", {"nearest_kind": {}}, -1],
		["cold_snap", "access", {"green": 0}, -1],
		["supply_shortage", "older", {"needs": {"groceries": true}, "nearest_kind": {K.SUPERMARKET: 5}}, -1],
		["supply_shortage", "worker", {"needs": {"groceries": false}, "nearest_kind": {}}, -1],
		["back_to_school", "child", {"needs": {"school": false}}, -1],
		["parking_shortage", "student", {"nearest_kind": {}}, -1],
		["parking_shortage", "older", {"nearest_kind": {}}, -1],
		["traffic_jam", "worker", {"parking_adjacent": true}, -1],
		["drought", "worker", {"green": 1, "has_park": false}, -1],
		["bike_week", "student", {"bike_route": true}, 1],
		["street_festival", "child", {"pedestrian_route": true}, 1],
		["remote_work", "worker", {"nearest_kind": {K.COFFEE_SHOP: 2}}, 1],
		["remote_work", "worker", {"nearest_kind": {K.KIOSK: 1}}, 1],
		["autumn_rain", "worker", {"has_park": true}, 1],
		["smog_alert", "worker", {"pollution": 6, "has_park": false}, -1],
		["cold_snap", "older", {"green": 0}, -1],
		["cold_snap", "child", {"green": 0}, -1],
		["farmers_market", "older", {"nearest_kind": {K.MARKET: 4}}, 1],
		["farmers_market", "worker", {"nearest_kind": {K.SUPERMARKET: 1}}, 1],
		["bus_strike", "worker", {"routes": {1: {"length": 3, "shaded": false, "kind": K.SUPERMARKET}}, "nearest_kind": {}}, -1],
	]
	for c in cases:
		eq(CircumstanceDefs.member_effect(c[0], _ctx(merge(c[2], {"role": c[1]}))), c[3], "%s hits a %s" % [c[0], c[1]])


# each case: [card, role, context overrides] where the card must do nothing
func test_every_happiness_card_leaves_others_alone() -> void:
	var short_route := {1: {"length": 1, "shaded": false, "kind": K.SUPERMARKET}}
	var cases := [
		["heatwave", "worker", {"heat": 0}],
		["flash_flood", "worker", {"routes": short_route, "green": 0}],
		["flash_flood", "worker", {"routes": {1: {"length": 3, "shaded": false, "kind": K.SUPERMARKET}}, "green": 1}],
		["dust_storm", "worker", {"pollution": 8}],
		["nice_weather", "worker", {"routes": {1: {"length": 3, "shaded": false, "kind": K.SUPERMARKET}}}],
		["road_works", "worker", {"routes": short_route}],
		["road_works", "worker", {"routes": {}}],
		["population_growth", "worker", {"so_far": 0}],
		["exam_season", "student", {"needs": {"library": true}}],
		["exam_season", "worker", {"needs": {"library": false}}],
		["flu_wave", "older", {"nearest_kind": {K.CLINIC: 2}}],
		["flu_wave", "worker", {"nearest_kind": {}}],
		["flu_wave", "expat", {"nearest_kind": {}}],
		["flu_wave", "access", {"nearest_kind": {K.CLINIC: 2}}],
		["supply_shortage", "older", {"needs": {"groceries": true}, "nearest_kind": {K.MARKET: 4}}],
		["supply_shortage", "student", {"needs": {}, "nearest_kind": {}}],
		["back_to_school", "child", {"needs": {"school": true}}],
		["back_to_school", "worker", {"needs": {}}],
		["parking_shortage", "student", {"nearest_kind": {K.PARKING: 2}}],
		["parking_shortage", "child", {"nearest_kind": {}}],
		["traffic_jam", "worker", {"parking_adjacent": false}],
		["drought", "worker", {"green": 1, "has_park": true}],
		["drought", "worker", {"green": 0, "has_park": false}],
		["bike_week", "student", {"bike_route": false}],
		["street_festival", "child", {"pedestrian_route": false}],
		["remote_work", "student", {"nearest_kind": {K.COFFEE_SHOP: 1}}],
		["remote_work", "worker", {"nearest_kind": {K.RESTAURANT: 1}}],
		["tax_refund", "worker", {}],
		["budget_cut", "worker", {}],
		["autumn_rain", "worker", {"has_park": false}],
		["smog_alert", "worker", {"pollution": 5, "has_park": false}],
		["smog_alert", "worker", {"pollution": 9, "has_park": true}],
		["cold_snap", "older", {"green": 1}],
		["cold_snap", "worker", {"green": 0}],
		["farmers_market", "older", {"nearest_kind": {K.MARKET: 5}}],
		["farmers_market", "worker", {"nearest_kind": {K.KIOSK: 1}}],
		["bus_strike", "worker", {"routes": {1: {"length": 2, "shaded": false, "kind": K.SUPERMARKET}}, "nearest_kind": {}}],
		["bus_strike", "worker", {"routes": {1: {"length": 3, "shaded": false, "kind": K.SUPERMARKET}}, "nearest_kind": {K.PARKING: 2}}],
		["science_fair", "worker", {}],
		["road_subsidy", "worker", {}],
		["pipe_repairs", "worker", {}],
	]
	for c in cases:
		eq(CircumstanceDefs.member_effect(c[0], _ctx(merge(c[2], {"role": c[1]}))), 0, "%s spares a %s" % [c[0], c[1]])


func merge(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := a.duplicate()
	out.merge(b, true)
	return out


func test_the_cards_added_in_the_rework() -> void:
	var near := {"routes": {1: {"length": 3, "shaded": false, "kind": K.CLINIC}}}
	var far := {"routes": {1: {"length": 6, "shaded": false, "kind": K.CLINIC}}}
	var cases := [
		["step_free_streets", merge(near, {"role": "older"}), 1], ["step_free_streets", merge(near, {"role": "worker"}), 0],
		["step_free_streets", merge(far, {"role": "access"}), 0],
		["short_walks", merge(near, {"role": "student"}), 1], ["short_walks", merge(far, {"role": "worker"}), 0],
		["short_walks", merge(near, {"role": "child"}), 0],
		["playground_day", {"role": "child", "has_park": true}, 1], ["playground_day", {"role": "worker", "has_park": true}, 0],
		["tree_lined_walks", {"green": 2}, 1], ["tree_lined_walks", {"green": 1}, 0],
		["night_noise", {"dislike": true}, -1], ["night_noise", {"dislike": false}, 0],
		["neighbourhood_spirit", {"like": true}, 1], ["neighbourhood_spirit", {"like": false}, 0],
		["park_stroll", {"has_park": true, "pedestrian_route": true}, 1], ["park_stroll", {"has_park": true}, 0],
	]
	for c in cases:
		eq(CircumstanceDefs.member_effect(c[0], _ctx(c[1])), c[2], "%s with %s" % [c[0], str(c[1])])


func test_the_hidden_deck_has_24_cards_that_each_answer_an_objective() -> void:
	eq(CircumstanceDefs.IDS.size(), 24, "24 hidden cards")
	for id in CircumstanceDefs.IDS:
		var o: Array = CircumstanceDefs.objectives(id)
		check(not o.is_empty(), "%s answers an objective" % id)
		check(FileAccess.file_exists(CircumstanceDefs.art_path(id)), "%s has art" % id)


func test_science_fair_rewards_busy_schools() -> void:
	var cells := mat(["h.F....", EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY])
	var stats := {"cells": cells, "served_homes": {at(0): 3, at(2): 4}, "served_student_homes": {}}
	eq(CircumstanceDefs.point_bonus("science_fair", stats), [at(0)], "only the school with 3+ homes")
	stats["served_homes"] = {at(0): 2}
	eq(CircumstanceDefs.point_bonus("science_fair", stats), [], "too few homes")


func test_point_cards_need_enough_homes() -> void:
	var cells := mat(["F.C.U..", EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY])
	var stats := {"cells": cells, "served_homes": {at(0): 3, at(2): 2, at(4): 3}, "served_student_homes": {at(4): 2}}
	eq(CircumstanceDefs.point_bonus("new_attractor", stats), [at(0), at(4)], "attractors: services with 3+ homes")
	eq(CircumstanceDefs.point_bonus("tourist_season", stats), [at(0)], "tourist season: coffee shop with 3 homes")
	eq(CircumstanceDefs.point_bonus("open_day", stats), [at(4)], "open day: university with 2 student homes")
	eq(CircumstanceDefs.point_bonus("health_campaign", stats), [], "health campaign: no clinic here")
	stats["served_student_homes"] = {at(4): 1}
	eq(CircumstanceDefs.point_bonus("open_day", stats), [], "open day needs 2 student homes")


func test_no_cards_changes_nothing() -> void:
	var cells := mat(["uRRR...", ".ULF...", EMPTY, EMPTY, EMPTY, EMPTY, CLEAN])
	eq(_member(cells, [])["effects"], {}, "no effects without cards")


func test_exam_season_hits_a_student_without_a_library() -> void:
	var cells := mat(["uRR....", ".U.....", EMPTY, EMPTY, EMPTY, EMPTY, CLEAN])
	var before := _member(cells, [])
	var after := _member(cells, ["exam_season"])
	eq(after["effects"], {"exam_season": -1}, "recorded effect")
	eq(after["happiness"], before["happiness"] - 1, "one point lower")


func test_exam_season_spares_a_student_with_a_library() -> void:
	var cells := mat(["uRRR...", ".ULF...", EMPTY, EMPTY, EMPTY, EMPTY, CLEAN])
	eq(_member(cells, ["exam_season"])["effects"], {}, "no effect")


func test_back_to_school_hits_the_child_not_the_parent() -> void:
	var cells := mat([EMPTY, "..mR...", EMPTY, EMPTY, EMPTY, EMPTY, CLEAN], {9: 2})
	eq(_member(cells, ["back_to_school"], 9, 0)["effects"], {}, "worker")
	eq(_member(cells, ["back_to_school"], 9, 1)["effects"], {"back_to_school": -1}, "child")


func test_a_need_card_becomes_an_accessibility_complaint() -> void:
	# the student is unhappy and the card is what tipped it
	var cells := mat(["uRR....", ".UL....", EMPTY, EMPTY, EMPTY, EMPTY, EMPTY])
	var m := _member(cells, ["exam_season"])
	eq(m["effects"], {}, "library is reached, so exam season spares this student")
	var without := mat(["uRR....", ".U.....", EMPTY, EMPTY, EMPTY, EMPTY, EMPTY])
	eq(_member(without, ["exam_season"])["complaint"], "Accessibility", "unmet need stays the complaint")


func test_attractor_bonus_is_counted_in_the_total() -> void:
	# three homes share one supermarket
	var rows := ["sRs....", ".RS....", ".R.....", "sR.....", EMPTY, EMPTY, CLEAN]
	var base := Scoring.evaluate(mat(rows), 0, [])
	var with_card := Scoring.evaluate(mat(rows), 0, ["new_attractor"])
	eq(with_card["circumstance_bonus"], 1, "one shared supermarket")
	eq(with_card["attractors"], [at(9)], "the supermarket cell")
	eq(with_card["total"], base["total"] + 1, "total")


func test_effects_stack_and_stay_inside_the_happiness_range() -> void:
	var cells := mat(["uRR....", ".U.....", EMPTY, EMPTY, EMPTY, EMPTY, EMPTY])
	var m := _member(cells, ["exam_season", "dust_storm", "parking_shortage"])
	check(m["happiness"] >= Scoring.HAPPY_MIN, "never below the happiness floor")
	check(m["raw"] < m["happiness"] or m["raw"] == m["happiness"], "raw can run past the cap, happiness cannot")


func test_every_card_has_art_and_an_icon_on_disk() -> void:
	for id in CircumstanceDefs.IDS:
		check(FileAccess.file_exists(CircumstanceDefs.art_path(id)), "card art for %s" % id)
		check(FileAccess.file_exists(CircumstanceDefs.icon_path(id)), "icon for %s" % id)


func test_happiness_shows_as_a_signed_number_and_a_smiley_not_as_the_word() -> void:
	var Face = load("res://scripts/game/circumstance_card_face.gd")
	var lose: String = Face.happiness_icons("Citizens with a long walk lose 1 happiness.", "00AA00", "CC0000", 27)
	check(not lose.contains("happiness") and not lose.contains("lose"), "no word is left next to the picture")
	check(lose.contains("-1") and lose.contains("smile_down.svg") and lose.contains("CC0000"), "a red frowning face with -1")
	var gain: String = Face.happiness_icons("Every citizen gains 1 happiness (up to +3).", "00AA00", "CC0000", 27)
	check(gain.contains("gets") and gain.contains("+1") and gain.contains("smile_up.svg") and gain.contains("00AA00"), "a green smiling face with +1")
	var extra: String = Face.happiness_icons("Citizens with no shade lose 1 extra happiness.", "00AA00", "CC0000", 27)
	check(extra.contains("an extra") and extra.contains("smile_down.svg") and not extra.contains("happiness"), "the extra one keeps its meaning")
	for id in CircumstanceDefs.IDS:
		var rule: String = CircumstanceDefs.info(id)["rule"]
		var shown: String = Face.rich_rule(rule, CircumstanceDefs.info(id)["key"], "3F9A2B", 27, false, "")
		if rule.contains("happiness"):
			check(not shown.contains("happiness"), "%s: the card shows a smiley instead of the word" % id)
			check(shown.contains("smile_"), "%s: and the smiley is there" % id)
	for file in ["smile_up", "smile_down"]:
		check(FileAccess.file_exists("res://assets/ui/%s.svg" % file), "%s.svg exists" % file)
