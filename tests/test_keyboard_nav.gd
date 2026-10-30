extends "res://tests/test_base.gd"

const KeyboardNav = preload("res://scripts/game/keyboard_nav.gd")

const LEFT := Vector2i(-1, 0)
const RIGHT := Vector2i(1, 0)
const UP := Vector2i(0, -1)
const DOWN := Vector2i(0, 1)


func test_shop_cursor_stays_inside_the_grid() -> void:
	var nav := KeyboardNav.new()
	nav.step(LEFT)
	nav.step(UP)
	eq(nav.shop, 0, "top-left corner holds")
	nav.step(DOWN)
	nav.step(RIGHT)
	eq(nav.shop, 7, "one down, one right")
	for k in 10:
		nav.step(DOWN)
	eq(nav.shop, 31, "bottom row holds")


func test_right_edge_of_the_shop_enters_the_mat_at_the_same_height() -> void:
	var nav := KeyboardNav.new()
	nav.shop = 5
	nav.step(RIGHT)
	eq(nav.area, "mat", "area")
	eq(nav.mat, 0, "top row of the shop leads to the top row of the mat")
	nav.area = "shop"
	nav.shop = 23
	nav.step(RIGHT)
	eq(nav.mat, 8, "shop row 3 (of 0-5) leads to mat row 2 (of 0-3)")


func test_left_edge_of_the_mat_returns_to_the_shop() -> void:
	var nav := KeyboardNav.new()
	nav.area = "mat"
	nav.mat = 8
	nav.step(LEFT)
	eq(nav.area, "shop", "area")
	eq(nav.shop, 23, "mat row 2 (of 0-3) leads to shop row 3 (of 0-5), last column")


func test_mat_cursor_moves_and_clamps() -> void:
	var nav := KeyboardNav.new()
	nav.area = "mat"
	nav.mat = 5
	nav.step(RIGHT)
	nav.step(DOWN)
	eq(nav.mat, 10, "moves right then down")
	for k in 6:
		nav.step(RIGHT)
		nav.step(DOWN)
	eq(nav.mat, 15, "bottom-right corner holds")


func test_toggle_area_switches_between_shop_and_mat() -> void:
	var nav := KeyboardNav.new()
	nav.toggle_area()
	eq(nav.area, "mat", "to mat")
	nav.toggle_area()
	eq(nav.area, "shop", "back to shop")
