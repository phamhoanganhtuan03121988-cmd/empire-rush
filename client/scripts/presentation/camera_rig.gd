## Fixed isometric-style camera that frames the whole board inside the free
## screen area left by the HUD (portrait or landscape). Framing is solved
## numerically by projecting the board's extreme points, so perspective
## (the near corner looks bigger) is accounted for.
class_name CameraRig
extends Camera3D

const YAW := 45.0
const PITCH := 50.0
const HALF := 4.6     # board skirt half-size (m)
const TALL := 1.6     # tallest building height (m)
const MARGIN := 0.03  # fraction of the free area kept empty around the board

var _points: Array[Vector3] = []


func _ready() -> void:
	for x in [-HALF, HALF]:
		for z in [-HALF, HALF]:
			_points.append(Vector3(x, -0.4, z))
			_points.append(Vector3(x, TALL, z))


func frame(insets: Dictionary) -> void:
	var vp := get_viewport().get_visible_rect().size
	keep_aspect = Camera3D.KEEP_WIDTH if vp.y > vp.x else Camera3D.KEEP_HEIGHT
	fov = 32.0
	var free := Rect2(vp.x * insets.get("left", 0.0), vp.y * insets.get("top", 0.0), 0, 0)
	free.size = Vector2(vp.x * (1.0 - insets.get("left", 0.0) - insets.get("right", 0.0)),
		vp.y * (1.0 - insets.get("top", 0.0) - insets.get("bottom", 0.0)))
	free = free.grow_individual(-free.size.x * MARGIN, -free.size.y * MARGIN, -free.size.x * MARGIN, -free.size.y * MARGIN)
	var lo := 4.0
	var hi := 120.0
	for i in 28:
		var mid := (lo + hi) * 0.5
		if _fits(mid, free, vp):
			hi = mid
		else:
			lo = mid
	_place(hi, free, vp)


func _place(dist: float, free: Rect2, vp: Vector2) -> Rect2:
	h_offset = 0.0
	v_offset = 0.0
	var dir := Basis.from_euler(Vector3(deg_to_rad(-PITCH), deg_to_rad(YAW), 0)) * Vector3(0, 0, 1)
	look_at_from_position(dir * dist, Vector3(0, 0.2, 0))
	var bb := _bbox()
	# Shift the frustum so the board's projected box is centred in `free`.
	var px_per_m := (vp.x if keep_aspect == Camera3D.KEEP_WIDTH else vp.y) * 0.5 / (dist * tan(deg_to_rad(fov * 0.5)))
	var shift := free.get_center() - bb.get_center()
	h_offset = -shift.x / px_per_m
	v_offset = shift.y / px_per_m
	return _bbox()


func _fits(dist: float, free: Rect2, vp: Vector2) -> bool:
	var bb := _place(dist, free, vp)
	return free.grow(1.0).encloses(bb)


func _bbox() -> Rect2:
	var bb := Rect2(unproject_position(_points[0]), Vector2.ZERO)
	for p in _points:
		bb = bb.expand(unproject_position(p))
	return bb
