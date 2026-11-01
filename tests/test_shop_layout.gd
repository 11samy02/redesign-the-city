extends "res://tests/test_base.gd"
## The construction site's layout: every stack fits, nothing overlaps, badges follow the counts.

const GameState = preload("res://scripts/core/game_state.gd")
const ShopView = preload("res://scripts/ui/shop_view.gd")

## The space the shop column may take at the 1600x900 design size.
const MAX_WIDTH := 560.0
const MAX_HEIGHT := 560.0


func _view(players: int) -> Array:
	var gs := GameState.new()
	gs.setup(["Ana", "Ben", "Cleo", "Dimitri"].slice(0, players), [0, 1, 2, 3].slice(0, players), 5)
	var v := ShopView.new()
	v.build(gs.shop)
	v.refresh(gs.shop, gs.current_player().money, true)
	return [v, gs]


func test_every_stack_is_inside_the_panel_and_the_panel_fits_the_column() -> void:
	for n in [2, 3, 4]:
		var pair := _view(n)
		var v: ShopView = pair[0]
		var bounds := Rect2(Vector2.ZERO, v.custom_minimum_size)
		check(v.custom_minimum_size.x <= MAX_WIDTH, "%d players: width %d fits" % [n, v.custom_minimum_size.x])
		check(v.custom_minimum_size.y <= MAX_HEIGHT, "%d players: height %d fits" % [n, v.custom_minimum_size.y])
		eq(v.views.size(), pair[1].shop.size(), "%d players: one view per stack" % n)
		for t in v.views:
			check(bounds.encloses(Rect2(t.position, t.size)), "%d players: stack %d is inside" % [n, t.index])
		v.free()


func test_no_two_stacks_overlap() -> void:
	var v: ShopView = _view(4)[0]
	for i in v.views.size():
		for j in range(i + 1, v.views.size()):
			var a: Rect2 = Rect2(v.views[i].position, v.views[i].size)
			var b: Rect2 = Rect2(v.views[j].position, v.views[j].size)
			check(not a.intersects(b), "stacks %d and %d overlap" % [i, j])
	v.free()


func test_the_shop_has_five_rows_and_no_section_starts_mid_row_by_accident() -> void:
	var v: ShopView = _view(4)[0]
	eq(v.rows.size(), 5, "35 stacks in five rows")
	# the first row is all homes: the home section is never left with a single tile on a row of its own
	for s in v.rows[1]:
		eq(TileDefs.group_of(v.views[s].tile["kind"]), 0, "second row is still homes")
	v.free()


func test_tiles_are_big_enough_to_read() -> void:
	var v: ShopView = _view(4)[0]
	check(v.cell >= 56.0, "stacks are at least 56 px, got %d" % v.cell)
	v.free()


func test_rows_list_every_stack_once_in_shop_order() -> void:
	var pair := _view(4)
	var v: ShopView = pair[0]
	var flat := []
	for row in v.rows:
		flat.append_array(row)
	eq(flat.size(), pair[1].shop.size(), "all stacks are in a row")
	var seen := {}
	for s in flat:
		check(not seen.has(s), "stack %d once" % s)
		seen[s] = true
	var sorted := flat.duplicate()
	sorted.sort()
	eq(flat, sorted, "rows keep the shop order")
	v.free()


func test_stack_badge_follows_the_count_as_tiles_are_bought() -> void:
	var pair := _view(4)
	var v: ShopView = pair[0]
	var gs: GameState = pair[1]
	for i in gs.shop.size():
		eq(v.views[i].stack_count, gs.shop[i]["count"], "count of stack %d" % i)
	check(gs.buy_and_place(0, 0), "buy from the first stack")
	v.refresh(gs.shop, gs.current_player().money, true)
	eq(v.views[0].stack_count, gs.shop[0]["count"], "badge drops after a purchase")
	eq(v.views[0].stack_count, gs.shop[0]["start"] - 1, "one fewer than at the start")
	v.free()


func test_sold_out_stack_is_faded_and_not_interactive() -> void:
	var pair := _view(4)
	var v: ShopView = pair[0]
	var gs: GameState = pair[1]
	gs.shop[0]["count"] = 0
	v.refresh(gs.shop, 110, true)
	check(v.views[0].sold_out, "sold out")
	check(not v.views[0].interactive, "not clickable")
	check(not v.views[1].sold_out, "others are fine")
	check(v.views[1].interactive, "others stay clickable")
	v.free()


func test_unaffordable_stack_is_marked() -> void:
	var pair := _view(4)
	var v: ShopView = pair[0]
	var gs: GameState = pair[1]
	v.refresh(gs.shop, 2, true)
	for i in gs.shop.size():
		eq(v.views[i].affordable, TileDefs.tile_cost(gs.shop[i]["tile"]) <= 2, "affordable flag of stack %d" % i)
	v.free()


func test_prices_follow_the_card_discounts() -> void:
	var pair := _view(4)
	var v: ShopView = pair[0]
	var gs: GameState = pair[1]
	var prices := []
	for s in gs.shop:
		prices.append(0 if s["tile"]["kind"] == TileDefs.Kind.TREES else TileDefs.tile_cost(s["tile"]))
	v.refresh(gs.shop, 0, true, prices)
	for i in gs.shop.size():
		eq(v.views[i].price, prices[i], "price of stack %d" % i)
		eq(v.views[i].affordable, prices[i] == 0, "with no gold only free stacks are affordable (stack %d)" % i)
	v.free()
