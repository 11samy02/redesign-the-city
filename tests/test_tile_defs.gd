extends "res://tests/test_base.gd"

const Roles = preload("res://scripts/core/roles.gd")


func _counts(bag: Array) -> Dictionary:
	var counts := {}
	for t in bag:
		counts[t["kind"]] = counts.get(t["kind"], 0) + 1
	return counts


func test_full_bag_has_222_tiles_with_documented_counts() -> void:
	var bag := TileDefs.full_bag()
	eq(bag.size(), 222, "bag size")
	eq(TileDefs.BAG_SIZE, 222, "BAG_SIZE")
	var c := _counts(bag)
	var K := TileDefs.Kind
	var want := {
		K.APT_S: 18, K.APT_M: 18, K.APT_L: 14, K.STUDENT_S: 8, K.STUDENT_L: 8,
		K.COMMERCIAL: 10, K.UNIVERSITY: 5, K.LIBRARY: 8, K.BOOKSHOP: 5, K.PRINT_SHOP: 5,
		K.COFFEE_SHOP: 10, K.KIOSK: 8, K.RESTAURANT: 8, K.SUPERMARKET: 8, K.MARKET: 5,
		K.HOSPITAL: 5, K.CLINIC: 6, K.SCHOOL: 8, K.PARKING: 10, K.PARK: 8, K.TREES: 9, K.ROAD: 38,
	}
	for kind in want:
		eq(c.get(kind, 0), want[kind], "count of kind %d" % kind)


func test_household_quantities_sum_to_kind_quantity() -> void:
	for kind in TileDefs.HOUSEHOLDS:
		var sum := 0
		for h in TileDefs.HOUSEHOLDS[kind]:
			sum += h["qty"]
		eq(sum, TileDefs.DEFS[kind]["qty"], "qty of homes %d" % kind)


func test_members_match_citizens() -> void:
	for kind in TileDefs.HOUSEHOLDS:
		var list: Array = TileDefs.HOUSEHOLDS[kind]
		for v in list.size():
			var tile := TileDefs.make(kind, v)
			eq(TileDefs.members(tile).size(), TileDefs.citizens(kind), "members of %s" % TileDefs.household_name(tile))
			for r in TileDefs.members(tile):
				check(r in Roles.IDS, "%s is a real role" % r)


## Every citizen in the shop, by role.
func _citizens_by_role() -> Dictionary:
	var counts := {}
	for t in TileDefs.full_bag():
		for r in TileDefs.members(t):
			counts[r] = counts.get(r, 0) + 1
	return counts


func test_no_citizen_dominates_the_shop_and_none_is_rare() -> void:
	var counts := _citizens_by_role()
	var total := 0
	for r in counts:
		total += counts[r]
	for r in Roles.IDS:
		check(counts.has(r), "%s lives somewhere" % r)
		var share: float = counts.get(r, 0) / float(total)
		check(share <= 0.26, "%s is %.0f%% of the shop, too many" % [r, share * 100.0])
		check(share >= 0.095, "%s is %.0f%% of the shop, too few" % [r, share * 100.0])


func test_students_live_in_residences_and_one_shared_house() -> void:
	for kind in [TileDefs.Kind.APT_S, TileDefs.Kind.APT_M, TileDefs.Kind.APT_L]:
		for h in TileDefs.HOUSEHOLDS[kind]:
			var students: int = h["members"].count("student")
			if h["name"] == "Shared house":
				eq(students, 1, "the shared house has one student")
			else:
				eq(students, 0, "%s has no student" % h["name"])


func test_every_household_is_different_and_has_its_own_picture() -> void:
	var arts := {}
	var seen := {}
	for kind in TileDefs.HOUSEHOLDS:
		for h in TileDefs.HOUSEHOLDS[kind]:
			var who := str(h["members"])
			check(not seen.has(who), "%s repeats the household %s" % [h["name"], who])
			seen[who] = true
			check(not arts.has(h["art"]), "%s shares its picture" % h["name"])
			arts[h["art"]] = true
			check(FileAccess.file_exists("res://assets/tiles/%s.svg" % h["art"]), "picture of %s exists" % h["name"])
	eq(arts.size(), 15, "15 household pictures")


func test_art_path_follows_the_household() -> void:
	eq(TileDefs.art_path(TileDefs.make(TileDefs.Kind.APT_S, 2)), "res://assets/tiles/home_small_access.svg", "small disability home")
	eq(TileDefs.art_path(TileDefs.make(TileDefs.Kind.APT_L, 3)), "res://assets/tiles/home_large_expat_family.svg", "expat family")
	eq(TileDefs.art_path(TileDefs.make(TileDefs.Kind.STUDENT_L)), "res://assets/tiles/student_large.svg", "student residence")


func test_student_residences_are_always_students() -> void:
	for kind in [TileDefs.Kind.STUDENT_S, TileDefs.Kind.STUDENT_L]:
		eq(TileDefs.HOUSEHOLDS[kind].size(), 1, "one household")
		for r in TileDefs.members(TileDefs.make(kind)):
			eq(r, "student", "student residence resident")


func test_a_family_in_a_large_apartment_has_a_child() -> void:
	var family := TileDefs.make(TileDefs.Kind.APT_L, 0)
	eq(TileDefs.household_name(family), "Family", "household name")
	eq(TileDefs.members(family), ["worker", "worker", "child"], "family members")


func test_home_and_service_predicates() -> void:
	check(TileDefs.is_home(TileDefs.Kind.STUDENT_L), "student residence is a home")
	check(not TileDefs.is_home(TileDefs.Kind.LIBRARY), "library is not a home")
	check(TileDefs.is_service(TileDefs.Kind.PARKING), "parking is a service")
	check(TileDefs.is_service(TileDefs.Kind.COMMERCIAL), "commercial is a service")
	check(not TileDefs.is_service(TileDefs.Kind.PARK), "park is not a service")
	check(not TileDefs.is_service(TileDefs.Kind.ROAD), "road is not a service")


func test_every_service_has_art_cost_and_effect() -> void:
	for kind in TileDefs.DEFS:
		var d: Dictionary = TileDefs.DEFS[kind]
		check(d["cost"] >= 1, "cost of %s" % d["name"])
		check(String(d["effect"]).length() > 8, "effect of %s" % d["name"])
		var path := TileDefs.art_path(TileDefs.make(kind), 15)
		check(path.begins_with("res://assets/tiles/") and path.ends_with(".svg"), "art path of %s" % d["name"])


func test_groups_cover_every_kind_exactly_once() -> void:
	var seen := {}
	for g in TileDefs.GROUPS:
		for k in g["kinds"]:
			check(not seen.has(k), "kind %d listed once" % k)
			seen[k] = true
	eq(seen.size(), TileDefs.DEFS.size(), "all kinds are in a group")
	eq(TileDefs.GROUPS[TileDefs.group_of(TileDefs.Kind.LIBRARY)]["name"], "Study", "library group")


func test_street_types_split_38_roads_24_5_5_4() -> void:
	var by_variant := {}
	for t in TileDefs.full_bag():
		if t["kind"] == TileDefs.Kind.ROAD:
			by_variant[t["variant"]] = by_variant.get(t["variant"], 0) + 1
	eq(by_variant, {0: 24, 1: 5, 2: 5, 3: 4}, "street split")
	eq(TileDefs.tile_cost(TileDefs.make(TileDefs.Kind.ROAD, 1)), 3, "shaded street price")
	eq(TileDefs.tile_cost(TileDefs.make(TileDefs.Kind.ROAD, 3)), 2, "bike lane price")


func test_street_suits_use_role_ids() -> void:
	for s in TileDefs.STREETS:
		for r in s["suits"]:
			check(r in Roles.IDS, "%s is a role" % r)


func test_display_names() -> void:
	eq(TileDefs.display_name(TileDefs.make(TileDefs.Kind.COFFEE_SHOP)), "Coffee shop", "coffee")
	eq(TileDefs.display_name(TileDefs.make(TileDefs.Kind.PARKING)), "Parking place", "parking")
	eq(TileDefs.display_name(TileDefs.make(TileDefs.Kind.APT_M)), "Medium apartment", "apartment")
	var free := TileDefs.make(TileDefs.Kind.ROAD)
	free["free"] = true
	eq(TileDefs.display_name(free), "Free road", "free road")


func test_art_exists_for_every_tile_and_role() -> void:
	for kind in TileDefs.DEFS:
		var path := TileDefs.art_path(TileDefs.make(kind), 15)
		check(FileAccess.file_exists(path), "art file %s" % path)
	for s in TileDefs.STREETS:
		for mask in 16:
			var path := "res://assets/tiles/%s_%d.svg" % [s["art"], mask]
			check(FileAccess.file_exists(path), "street art %s" % path)
	for r in Roles.IDS:
		check(FileAccess.file_exists(Roles.DEFS[r]["icon"]), "role icon %s" % r)
