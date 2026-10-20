## Maps the 28 board spaces onto the perimeter of an 8x8 grid (presentation
## only). Space 0 (Start) is the corner nearest the camera; play runs
## clockwise as seen from above: bottom edge right->left, left edge, top, right.
class_name BoardLayout
extends RefCounted

const SIDE := 8
const TILE := 1.0
const GAP := 0.06


static func grid_of(index: int) -> Vector2i:
	if index <= 7:
		return Vector2i(7 - index, 7)
	if index <= 14:
		return Vector2i(0, 7 - (index - 7))
	if index <= 21:
		return Vector2i(index - 14, 0)
	return Vector2i(7, index - 21)


static func position_of(index: int) -> Vector3:
	var g := grid_of(index)
	return Vector3((g.x - 3.5) * TILE, 0.0, (g.y - 3.5) * TILE)


static func is_corner(index: int) -> bool:
	return index % 7 == 0


## Unit vector from the tile towards the board centre (for orienting tiles).
static func inward(index: int) -> Vector3:
	if is_corner(index):
		return -position_of(index).normalized()
	var g := grid_of(index)
	if g.y == 7:
		return Vector3(0, 0, -1)
	if g.x == 0:
		return Vector3(1, 0, 0)
	if g.y == 0:
		return Vector3(0, 0, 1)
	return Vector3(-1, 0, 0)
