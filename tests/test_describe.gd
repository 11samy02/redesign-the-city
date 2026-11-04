extends "res://tests/test_base.gd"
## The plain-language tooltip lines: who lives in a home, what they need, and what is missing.

const Describe = preload("res://scripts/ui/describe.gd")
const Scoring = preload("res://scripts/core/scoring.gd")

const EMPTY := "......."
const CLEAN := "PPP...."


func _text(lines: Array) -> String:
	return "\n".join(lines)


func test_household_lines_name_every_role_and_need() -> void:
	var tile := TileDefs.make(TileDefs.Kind.APT_M, 2)
	var text := _text(Describe.household_lines(tile))
	check(text.contains("Worker"), "the parent")
	check(text.contains("Child"), "the child")
	for need in ["Commercial area", "Supermarket or market", "School", "Park"]:
		check(text.contains(need), "needs a %s" % need)


func test_household_lines_list_each_role_once_with_a_count() -> void:
	var text := _text(Describe.household_lines(TileDefs.make(TileDefs.Kind.APT_L, 0)))
	check(text.contains("2 Workers"), "two workers in a family")
	check(text.contains("Child"), "one child")
	var first := text.find("needs a ")
	check(first >= 0, "needs are listed")
	eq(text.count("Commercial area"), 1, "the workers' needs are not repeated")


func test_student_residences_say_they_are_for_students() -> void:
	var text := _text(Describe.household_lines(TileDefs.make(TileDefs.Kind.STUDENT_L)))
	check(text.contains("Students"), "two students")
	check(text.contains("University"), "needs a university")
	check(text.contains("Library"), "needs a library")


func test_shop_lines_use_the_turn_size() -> void:
	var tile := TileDefs.make(TileDefs.Kind.TREES)
	check(_text(Describe.shop_lines(tile, 50, 0)).contains("4 tiles"), "all four are bought")
	check(_text(Describe.shop_lines(tile, 50, 2)).contains("Click"), "can pick it up")
	check(_text(Describe.shop_lines(tile, 0, 2)).contains("1 more gold"), "short of gold")


func test_cell_lines_mark_missing_needs() -> void:
	var cells := mat(["uRR....", ".U.....", EMPTY, EMPTY, EMPTY, EMPTY, CLEAN])
	var r := Scoring.evaluate(cells, 0)
	var text := _text(Describe.cell_lines(cells, r, 0))
	check(not text.contains("University"), "a need that is met is not listed")
	check(text.contains("Missing") and text.contains("Library"), "library is missing")
	check(text.contains("Student"), "role is named")


func test_cell_lines_name_the_complaint_of_an_unhappy_citizen() -> void:
	var cells := mat(["uRR....", ".U.....", EMPTY, EMPTY, EMPTY, EMPTY, EMPTY])
	var r := Scoring.evaluate(cells, 0)
	var text := _text(Describe.cell_lines(cells, r, 0))
	check(text.contains("Missing: Library"), "the tooltip names the missing library")


func test_citizens_who_feel_the_same_share_a_block() -> void:
	var cells := mat([EMPTY, "..lR...", EMPTY, EMPTY, EMPTY, EMPTY, CLEAN])
	var r := Scoring.evaluate(cells, 0)
	var text := _text(Describe.cell_lines(cells, r, at(9)))
	check(text.contains("2 Workers"), "the two workers who feel the same share a block")
	eq(text.count("Child"), 1, "one child")


func test_service_lines_say_who_needs_them() -> void:
	var cells := mat(["uRL....", EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, CLEAN])
	var r := Scoring.evaluate(cells, 0)
	var text := _text(Describe.cell_lines(cells, r, at(2)))
	check(text.contains("needed by 1 citizen") or text.contains("Needed by 1 citizen"), "the student needs the library")


func test_a_service_nobody_reaches_warns_about_the_penalty() -> void:
	var cells := mat(["L......", EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY])
	var r := Scoring.evaluate(cells, 0)
	var text := _text(Describe.cell_lines(cells, r, at(0)))
	check(text.contains("No homes reach it"), "unreached")
	check(text.contains("1 point"), "penalty is named")
