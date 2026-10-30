extends "res://tests/test_base.gd"

const Scoring = preload("res://scripts/core/scoring.gd")


func _apt(result: Dictionary, index: int) -> Dictionary:
	for a in result["apartments"]:
		if a["index"] == index:
			return a
	return {}


func test_empty_mat_has_full_pollution_and_zero_score() -> void:
	var r := Scoring.evaluate(mat(["....", "....", "....", "...."]), 0)
	eq(r["pollution"], 10, "pollution")
	eq(r["pollution_penalty"], 2, "penalty")
	eq(r["total"], 0, "total")
	eq(r["citizens"], 0, "citizens")


func test_park_and_two_trees_bring_pollution_to_five() -> void:
	var r := Scoring.evaluate(mat(["P...", "....", "....", "TT.."]), 0)
	eq(r["pollution"], 5, "pollution")
	eq(r["pollution_penalty"], 0, "penalty")


func test_pollution_never_drops_below_zero() -> void:
	var r := Scoring.evaluate(mat(["P.P.", "....", "P.P.", "...."]), 0)
	eq(r["pollution"], 0, "pollution")


func test_pollution_bands() -> void:
	eq(Scoring.evaluate(mat(["P...", "....", "....", "...."]), 0)["pollution_penalty"], 1, "7 -> -1")
	eq(Scoring.evaluate(mat(["T...", "....", "....", "...."]), 0)["pollution_penalty"], 2, "9 -> -2")
	eq(Scoring.evaluate(mat(["TTTT", "....", "....", "...."]), 0)["pollution_penalty"], 1, "6 -> -1")
	eq(Scoring.evaluate(mat(["TTTT", "T...", "....", "...."]), 0)["pollution_penalty"], 0, "5 -> 0")


func test_lone_apartment_suffers_pollution() -> void:
	var r := Scoring.evaluate(mat(["s...", "....", "....", "...."]), 0)
	var a := _apt(r, 0)
	eq(a["happiness"], -2, "happiness")
	eq(r["citizens"], 1, "citizens")
	eq(r["total"], -2, "total")
	eq(r["complaints"]["Pollution"], 1, "pollution complaint")


func test_amenity_reached_by_road_gives_plus_one() -> void:
	var r := Scoring.evaluate(mat(["sRA.", "....", "....", "P..P"]), 0)
	var a := _apt(r, 0)
	eq(r["pollution"], 4, "pollution")
	eq(a["amenity_bonus"], 1, "amenity bonus")
	eq(a["happiness"], 1, "happiness")
	eq(r["total"], 1, "total")


func test_amenity_next_door_without_road_is_not_connected() -> void:
	var r := Scoring.evaluate(mat(["sA..", "....", "....", "P..P"]), 0)
	var a := _apt(r, 0)
	eq(a["amenity_bonus"], 0, "amenity bonus")
	eq(a["happiness"], 0, "happiness")


func test_long_unshaded_route_costs_one_from_heat() -> void:
	var r := Scoring.evaluate(mat(["sRRR", "...A", "....", "P..P"]), 0)
	var a := _apt(r, 0)
	eq(a["amenity_bonus"], 1, "amenity bonus")
	eq(a["heat"], 1, "heat")
	eq(a["happiness"], 0, "happiness")


func test_shaded_long_route_has_no_heat() -> void:
	var r := Scoring.evaluate(mat(["sRRR", "..TA", "....", "P..P"]), 0)
	var a := _apt(r, 0)
	eq(a["heat"], 0, "heat")
	eq(a["happiness"], 1, "happiness")
	check(r["shaded"][2], "road at (2,0) should be shaded by the trees below it")


func test_single_road_route_is_never_hot() -> void:
	var r := Scoring.evaluate(mat(["sRA.", "....", "....", "P..P"]), 0)
	eq(_apt(r, 0)["heat"], 0, "heat")


func test_two_road_unshaded_route_is_hot() -> void:
	var r := Scoring.evaluate(mat(["sRRA", "....", "....", "P..P"]), 0)
	eq(_apt(r, 0)["heat"], 1, "heat")


func test_two_road_route_with_shade_is_not_hot() -> void:
	var r := Scoring.evaluate(mat(["sRRA", "..T.", "....", "P..P"]), 0)
	eq(_apt(r, 0)["heat"], 0, "heat")


func test_park_area_counts_diagonals_but_trees_do_not() -> void:
	var r := Scoring.evaluate(mat(["T...", ".s..", "..P.", "...P"]), 0)
	var a := _apt(r, 5)
	eq(a["green_bonus"], 1, "green bonus (park only)")
	eq(a["happiness"], 1, "happiness")


func test_orthogonal_trees_give_plus_one() -> void:
	var r := Scoring.evaluate(mat(["Ts..", "....", "..P.", "...P"]), 0)
	var a := _apt(r, 1)
	eq(a["green_bonus"], 1, "green bonus")
	eq(a["happiness"], 1, "happiness")


func test_happiness_is_capped_at_plus_three() -> void:
	var r := Scoring.evaluate(mat(["PT..", "TlT.", "ARA.", "...."]), 0)
	var a := _apt(r, 5)
	eq(a["raw"], 6, "raw happiness")
	eq(a["happiness"], 3, "clamped happiness")
	eq(a["sp"], 9, "sp for 3 citizens")
	eq(r["happy_citizens"], 3, "happy citizens")


func test_each_connected_amenity_stacks() -> void:
	var r := Scoring.evaluate(mat(["ARA.", ".s..", "....", "P..P"]), 0)
	eq(_apt(r, 5)["amenity_bonus"], 2, "two amenities")


func test_each_loan_costs_two_points() -> void:
	var r := Scoring.evaluate(mat(["....", "....", "....", "...."]), 2)
	eq(r["loan_penalty"], 4, "loan penalty")
	eq(r["total"], -4, "total")


func test_complaint_tie_prefers_accessibility() -> void:
	var r := Scoring.evaluate(mat(["s...", "....", "..TT", "..TT"]), 0)
	eq(_apt(r, 0)["happiness"], -1, "happiness")
	eq(_apt(r, 0)["complaint"], "Accessibility", "complaint type")
	eq(r["complaints"]["Accessibility"], 1, "count")


func test_heat_complaint_is_walkability_per_citizen() -> void:
	var r := Scoring.evaluate(mat(["mRRR", "...A", "TT..", "TT.."]), 0)
	eq(_apt(r, 0)["happiness"], -1, "happiness")
	eq(r["complaints"]["Walkability"], 2, "two citizens complain")


func test_happy_citizens_have_no_complaints() -> void:
	var r := Scoring.evaluate(mat(["sRA.", "....", "....", "P..P"]), 0)
	eq(r["unhappy_citizens"], 0, "unhappy")
	eq(_apt(r, 0)["complaint"], "", "no complaint")


func test_unused_amenity_costs_a_point() -> void:
	var r := Scoring.evaluate(mat(["A...", "....", "....", "P..P"]), 0)
	eq(r["unused"].size(), 1, "unused amenities")
	eq(r["unused_penalty"], 1, "unused penalty")
	eq(r["total"], -1, "total")


func test_connected_amenity_is_not_unused() -> void:
	var r := Scoring.evaluate(mat(["sRA.", "....", "....", "P..P"]), 0)
	eq(r["unused"].size(), 0, "unused amenities")
	eq(r["unused_penalty"], 0, "unused penalty")


func test_room_to_improve_names_the_missing_factor() -> void:
	var r := Scoring.evaluate(mat(["sRA.", "....", "....", "P..P"]), 0)
	eq(_apt(r, 0)["happiness"], 1, "happiness")
	eq(_apt(r, 0)["improve"], "Greenery", "missing factor")
	eq(r["room"]["Greenery"], 2, "points to gain")
	eq(r["room_homes"]["Greenery"], 1, "homes helped")


func test_unused_amenity_counts_towards_accessibility_room() -> void:
	var r := Scoring.evaluate(mat(["A...", "....", "....", "P..P"]), 0)
	eq(r["room"]["Accessibility"], 1, "room")


func test_homes_at_the_cap_leave_no_room() -> void:
	var r := Scoring.evaluate(mat(["PT..", "TlT.", "ARA.", "...."]), 0)
	eq(_apt(r, 5)["improve"], "", "nothing to improve")
