extends VBoxContainer
## Left column: the construction site with its tile counter.

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const ShopView = preload("res://scripts/ui/shop_view.gd")

signal slot_pressed(index: int)
signal slot_right_pressed(index: int)
signal slot_hovered(index: int, inside: bool)

const SHOP_CELL := 60.0
const SHOP_GAP := 6.0

var view: ShopView
var _count: Label


func _init(stacks: Array) -> void:
	add_theme_constant_override("separation", 10)
	var head := HBoxContainer.new()
	head.add_child(UiKit.label("Construction site", 26, UiKit.LIMESTONE, "display_bold"))
	head.add_child(UiKit.spacer())
	_count = UiKit.label("", 16, UiKit.MUTED)
	head.add_child(_count)
	add_child(head)
	view = ShopView.new()
	view.build(stacks, SHOP_CELL, SHOP_GAP)
	view.slot_pressed.connect(slot_pressed.emit)
	view.slot_right_pressed.connect(slot_right_pressed.emit)
	view.slot_hovered.connect(slot_hovered.emit)
	add_child(view)


func refresh(stacks: Array, money: int, can_buy: bool, prices: Array = []) -> void:
	view.refresh(stacks, money, can_buy, prices)
	var left := 0
	for s in stacks:
		left += s["count"]
	_count.text = "%d tiles left" % left
