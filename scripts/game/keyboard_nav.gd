extends RefCounted
## Keyboard cursor over the construction site's stacks and the player mat (7x7).
## Pure navigation state: the screen draws the focus and acts on Enter.

const Scoring = preload("res://scripts/core/scoring.gd")

const MAT_N := Scoring.SIZE

## False until a key is used, and again as soon as the mouse moves.
var on := false
## "shop" or "mat".
var area := "shop"
## Stack index under the cursor.
var shop := 0
var mat := 0
## The shop's visual rows: arrays of stack indexes, top to bottom (see ShopView.rows).
var shop_rows: Array = []


## Moves the cursor one step. Walking off the right edge of a shop row enters the mat, and back.
func step(d: Vector2i) -> void:
	if area == "shop":
		_step_shop(d)
	else:
		_step_mat(d)


func toggle_area() -> void:
	area = "mat" if area == "shop" else "shop"


## Row and column of stack `s` in shop_rows, or (0, 0) when it is not laid out.
func _shop_pos(s: int) -> Vector2i:
	for r in shop_rows.size():
		var c: int = shop_rows[r].find(s)
		if c >= 0:
			return Vector2i(c, r)
	return Vector2i.ZERO


func _step_shop(d: Vector2i) -> void:
	if shop_rows.is_empty():
		return
	var pos := _shop_pos(shop)
	var row: Array = shop_rows[pos.y]
	if d.x > 0 and pos.x == row.size() - 1:
		area = "mat"
		# same relative height on the mat
		mat = roundi(float(pos.y) / maxf(1.0, shop_rows.size() - 1.0) * (MAT_N - 1)) * MAT_N
		return
	var new_row := clampi(pos.y + d.y, 0, shop_rows.size() - 1)
	var target: Array = shop_rows[new_row]
	var new_col := clampi(pos.x + d.x, 0, target.size() - 1)
	shop = target[new_col]


func _step_mat(d: Vector2i) -> void:
	var col := mat % MAT_N
	var row := mat / MAT_N
	if d.x < 0 and col == 0:
		if shop_rows.is_empty():
			return
		area = "shop"
		var r := roundi(float(row) / (MAT_N - 1.0) * (shop_rows.size() - 1))
		shop = shop_rows[r][-1]
		return
	mat = clampi(row + d.y, 0, MAT_N - 1) * MAT_N + clampi(col + d.x, 0, MAT_N - 1)
