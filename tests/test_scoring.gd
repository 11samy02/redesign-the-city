extends "res://tests/test_base.gd"

const Scoring = preload("res://scripts/core/scoring.gd")
const Influence = preload("res://scripts/game/influence.gd")
const Roles = preload("res://scripts/core/roles.gd")

## Three parks in the bottom row: pollution 16 - 9 = 7, so no pollution penalty.
const CLEAN := "PPP...."
const EMPTY := "......."


func _home(result: Dictionary, index: int) -> Dictionary:
	for a in result["apartments"]:
		if a["index"] == index:
			return a
	return {}


func _need(member: Dictionary, id: String) -> Dictionary:
	for n in member["needs"]:
		if n["id"] == id:
			return n
	return {}


func test_neighbours_and_park_area_on_7x7() -> void:
	eq(Scoring.SIZE, 7, "mat size")
	eq(Scoring.neighbours(0).size(), 2, "corner")
	eq(Scoring.neighbours(24).size(), 4, "centre")
	eq(Scoring.neighbours(3).size(), 3, "edge")
	check(Scoring.in_park_area(24, 32), "diagonal is in the 3x3")
	check(not Scoring.in_park_area(24, 40), "two away is outside")
	check(not Scoring.in_park_area(24, 24), "a park is not in its own area")


func test_student_with_both_needs_met_and_a_like_reaches_plus_three() -> void:
	var cells := mat(["uRRR...", ".ULF...", EMPTY, EMPTY, EMPTY, EMPTY, CLEAN])
	var home := _home(Scoring.evaluate(cells, 0), 0)
	eq(home["citizens"], 1, "citizens")
	var m: Dictionary = home["members"][0]
	eq(m["role"], "student", "role")
	check(_need(m, "university")["met"], "university met")
	check(_need(m, "library")["met"], "library met")
	check(m["like"], "coffee shop is liked")
	eq(m["happiness"], 3, "happiness")
	eq(home["sp"], 3, "points")
	eq(m["complaint"], "", "no complaint")


func test_unmet_need_files_a_named_complaint() -> void:
	# no parks (pollution penalty 2), no like, library missing
	var cells := mat(["uRR....", ".U.....", EMPTY, EMPTY, EMPTY, EMPTY, EMPTY])
	var home := _home(Scoring.evaluate(cells, 0), 0)
	var m: Dictionary = home["members"][0]
	check(_need(m, "university")["met"], "university met")
	check(not _need(m, "library")["met"], "library missing")
	eq(m["happiness"], -2, "happiness")
	eq(m["complaint"], "Accessibility", "complaint type")
	eq(m["complaint_detail"], "No library within reach", "complaint detail")


func test_one_unmet_need_is_neutral_not_unhappy() -> void:
	var cells := mat(["uRR....", ".U.....", EMPTY, EMPTY, EMPTY, EMPTY, CLEAN])
	var m: Dictionary = _home(Scoring.evaluate(cells, 0), 0)["members"][0]
	eq(m["happiness"], 0, "one need met, none missing penalty")
	eq(m["complaint"], "", "not unhappy, so no complaint")


func test_street_likes_count_for_roads_next_to_the_home() -> void:
	var cells := mat(["uRU....", EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY], {1: TileDefs.STREET_BIKE})
	var m: Dictionary = _home(Scoring.evaluate(cells, 0), 0)["members"][0]
	check(m["like"], "students like the bike lane next door")
	var plain := mat(["uRU....", EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY])
	check(not _home(Scoring.evaluate(plain, 0), 0)["members"][0]["like"], "a plain road is not a like")


func test_child_dislikes_parking_next_door_but_the_parent_does_not() -> void:
	var cells := mat([EMPTY, ".QmR...", EMPTY, EMPTY, EMPTY, EMPTY, CLEAN], {9: 2})
	var home := _home(Scoring.evaluate(cells, 0), 9)
	eq(home["members"].size(), 2, "parent and child")
	eq(home["members"][0]["role"], "worker", "first member")
	eq(home["members"][1]["role"], "child", "second member")
	check(home["members"][1]["dislike"], "child dislikes parking")
	check(not home["members"][0]["dislike"], "worker does not")


func test_parking_within_reach_is_a_like_for_a_worker() -> void:
	var cells := mat(["sRQ....", EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, CLEAN], {0: 0})
	var m: Dictionary = _home(Scoring.evaluate(cells, 0), 0)["members"][0]
	check(m["like"], "worker likes the parking place")


func test_older_feels_heat_twice_a_worker_once_and_shade_removes_it() -> void:
	# unshaded 3-road walk to the supermarket
	var rows := ["sRRR...", "...S...", EMPTY, EMPTY, EMPTY, EMPTY, CLEAN]
	var older: Dictionary = _home(Scoring.evaluate(mat(rows, {0: 1}), 0), 0)["members"][0]
	eq(older["role"], "older", "older role")
	eq(older["heat"], 2, "older heat is doubled")
	var worker: Dictionary = _home(Scoring.evaluate(mat(rows, {0: 0}), 0), 0)["members"][0]
	eq(worker["heat"], 1, "worker heat")
	var shaded := ["sRRR...", "..TS...", EMPTY, EMPTY, EMPTY, EMPTY, CLEAN]
	eq(_home(Scoring.evaluate(mat(shaded, {0: 1}), 0), 0)["members"][0]["heat"], 0, "trees shade the walk")


func test_a_park_in_the_3x3_area_meets_a_childs_need_without_a_road() -> void:
	var near := mat([EMPTY, "..mP...", EMPTY, EMPTY, EMPTY, EMPTY, EMPTY], {9: 2})
	var child: Dictionary = _home(Scoring.evaluate(near, 0), 9)["members"][1]
	check(_need(child, "park")["met"], "park next door")
	var far := mat([EMPTY, "..m.P..", EMPTY, EMPTY, EMPTY, EMPTY, EMPTY], {9: 2})
	child = _home(Scoring.evaluate(far, 0), 9)["members"][1]
	check(not _need(child, "park")["met"], "park two away is too far")


func test_home_points_are_the_sum_of_its_members() -> void:
	var cells := mat([EMPTY, "..lR...", EMPTY, EMPTY, EMPTY, EMPTY, CLEAN], {9: 0})
	var home := _home(Scoring.evaluate(cells, 0), 9)
	var sum := 0
	for m in home["members"]:
		sum += m["happiness"]
	eq(home["members"].size(), 3, "a family has three members")
	eq(home["sp"], sum, "home points")


func test_an_unused_service_costs_a_point() -> void:
	var r := Scoring.evaluate(mat(["L......", EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY]), 0)
	eq(r["unused"], [0], "unused list")
	eq(r["unused_penalty"], 1, "penalty")
	eq(r["total"], -1, "total")


func test_a_service_that_a_home_reaches_is_not_unused() -> void:
	var r := Scoring.evaluate(mat(["uRL....", EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY]), 0)
	eq(r["unused"], [], "nothing unused")


func test_loan_penalty_escalates() -> void:
	eq(Scoring.loan_penalty(0), 0, "no loans")
	eq(Scoring.loan_penalty(1), 6, "one loan")
	eq(Scoring.loan_penalty(2), 15, "two loans")
	eq(Scoring.loan_penalty(3), 27, "three loans")
	eq(Scoring.loan_penalty(4), 42, "the fourth costs 15")
	var r := Scoring.evaluate(mat([EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY]), 2)
	eq(r["loan_penalty"], 15, "result carries the penalty")
	eq(r["total"], -15, "total")


func test_empty_and_homeless_mats_evaluate_cleanly() -> void:
	var r := Scoring.evaluate(mat([EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY]), 0)
	eq(r["total"], 0, "empty total")
	eq(r["citizens"], 0, "empty citizens")
	var roads := Scoring.evaluate(mat(["RRRRRRR", EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY]), 0)
	eq(roads["total"], 0, "roads only")
	eq(roads["apartments"].size(), 0, "no homes")


func test_pollution_scale_for_7x7() -> void:
	var none := Scoring.evaluate(mat([EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY]), 0)
	eq(none["pollution"], 16, "start pollution")
	eq(none["pollution_penalty"], 2, "penalty at 16")
	var green := Scoring.evaluate(mat(["PP.TTT.", EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY]), 0)
	eq(green["pollution"], 7, "two parks and three trees")
	eq(green["pollution_penalty"], 0, "no penalty at 7")
	eq(Scoring.pollution_penalty(13), 2, "13")
	eq(Scoring.pollution_penalty(12), 1, "12")
	eq(Scoring.pollution_penalty(8), 1, "8")
	eq(Scoring.pollution_penalty(7), 0, "7")


func test_roads_next_to_trees_or_a_park_are_shaded() -> void:
	var r := Scoring.evaluate(mat(["RRT....", "P......", EMPTY, EMPTY, EMPTY, EMPTY, EMPTY]), 0)
	check(r["shaded"][1], "road beside trees")
	check(r["shaded"][0], "road beside the park")


func test_a_shaded_route_is_preferred_among_equally_short_ones() -> void:
	# two 3-road ways to the hospital; a tree shades the lower one
	var rows := [".RRR...", ".s.H...", ".RRR...", ".T.....", EMPTY, EMPTY, CLEAN]
	var home := _home(Scoring.evaluate(mat(rows), 0), 8)
	check(home["routes"].has(10), "hospital is reachable")
	eq(home["routes"][10]["length"], 3, "route length")
	check(home["routes"][10]["shaded"], "the shaded way is kept")
	rows[3] = EMPTY
	home = _home(Scoring.evaluate(mat(rows), 0), 8)
	check(not home["routes"][10]["shaded"], "no tree, no shade")


func test_happy_and_unhappy_citizens_are_counted_per_citizen() -> void:
	var happy := mat(["uRRR...", ".ULF...", EMPTY, EMPTY, EMPTY, EMPTY, CLEAN])
	var r := Scoring.evaluate(happy, 0)
	eq(r["happy_citizens"], 1, "happy")
	eq(r["unhappy_citizens"], 0, "unhappy")
	var sad := Scoring.evaluate(mat(["uRR....", ".U.....", EMPTY, EMPTY, EMPTY, EMPTY, EMPTY]), 0)
	eq(sad["unhappy_citizens"], 1, "unhappy")
	eq(sad["complaints"]["Accessibility"], 1, "complaint count")


func test_hovering_a_road_on_an_equally_short_route_still_finds_the_connection() -> void:
	# home 0 and market 8 touch both roads (1 and 7); only one of them is the route that is scored
	var cells := mat(["sR.....", "RM.....", EMPTY, EMPTY, EMPTY, EMPTY, EMPTY])
	var home := _home(Scoring.evaluate(cells, 0), 0)
	var used: int = home["routes"][8]["path"][0]
	var other := 7 if used == 1 else 1
	eq(Influence._alternative_path(cells, 0, 8, other, 1), [other], "the other road connects them too")
	eq(Influence._alternative_path(cells, 0, 8, 9, 1), [], "a lot that is not a road does not")


# ================================================================ variety bonus

## One home of every kind of citizen along a road, each with its services close by.
func _four_kinds() -> Array:
	return mat([
		"ussmP..",
		"RRRRRRR",
		"ULHSCh.",
		EMPTY, EMPTY, EMPTY,
		CLEAN,
	], {2: 1, 3: 2})


func test_one_kind_of_citizen_earns_no_variety_bonus() -> void:
	var r := Scoring.evaluate(mat(["uRRR...", ".ULF...", EMPTY, EMPTY, EMPTY, EMPTY, CLEAN]), 0)
	eq(r["variety_roles"], ["student"], "only students live here")
	eq(r["variety_bonus"], 0, "one kind is not variety")


func test_two_happy_kinds_earn_the_small_bonus() -> void:
	# a student and a worker, both with their services in reach
	var cells := mat(["uRRRRs.", ".ULCS..", EMPTY, EMPTY, EMPTY, EMPTY, CLEAN], {5: 0})
	var r := Scoring.evaluate(cells, 0)
	eq(r["variety_roles"], ["student", "worker"], "both kinds are happy")
	eq(r["variety_bonus"], Scoring.VARIETY_BONUS[2], "two kinds")


func test_a_kind_without_a_happy_citizen_does_not_count() -> void:
	# the worker lives here too but has no workplace or supermarket: one cheap, unserved home earns nothing
	var cells := mat(["uRRRRs.", ".UL....", EMPTY, EMPTY, EMPTY, EMPTY, CLEAN], {5: 0})
	var r := Scoring.evaluate(cells, 0)
	var worker: Dictionary = _home(r, 5)["members"][0]
	check(worker["happiness"] < Scoring.VARIETY_HAPPY, "the worker is not happy")
	eq(r["variety_roles"], ["student"], "so only the student counts")
	eq(r["variety_bonus"], 0, "no bonus")


func test_all_four_kinds_earn_the_biggest_bonus() -> void:
	var r := Scoring.evaluate(_four_kinds(), 0)
	eq(r["variety_roles"], ["student", "worker", "child", "older"], "every kind is happy")
	eq(r["variety_bonus"], Scoring.VARIETY_BONUS[4], "four kinds")


## Every kind of citizen along one road, each with what they need close by: a student, a worker,
## an older resident, a child, a resident with a disability and an expat.
func _six_kinds() -> Array:
	return mat([
		"ussmPss",
		"RRRRRRR",
		"ULHSChE",
		EMPTY, EMPTY, EMPTY,
		CLEAN,
	], {2: 1, 3: 2, 5: 2, 6: 3})


func test_all_six_kinds_earn_the_biggest_bonus() -> void:
	var r := Scoring.evaluate(_six_kinds(), 0)
	eq(r["variety_roles"], ["student", "worker", "child", "older", "access", "expat"], "every kind is happy")
	eq(r["variety_bonus"], Scoring.VARIETY_BONUS[6], "six kinds")


func test_a_resident_with_a_disability_and_an_expat_are_scored_by_their_own_needs() -> void:
	var r := Scoring.evaluate(_six_kinds(), 0)
	var access: Dictionary = _home(r, 5)["members"][0]
	eq(access["role"], "access", "access role")
	check(_need(access, "health")["met"] and _need(access, "park")["met"], "clinic or hospital and park are met")
	var expat: Dictionary = _home(r, 6)["members"][0]
	eq(expat["role"], "expat", "expat role")
	check(_need(expat, "work")["met"] and _need(expat, "dining")["met"], "workplace and restaurant are met")
	# without the restaurant the expat has a named complaint
	var no_restaurant := _six_kinds()
	no_restaurant[20] = null
	expat = _home(Scoring.evaluate(no_restaurant, 0), 6)["members"][0]
	check(not _need(expat, "dining")["met"], "no restaurant, no dining")
	eq(expat["complaint_detail"] if expat["happiness"] < 0 else "No restaurant within reach", "No restaurant within reach", "the complaint names it")


func test_the_variety_bonus_is_part_of_the_total() -> void:
	var r := Scoring.evaluate(_four_kinds(), 0, [], 3)
	eq(r["total"], r["citizen_sp"] - r["loan_penalty"] - r["unused_penalty"] + r["circumstance_bonus"] + r["variety_bonus"] + 3, "total adds it up")


func test_each_extra_kind_is_worth_more_than_the_one_before() -> void:
	var table: Array = Scoring.VARIETY_BONUS
	eq(table.size(), Roles.IDS.size() + 1, "0 to 6 kinds")
	eq(table[0], 0, "nobody")
	eq(table[1], 0, "one kind is just a city")
	for k in range(2, table.size()):
		check(table[k] - table[k - 1] > table[k - 1] - table[k - 2], "kind %d adds more than kind %d" % [k, k - 1])



func test_a_hospital_and_a_supermarket_give_more_than_their_cheap_twins() -> void:
	var with_clinic := Scoring.evaluate(mat(["sRc....", EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY], {0: 1}), 0)
	var with_hospital := Scoring.evaluate(mat(["sRH....", EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY], {0: 1}), 0)
	check(with_clinic["apartments"].size() > 0 and with_hospital["apartments"].size() > 0, "both mats have a home")
	var c: Dictionary = with_clinic["apartments"][0]["members"][0]
	var h: Dictionary = with_hospital["apartments"][0]["members"][0]
	eq(c["premium"], 0, "a clinic adds no bonus")
	eq(h["premium"], Scoring.PREMIUM_BONUS, "a hospital adds the bonus")
	eq(h["raw"], c["raw"] + Scoring.PREMIUM_BONUS, "one more happiness with the hospital")
