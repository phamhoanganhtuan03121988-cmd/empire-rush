## Fixed isometric-style camera that frames the whole board in the free area
## between HUD panels, for portrait and landscape.
class_name CameraRig
extends Camera3D

const YAW := 45.0
const PITCH := 52.0
const BOARD_HALF_DIAG := 6.5  # 9 m skirt rotated 45° plus margin


func frame(insets: Dictionary) -> void:
	var vp := get_viewport().get_visible_rect().size
	var portrait := vp.y > vp.x
	fov = 34.0
	keep_aspect = Camera3D.KEEP_WIDTH if portrait else Camera3D.KEEP_HEIGHT
	var free_w: float = 1.0 - insets.get("left", 0.0) - insets.get("right", 0.0)
	var free_h: float = 1.0 - insets.get("top", 0.0) - insets.get("bottom", 0.0)
	var aspect := vp.x / vp.y
	# Half-angles of the free region.
	var h_half: float
	var v_half: float
	if portrait:
		h_half = deg_to_rad(fov * 0.5)
		v_half = atan(tan(h_half) / aspect)
	else:
		v_half = deg_to_rad(fov * 0.5)
		h_half = atan(tan(v_half) * aspect)
	var need_w := BOARD_HALF_DIAG / tan(h_half) / maxf(free_w, 0.2)
	var need_h := BOARD_HALF_DIAG * sin(deg_to_rad(PITCH)) / tan(v_half) / maxf(free_h, 0.2) + 1.5
	var dist := maxf(need_w, need_h)
	var dir := Basis.from_euler(Vector3(deg_to_rad(-PITCH), deg_to_rad(YAW), 0)) * Vector3(0, 0, 1)
	look_at_from_position(dir * dist, Vector3(0, 0.3, 0))
	# Shift the image so the board centre sits in the middle of the free area.
	var cy: float = insets.get("bottom", 0.0) - insets.get("top", 0.0)
	var cx: float = insets.get("right", 0.0) - insets.get("left", 0.0)
	var half_h_world := tan(v_half) * dist
	var half_w_world := tan(h_half) * dist
	v_offset = -cy * half_h_world
	h_offset = cx * half_w_world
