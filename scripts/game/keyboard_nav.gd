extends RefCounted
## Keyboard cursor over the shop grid (6x6) and the player mat (4x4).
## Pure navigation state: the screen draws the focus and acts on Enter.

const SHOP_N := 6
const MAT_N := 4

## False until a key is used, and again as soon as the mouse moves.
var on := false
## "shop" or "mat".
var area := "shop"
var shop := 0
var mat := 0


## Moves the cursor one step. Walking off the right edge of the shop enters the mat, and back.
func step(d: Vector2i) -> void:
	if area == "shop":
		_step_shop(d)
	else:
		_step_mat(d)


func toggle_area() -> void:
	area = "mat" if area == "shop" else "shop"


func _step_shop(d: Vector2i) -> void:
	var col := shop % SHOP_N
	var row := shop / SHOP_N
	if d.x > 0 and col == SHOP_N - 1:
		area = "mat"
		# same relative height on the mat
		mat = (row * MAT_N / SHOP_N) * MAT_N
		return
	shop = clampi(row + d.y, 0, SHOP_N - 1) * SHOP_N + clampi(col + d.x, 0, SHOP_N - 1)


func _step_mat(d: Vector2i) -> void:
	var col := mat % MAT_N
	var row := mat / MAT_N
	if d.x < 0 and col == 0:
		area = "shop"
		shop = (row * SHOP_N / MAT_N) * SHOP_N + SHOP_N - 1
		return
	mat = clampi(row + d.y, 0, MAT_N - 1) * MAT_N + clampi(col + d.x, 0, MAT_N - 1)
