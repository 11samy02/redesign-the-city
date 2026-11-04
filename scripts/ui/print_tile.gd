extends RefCounted
## A tile as it is printed for the real board game: the picture with what a player needs on it,
## laid out like the tiles in the game, with no boxes.
##
## Every tile is drawn on a 256 x 256 canvas. A 2:2 tile is printed 4 x 4 cm, a 1:1 tile half that
## (2 x 2 cm), so a small tile gets bigger badges to stay readable.
##
##   homes            one round role icon per citizen who lives there, top left
##   top, left half   services, parks and special streets: what is good. A role icon per citizen they matter to,
##                    overlapping, with the points under it: blue +2 a need met (+3 at a hospital or supermarket),
##                    green +1 a like or green space near the home
##   top, right half  what is bad: red -1 for a citizen who dislikes it (only right next to the home). Parks,
##                    trees and shaded streets have no dislikes, so their cloud sits here: how far they pull
##                    the pollution bar down
##   bottom right   what it costs (coin and number)

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const TileDefs = preload("res://scripts/core/tile_defs.gd")
const Roles = preload("res://scripts/core/roles.gd")
const Scoring = preload("res://scripts/core/scoring.gd")
const PrintBadge = preload("res://scripts/ui/print_badge.gd")

const SIZE := 256.0
const MARGIN := 14.0
const COIN := 50.0
## Good effects fill the left half of the tile and bad ones the right half, with this much room between them.
const SIDE_GAP := 18.0
## How far the next icon of a group sits, as a share of an icon's width (less than 1 means they overlap).
const OVERLAP := 0.6
## Room between two groups, in icon widths.
const GROUP_GAP := 0.16

## Pollution a green tile takes off the pollution bar.
const PARK_AIR := 3
const TREE_AIR := 1

## A 256 x 256 control. `road_mask` picks the piece of a road (see TileDefs.art_path).
static func build(tile: Dictionary, road_mask := 15) -> Control:
	var root := Control.new()
	root.custom_minimum_size = Vector2(SIZE, SIZE)
	root.size = Vector2(SIZE, SIZE)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art := TextureRect.new()
	art.texture = UiKit.tex(TileDefs.art_path(tile, road_mask))
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.size = Vector2(SIZE, SIZE)
	root.add_child(art)
	var small := TileDefs.footprint(tile) == 1
	if TileDefs.is_home(tile["kind"]):
		root.add_child(_residents(TileDefs.members(tile), small))
	else:
		var list := effects(tile)
		if not list.is_empty():
			root.add_child(_badges(list, small))
	var air := air_effect(tile)
	if air != 0:
		root.add_child(_air_badge(air, small))
	root.add_child(_price(TileDefs.tile_cost(tile), small))
	return root


# ================================================================ what a tile does for citizens

## Pollution a tile takes off the pollution bar (0 for most tiles).
static func air_effect(tile: Dictionary) -> int:
	if tile["kind"] == TileDefs.Kind.PARK:
		return PARK_AIR
	if TileDefs.is_tree_like(tile):
		return TREE_AIR
	return 0


## Which citizens a tile matters to and by how much: [{"role", "value", "type"}] in citizen order, needs first,
## then likes, then dislikes. type is "need", "like", "dislike" or "green" (role "home": every home near it).
static func effects(tile: Dictionary) -> Array:
	var kind: int = tile["kind"]
	var out: Array = []
	var needs: Array = []
	var likes: Array = []
	var dislikes: Array = []
	for role in Roles.IDS:
		var def: Dictionary = Roles.DEFS[role]
		for need_id in def["needs"]:
			if kind in Roles.NEEDS[need_id]["kinds"]:
				var value := 2
				if not Roles.NEEDS[need_id]["area"] and kind in Scoring.PREMIUM_KINDS:
					value += Scoring.PREMIUM_BONUS
				needs.append({"role": role, "value": value, "type": "need"})
		if kind in def["like_kinds"]:
			likes.append({"role": role, "value": 1, "type": "like"})
		if kind == TileDefs.Kind.ROAD and TileDefs.is_special_street(tile) and tile.get("variant", 0) in def["like_streets"]:
			likes.append({"role": role, "value": 1, "type": "like"})
		if def["dislike_kind"] == kind:
			dislikes.append({"role": role, "value": -1, "type": "dislike"})
	out.append_array(needs)
	out.append_array(likes)
	out.append_array(dislikes)
	if kind == TileDefs.Kind.PARK or TileDefs.is_tree_like(tile):
		out.append({"role": "home", "value": 1, "type": "green"})
	return out


static func _resident_badges(members: Array) -> Array:
	var out: Array = []
	for role in members:
		out.append({"role": role, "value": 0, "type": "resident"})
	return out


# ================================================================ drawing

## The citizens who live in a home: one round icon each in a row, as big as fits.
static func _residents(members: Array, small: bool) -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var n := members.size()
	var d := minf(70.0 if small else 58.0, (SIZE - 2.0 * MARGIN) / (n * 0.94 + 0.06))
	for k in n:
		var b := _badge({"role": members[k], "value": 0, "type": "resident"}, d)
		b.position = Vector2(MARGIN + k * d * 0.94, MARGIN)
		holder.add_child(b)
	return holder


## The citizens a tile matters to, as round icons with their points under them. Good effects (needs, likes,
## green) sit on the left half of the tile, bad ones (dislikes) on the right half, with a gap between. Citizens
## who get the same points overlap in one group with a single pill; a big group wraps into two staggered rows.
static func _badges(list: Array, small: bool) -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var good: Array = []
	var bad: Array = []
	for item in list:
		(bad if item["type"] == "dislike" else good).append(item)
	var good_groups := _group(good)
	var bad_groups := _group(bad)
	var half := (SIZE - 2.0 * MARGIN - SIDE_GAP) / 2.0
	# both sides use the same icon size: the biggest that lets the fuller side fit in half the tile
	var d := minf(64.0 if small else 54.0, half / maxf(_width_in_d(good_groups), _width_in_d(bad_groups)))
	_place_groups(holder, good_groups, d, MARGIN)
	_place_groups(holder, bad_groups, d, SIZE - MARGIN - _width_in_d(bad_groups) * d)
	return holder


## Neighbours with the same kind of points share a group.
static func _group(items: Array) -> Array:
	var groups: Array = []
	for item in items:
		var key := "%s%d" % [item["type"], item["value"]]
		if not groups.is_empty() and groups[-1]["key"] == key:
			groups[-1]["items"].append(item)
		else:
			groups.append({"key": key, "items": [item]})
	return groups


## Icons in a row of a group: all of them up to 3, four make 2 + 2, five or six make 3 + the rest.
static func _per_row(n: int) -> int:
	if n <= 3:
		return n
	return 2 if n == 4 else 3


## How wide a group is, in icon widths: each icon after the first in a row adds OVERLAP, and a second row is
## shifted half a step so the icons nest.
static func _group_width(n: int) -> float:
	var cols := _per_row(n)
	return 1.0 + (cols - 1) * OVERLAP + (OVERLAP / 2.0 if n > cols else 0.0)


## How wide a row of groups is, in icon widths.
static func _width_in_d(groups: Array) -> float:
	if groups.is_empty():
		return 0.0
	var w := GROUP_GAP * (groups.size() - 1)
	for g in groups:
		w += _group_width(g["items"].size())
	return w


static func _place_groups(holder: Control, groups: Array, d: float, start_x: float) -> void:
	var x := start_x
	for g in groups:
		var n: int = g["items"].size()
		var cols := _per_row(n)
		var rows := ceili(n / float(cols))
		var step := d * OVERLAP
		var width := _group_width(n) * d
		for k in n:
			var item: Dictionary = g["items"][k]
			var row := k / cols
			var b := _badge({"role": item["role"], "value": 0, "type": "resident"}, d)
			b.position = Vector2(x + (k % cols) * step + (step / 2.0 if row % 2 == 1 else 0.0), MARGIN + row * d * 0.7)
			holder.add_child(b)
		var first: Dictionary = g["items"][0]
		var pill := PrintBadge.new()
		pill.item = {"role": "", "value": first["value"], "type": first["type"], "only_pill": true}
		pill.d = d
		var pw := maxf(d * 0.92, d * 0.5 + 6.0)
		pill.size = Vector2(pw, d * 0.46)
		pill.position = Vector2(x + width / 2.0 - pw / 2.0, MARGIN + (rows - 1) * d * 0.7 + d * 0.8)
		pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(pill)
		x += width + d * GROUP_GAP


## One round icon of `d` pixels with a pill with its points hanging off the bottom.
static func _badge(item: Dictionary, d: float) -> Control:
	var c := PrintBadge.new()
	c.item = item
	c.d = d
	c.size = Vector2(d, d * 1.3)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## The pollution a green tile takes off the pollution bar: a smog cloud with a green pill, top right.
static func _air_badge(amount: int, small: bool) -> Control:
	var d := 56.0 if small else 50.0
	var b := _badge({"role": "smog", "value": -amount, "type": "air"}, d)
	b.position = Vector2(SIZE - MARGIN - d, MARGIN)
	return b


## Coin and number in the bottom-right corner; the outline keeps the number readable on any picture.
static func _price(cost: int, small: bool) -> Control:
	var f := UiKit.font("display_bold")
	var coin := COIN * (1.1 if small else 1.0)
	var fs := int(46 * (1.1 if small else 1.0))
	var text_w := f.get_string_size(str(cost), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size = Vector2(coin + text_w + 4, coin)
	holder.position = Vector2(SIZE - MARGIN - holder.size.x, SIZE - MARGIN - coin)
	var c := UiKit.icon("res://assets/ui/coin.svg", coin)
	c.size = Vector2(coin, coin)
	holder.add_child(c)
	var l := UiKit.outline(UiKit.label(str(cost), fs, UiKit.GOLD, "display_bold"), 10)
	l.position = Vector2(coin + 4, 0)
	l.size = Vector2(text_w + 4, coin)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	holder.add_child(l)
	return holder


## File name for a tile's print image, for example "home_medium_working_couple".
static func file_name(tile: Dictionary, road_mask := 15) -> String:
	# every household has its own picture, named after it, so the picture's name is the file name
	return TileDefs.art_path(tile, road_mask).get_file().get_basename()
