extends VBoxContainer
## Left column: the construction site grid with its tile counter and colour legend.

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const ShopView = preload("res://scripts/ui/shop_view.gd")

signal slot_pressed(index: int)
signal slot_right_pressed(index: int)
signal slot_hovered(index: int, inside: bool)

const SHOP_CELL := 76.0
const SHOP_GAP := 7.0
const LEGEND := [["Apartments", "Building"], ["Amenities", "Amenity"], ["Parks and trees", "Green space"], ["Roads", "Road"]]

var view: ShopView
var _count: Label


func _init() -> void:
	add_theme_constant_override("separation", 10)
	var head := HBoxContainer.new()
	head.add_child(UiKit.label("Construction site", 26, UiKit.LIMESTONE, "display_bold"))
	head.add_child(UiKit.spacer())
	_count = UiKit.label("", 16, UiKit.MUTED)
	head.add_child(_count)
	add_child(head)
	view = ShopView.new()
	view.setup(SHOP_CELL, SHOP_GAP)
	view.slot_pressed.connect(slot_pressed.emit)
	view.slot_right_pressed.connect(slot_right_pressed.emit)
	view.slot_hovered.connect(slot_hovered.emit)
	add_child(view)
	add_child(_build_legend())


func refresh(shop: Array, removed: Array, money: int, can_buy: bool) -> void:
	view.refresh(shop, removed, money, can_buy)
	var left := 0
	for t in shop:
		if t != null:
			left += 1
	_count.text = "%d tiles left" % left


func _build_legend() -> Control:
	var legend := HFlowContainer.new()
	legend.add_theme_constant_override("h_separation", 8)
	legend.add_theme_constant_override("v_separation", 6)
	for c in LEGEND:
		legend.add_child(UiKit.chip(c[0], UiKit.CATEGORY_COLORS[c[1]], UiKit.LIMESTONE, 13))
	legend.custom_minimum_size.x = view.custom_minimum_size.x
	return legend
