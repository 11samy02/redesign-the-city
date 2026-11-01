extends "res://tests/test_base.gd"

const Roles = preload("res://scripts/core/roles.gd")


func test_every_role_has_two_needs_and_a_color() -> void:
	eq(Roles.IDS, ["student", "worker", "child", "older", "access", "expat"], "role ids")
	for id in Roles.IDS:
		var d: Dictionary = Roles.DEFS[id]
		eq(d["needs"].size(), 2, "%s needs" % id)
		check(Color.html(d["color"]) != Color.BLACK, "%s has a colour" % id)
		for n in d["needs"]:
			check(Roles.NEEDS.has(n), "%s need %s is defined" % [id, n])


func test_groceries_and_health_accept_two_kinds_each() -> void:
	var g: Array = Roles.need_kinds("groceries")
	g.sort()
	var want: Array = [TileDefs.Kind.SUPERMARKET, TileDefs.Kind.MARKET]
	want.sort()
	eq(g, want, "groceries kinds")
	var h: Array = Roles.need_kinds("health")
	h.sort()
	want = [TileDefs.Kind.CLINIC, TileDefs.Kind.HOSPITAL]
	want.sort()
	eq(h, want, "health kinds")


func test_older_feels_heat_double() -> void:
	eq(Roles.DEFS["older"]["heat_factor"], 2, "older heat")
	eq(Roles.DEFS["access"]["heat_factor"], 2, "a resident with a disability feels long walks like older residents")
	for id in ["student", "worker", "child", "expat"]:
		eq(Roles.DEFS[id]["heat_factor"], 1, "%s heat" % id)


func test_child_dislikes_parking_and_park_is_an_area_need() -> void:
	eq(Roles.DEFS["child"]["dislike_kind"], TileDefs.Kind.PARKING, "child dislike")
	check(Roles.NEEDS["park"]["area"], "park is an area need")
	check(not Roles.NEEDS["school"]["area"], "school is a route need")
	eq(Roles.DEFS["student"]["dislike_kind"], -1, "students dislike nothing")
	eq(Roles.DEFS["older"]["dislike_kind"], TileDefs.Kind.RESTAURANT, "older dislike")


func test_parking_is_liked_by_everyone_but_children() -> void:
	for id in ["student", "worker", "older", "access", "expat"]:
		check(TileDefs.Kind.PARKING in Roles.DEFS[id]["like_kinds"], "%s likes parking" % id)
	check(not (TileDefs.Kind.PARKING in Roles.DEFS["child"]["like_kinds"]), "child does not like parking")


func test_missing_text_reads_naturally() -> void:
	eq(Roles.missing_text("school"), "No school within reach", "school")
	eq(Roles.missing_text("library"), "No library within reach", "library")
	eq(Roles.missing_text("park"), "No park nearby", "park")


func test_the_new_citizens_need_different_services() -> void:
	eq(Roles.DEFS["access"]["needs"], ["health", "park"], "resident with a disability needs")
	eq(Roles.DEFS["expat"]["needs"], ["work", "dining"], "expat needs")
	eq(Roles.need_kinds("dining"), [TileDefs.Kind.RESTAURANT], "dining is met by a restaurant")
	check(not Roles.NEEDS["dining"]["area"], "dining is a route need")
	eq(Roles.missing_text("dining"), "No restaurant within reach", "dining missing text")


func test_no_two_citizens_share_both_needs() -> void:
	for a in Roles.IDS:
		for b in Roles.IDS:
			if a >= b:
				continue
			var shared := 0
			for n in Roles.DEFS[a]["needs"]:
				if n in Roles.DEFS[b]["needs"]:
					shared += 1
			check(shared < 2, "%s and %s need different things" % [a, b])


func test_a_resident_with_a_disability_likes_gentle_streets() -> void:
	var streets: Array = Roles.DEFS["access"]["like_streets"]
	check(TileDefs.STREET_PEDESTRIAN in streets and TileDefs.STREET_SHADED in streets, "pedestrian and shaded streets")
	check(TileDefs.Kind.KIOSK in Roles.DEFS["access"]["like_kinds"], "likes a kiosk")
