## Fixed isometric-style camera that frames the whole board inside the free
## screen area left by the HUD (portrait or landscape). Framing is solved
## numerically by projecting the board's extreme points, so perspective
## (the near corner looks bigger) is accounted for.
class_name CameraRig
extends Camera3D

const MARGIN := 0.03  # fraction of the free area kept empty around the board

## Framing parameters (presentation tuning; see docs/M2_1_MOBILE_READABILITY_REPORT.md).
var yaw := 45.0
var pitch := 58.0
var half := 4.05  # tile ring half-size (+5 cm): the decorative quay may crop, tiles never
var tall := 1.3   # towers on the ring stay in frame

var _points: Array[Vector3] = []


func configure(p_yaw: float, p_pitch: float, p_half: float, p_tall: float) -> void:
	yaw = p_yaw
	pitch = p_pitch
	half = p_half
	tall = p_tall
	_points.clear()


func _build_points() -> void:
	_points.clear()
	for x in [-half, half]:
		for z in [-half, half]:
			_points.append(Vector3(x, -0.1, z))
			_points.append(Vector3(x, tall, z))


func frame(insets: Dictionary) -> void:
	if _points.is_empty():
		_build_points()
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
	var dir := Basis.from_euler(Vector3(deg_to_rad(-pitch), deg_to_rad(yaw), 0)) * Vector3(0, 0, 1)
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
