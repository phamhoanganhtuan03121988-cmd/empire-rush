## Procedural, tileable material textures for the miniature-city kit (M2.3).
## Albedo maps are near-white detail maps: the kit's vertex colours carry the
## hue, the texture adds surface variation (multiplied in the material), so one
## texture serves every district palette. Heights become normal maps.
## Everything is generated from fixed seeds, so re-running the forge gives
## byte-identical PNGs.
class_name TexGen
extends RefCounted

const SIZE := 512


static func _noise(seed_value: int, freq: float, octaves := 4) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = octaves
	return n


## Seamless noise: sample 3D noise on a torus, so the texture tiles in both
## axes (a, b are the texture angles 0..TAU).
static func _torus3(n: FastNoiseLite, a: float, b: float, r: float) -> float:
	var R := r * 2.0
	return n.get_noise_3d((R + r * cos(b)) * cos(a), (R + r * cos(b)) * sin(a), r * sin(b))


static func _img() -> Image:
	return Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)


static func _gray(img: Image, x: int, y: int, v: float) -> void:
	v = clampf(v, 0.0, 1.0)
	img.set_pixel(x, y, Color(v, v, v, 1.0))


static func _normal_from_height(h: Image, strength: float) -> Image:
	var n := h.duplicate() as Image
	n.convert(Image.FORMAT_RGBA8)
	n.bump_map_to_normal_map(strength)
	return n


## Rectangular pavers in running bond with mortar joints.
static func paving() -> Array:
	var alb := _img()
	var hgt := _img()
	var nz := _noise(11, 0.02)
	var fine := _noise(12, 0.12, 2)
	var bw := 64
	var bh := 32
	for y in SIZE:
		for x in SIZE:
			var row := y / bh
			var ox := (x + (bw / 2 if row % 2 == 1 else 0)) % SIZE
			var jx := mini(ox % bw, bw - ox % bw)
			var jy := mini(y % bh, bh - y % bh)
			var j := mini(jx, jy)
			var stone_id := (ox / bw) * 31 + row * 17
			var tone := 0.88 + 0.06 * sin(stone_id * 12.9898) + 0.05 * _torus3(nz, TAU * x / SIZE, TAU * y / SIZE, SIZE / TAU)
			tone += 0.03 * _torus3(fine, TAU * x / SIZE, TAU * y / SIZE, SIZE / TAU)
			var joint := smoothstep(0.0, 3.0, float(j))
			_gray(alb, x, y, lerpf(0.55, tone, joint))
			_gray(hgt, x, y, lerpf(0.0, 0.7 + 0.1 * _torus3(fine, TAU * x / SIZE, TAU * y / SIZE, SIZE / TAU), joint))
	return [alb, _normal_from_height(hgt, 6.0)]


## Ashlar quay wall: large blocks, chiselled edges, weathering.
static func stone_wall() -> Array:
	var alb := _img()
	var hgt := _img()
	var nz := _noise(21, 0.015)
	var grain := _noise(22, 0.2, 2)
	var bw := 128
	var bh := 64
	for y in SIZE:
		for x in SIZE:
			var row := y / bh
			var ox := (x + (bw / 2 if row % 2 == 1 else 0) + row * 23) % SIZE
			var jx := mini(ox % bw, bw - ox % bw)
			var jy := mini(y % bh, bh - y % bh)
			var j := mini(jx, jy)
			var id := (ox / bw) * 7 + row * 13
			var a := TAU * x / SIZE
			var b := TAU * y / SIZE
			var tone := 0.84 + 0.07 * sin(id * 78.233) + 0.07 * _torus3(nz, a, b, SIZE / TAU) + 0.04 * _torus3(grain, a, b, SIZE / TAU)
			var joint := smoothstep(0.0, 5.0, float(j))
			_gray(alb, x, y, lerpf(0.45, tone, joint))
			_gray(hgt, x, y, lerpf(0.0, 0.8, joint) * (0.85 + 0.15 * _torus3(grain, a, b, SIZE / TAU)))
	return [alb, _normal_from_height(hgt, 8.0)]


static func asphalt() -> Array:
	var alb := _img()
	var hgt := _img()
	var speck := _noise(31, 0.35, 1)
	var patch := _noise(32, 0.01, 3)
	for y in SIZE:
		for x in SIZE:
			var a := TAU * x / SIZE
			var b := TAU * y / SIZE
			var s := _torus3(speck, a, b, SIZE / TAU)
			var p := _torus3(patch, a, b, SIZE / TAU)
			_gray(alb, x, y, 0.82 + 0.08 * p + (0.1 if s > 0.55 else 0.0) - (0.08 if s < -0.6 else 0.0))
			_gray(hgt, x, y, 0.5 + 0.5 * s)
	return [alb, _normal_from_height(hgt, 2.0)]


static func grass() -> Array:
	var alb := _img()
	var blades := _noise(41, 0.25, 2)
	var patch := _noise(42, 0.012, 3)
	for y in SIZE:
		for x in SIZE:
			var a := TAU * x / SIZE
			var b := TAU * y / SIZE
			_gray(alb, x, y, 0.86 + 0.08 * _torus3(patch, a, b, SIZE / TAU) + 0.06 * _torus3(blades, a, b, SIZE / TAU))
	return [alb]


## Clay roof tiles: overlapping rows with a shadow under each course.
static func roof_tiles() -> Array:
	var alb := _img()
	var hgt := _img()
	var nz := _noise(51, 0.05, 2)
	var tw := 32
	var th := 24
	for y in SIZE:
		for x in SIZE:
			var row := y / th
			var ox := (x + (tw / 2 if row % 2 == 1 else 0)) % SIZE
			var u := float(ox % tw) / tw
			var v := float(y % th) / th
			var arch := sin(u * PI)
			var h := v * (0.6 + 0.4 * arch)
			var a := TAU * x / SIZE
			var b := TAU * y / SIZE
			_gray(alb, x, y, 0.72 + 0.25 * h + 0.06 * _torus3(nz, a, b, SIZE / TAU) + 0.04 * sin((ox / tw + row * 3) * 4.1))
			_gray(hgt, x, y, h)
	return [alb, _normal_from_height(hgt, 5.0)]


## Painted render with fine trowel noise (facades).
static func plaster() -> Array:
	var alb := _img()
	var hgt := _img()
	var fine := _noise(61, 0.18, 3)
	var stain := _noise(62, 0.008, 3)
	for y in SIZE:
		for x in SIZE:
			var a := TAU * x / SIZE
			var b := TAU * y / SIZE
			var f := _torus3(fine, a, b, SIZE / TAU)
			_gray(alb, x, y, 0.93 + 0.04 * _torus3(stain, a, b, SIZE / TAU) + 0.025 * f)
			_gray(hgt, x, y, 0.5 + 0.5 * f)
	return [alb, _normal_from_height(hgt, 1.5)]


static func wood() -> Array:
	var alb := _img()
	var hgt := _img()
	var grain := _noise(71, 0.04, 3)
	var pw := 48
	for y in SIZE:
		for x in SIZE:
			var plank := x / pw
			var e := mini(x % pw, pw - x % pw)
			var a := TAU * x / SIZE
			var b := TAU * y / SIZE
			var g := _torus3(grain, a * 0.25 + plank, b * 4.0, SIZE / TAU)
			var tone := 0.78 + 0.08 * sin(plank * 3.7) + 0.1 * g
			var edge := smoothstep(0.0, 2.5, float(e))
			_gray(alb, x, y, lerpf(0.45, tone, edge))
			_gray(hgt, x, y, edge * (0.8 + 0.2 * g))
	return [alb, _normal_from_height(hgt, 4.0)]


static func foliage() -> Array:
	var alb := _img()
	var hgt := _img()
	var leaves := _noise(81, 0.09, 3)
	for y in SIZE:
		for x in SIZE:
			var a := TAU * x / SIZE
			var b := TAU * y / SIZE
			var l := _torus3(leaves, a, b, SIZE / TAU)
			_gray(alb, x, y, 0.8 + 0.2 * l)
			_gray(hgt, x, y, 0.5 + 0.5 * l)
	return [alb, _normal_from_height(hgt, 5.0)]


## Polished light stone for the tile tops (soft veining).
static func marble() -> Array:
	var alb := _img()
	var vein := _noise(91, 0.006, 5)
	var fine := _noise(92, 0.15, 2)
	for y in SIZE:
		for x in SIZE:
			var a := TAU * x / SIZE
			var b := TAU * y / SIZE
			var v := absf(sin(8.0 * _torus3(vein, a, b, SIZE / TAU) + a))
			_gray(alb, x, y, 0.94 + 0.04 * v + 0.015 * _torus3(fine, a, b, SIZE / TAU))
	return [alb]


## Radial soft shadow (alpha) for contact shadows under buildings / props.
static func contact_shadow() -> Image:
	var s := 256
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	for y in s:
		for x in s:
			# Rounded-square falloff matches box footprints better than a disc.
			var u := absf((x + 0.5) / s * 2.0 - 1.0)
			var v := absf((y + 0.5) / s * 2.0 - 1.0)
			var d := pow(pow(u, 4.0) + pow(v, 4.0), 0.25)
			var alpha := 1.0 - smoothstep(0.35, 1.0, d)
			img.set_pixel(x, y, Color(0, 0, 0, alpha * 0.85))
	return img
