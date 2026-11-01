extends "res://tests/test_base.gd"

const KeyboardNav = preload("res://scripts/game/keyboard_nav.gd")

const LEFT := Vector2i(-1, 0)
const RIGHT := Vector2i(1, 0)
const UP := Vector2i(0, -1)
const DOWN := Vector2i(0, 1)

## Four visual rows of stacks, as the shop lays them out.
const ROWS := [[0, 1, 2, 3, 4, 5, 6], [7, 8, 9, 10, 11, 12, 13], [14, 15, 16], [17, 18]]


func _nav() -> KeyboardNav:
	var nav := KeyboardNav.new()
	nav.shop_rows = ROWS
	return nav


func test_shop_cursor_follows_the_visual_rows_and_stays_inside() -> void:
	var nav := _nav()
	nav.step(LEFT)
	nav.step(UP)
	eq(nav.shop, 0, "top-left corner holds")
	nav.step(DOWN)
	nav.step(RIGHT)
	eq(nav.shop, 8, "one down, one right")
	nav.step(DOWN)
	eq(nav.shop, 15, "second column of the short row")
	nav.step(DOWN)
	eq(nav.shop, 18, "second column of the last row")
	nav.step(DOWN)
	eq(nav.shop, 18, "bottom holds")
	nav.step(UP)
	eq(nav.shop, 15, "back up")


func test_moving_down_into_a_shorter_row_clamps_the_column() -> void:
	var nav := _nav()
	nav.shop = 13
	nav.step(DOWN)
	eq(nav.shop, 16, "row 1 column 6 lands on the last stack of row 2")


func test_moving_right_inside_a_row_stays_in_the_shop() -> void:
	var nav := _nav()
	nav.shop = 3
	nav.step(RIGHT)
	eq(nav.shop, 4, "next stack")
	eq(nav.area, "shop", "still in the shop")


func test_right_edge_of_a_shop_row_enters_the_mat_at_the_matching_height() -> void:
	var nav := _nav()
	nav.shop = 6
	nav.step(RIGHT)
	eq(nav.area, "mat", "area")
	eq(nav.mat, 0, "top row of the shop leads to the top row of the mat")
	nav.area = "shop"
	nav.shop = 13
	nav.step(RIGHT)
	eq(nav.mat, 14, "shop row 1 of 0-3 leads to mat row 2 of 0-6")
	nav.area = "shop"
	nav.shop = 18
	nav.step(RIGHT)
	eq(nav.mat, 42, "the last shop row leads to the last mat row")


func test_left_edge_of_the_mat_returns_to_the_shop() -> void:
	var nav := _nav()
	nav.area = "mat"
	nav.mat = 14
	nav.step(LEFT)
	eq(nav.area, "shop", "area")
	eq(nav.shop, 13, "mat row 2 of 0-6 leads to the end of shop row 1")
	nav.area = "mat"
	nav.mat = 42
	nav.step(LEFT)
	eq(nav.shop, 18, "last mat row leads to the last shop row")


func test_mat_cursor_moves_and_clamps_on_7x7() -> void:
	var nav := _nav()
	nav.area = "mat"
	nav.mat = 8
	nav.step(RIGHT)
	nav.step(DOWN)
	eq(nav.mat, 16, "moves right then down")
	for k in 10:
		nav.step(RIGHT)
		nav.step(DOWN)
	eq(nav.mat, 48, "bottom-right corner holds")


func test_an_empty_shop_layout_does_not_crash() -> void:
	var nav := KeyboardNav.new()
	nav.step(DOWN)
	nav.step(RIGHT)
	eq(nav.shop, 0, "nothing to move over")


func test_toggle_area_switches_between_shop_and_mat() -> void:
	var nav := _nav()
	nav.toggle_area()
	eq(nav.area, "mat", "to mat")
	nav.toggle_area()
	eq(nav.area, "shop", "back to shop")
