## Building models for the 7 districts x 3 upgrade levels (M2.3).
## Each district has its own architectural family so silhouettes differ, and
## each level adds mass, height and detail so the upgrade reads at phone size:
## L1 ~0.3-0.45 m, L2 ~0.6-0.8 m, L3 ~1.0-1.3 m (camera frames 1.3 m towers).
## Footprint stays inside 0.52 x 0.52 m (the lot on a 1 m tile). Front = +z.
class_name Buildings
extends RefCounted

const CREAM := Color("#efe5d1")
const WARM := Color("#f5f1e8")
const SAND := Color("#e0cfae")
const TERRA := Color("#b65a36")
const SLATE := Color("#5d6873")
const GLASS := Color("#36505f")
const GLASS_BLUE := Color("#4d7ca6")
const GOLD := Color("#d8a63a")
const CONCRETE := Color("#d3cec4")
const DARK := Color("#3b4048")
const WOOD := Color("#8a5a3c")
const WHITE := Color("#fbfaf6")

## district id -> [L1, L2, L3] builder method names
const TABLE := {
	"D1": ["market_l1", "market_l2", "market_l3"],
	"D2": ["harbor_l1", "harbor_l2", "harbor_l3"],
	"D3": ["river_l1", "river_l2", "river_l3"],
	"D4": ["flower_l1", "flower_l2", "flower_l3"],
	"D5": ["resort_l1", "resort_l2", "resort_l3"],
	"D6": ["finance_l1", "finance_l2", "finance_l3"],
	"D7": ["elite_l1", "elite_l2", "elite_l3"],
}


static func build(district: String, level: int, accent: Color, seed_value: int) -> ModelKit:
	var k := ModelKit.new(seed_value)
	var b := Buildings.new()
	b.call(TABLE[district][level - 1], k, accent)
	k.bake_ground_ao(0.14, 0.7)
	return k


# --- D1 Cho Cu: old market shophouses -------------------------------------------------

func _shophouse(k: ModelKit, x: float, z: float, w: float, d: float, floors: int, body: Color, roof: Color, awn: Color) -> float:
	var fh := 0.13
	var h := fh * floors
	k.block(w, h, d, x, 0.0, z, body)
	k.band(w, d, x, z, fh - 0.008, 0.014, WARM, 0.012)
	k.windows(w, d, x, z, fh, h, floors - 1, 2, 2, GLASS, 0.3, WARM)
	# Ground-floor shop front (lit) + awning.
	k.box(Vector3(w * 0.7, fh * 0.6, 0.008), Vector3(x, fh * 0.36, z + d * 0.5 + 0.004), Color("#ffcf86"), "window_glow")
	k.awning(w * 0.86, Vector3(x, fh * 0.82, z + d * 0.5), Vector3(0, 0, 1), awn, WHITE, 5)
	k.gable(w + 0.04, 0.1, d + 0.04, Vector3(x, h, z), roof, true)
	return h


func market_l1(k: ModelKit, accent: Color) -> void:
	k.contact_shadow(0.5, 0.42)
	_shophouse(k, 0, 0, 0.3, 0.28, 2, CREAM, TERRA, accent)
	# Fruit crates on the pavement.
	for i in 3:
		k.block(0.05, 0.035, 0.04, -0.09 + i * 0.07, 0.0, 0.2, WOOD, "wood")
		k.sphere(0.012, Vector3(-0.09 + i * 0.07, 0.04, 0.2), [Color("#e5533d"), Color("#f2b134"), Color("#7cb342")][i], "foliage", 6)


func market_l2(k: ModelKit, accent: Color) -> void:
	k.contact_shadow(0.56, 0.44)
	var cols := [CREAM, Color("#f0d9b5"), Color("#e9c9a8")]
	for i in 3:
		var x := -0.16 + i * 0.16
		var h := _shophouse(k, x, 0, 0.15, 0.3, 3 + (i % 2), cols[i], TERRA.darkened(0.05 * i), accent if i != 1 else accent.lightened(0.25))
		# Balcony with railing on the second floor.
		k.box(Vector3(0.13, 0.008, 0.04), Vector3(x, 0.26, 0.17), WARM, "concrete")
		k.box(Vector3(0.13, 0.03, 0.004), Vector3(x, 0.28, 0.19), DARK, "metal")


func market_l3(k: ModelKit, accent: Color) -> void:
	k.contact_shadow(0.56, 0.5)
	# Covered market hall with arched clerestory.
	k.block(0.5, 0.26, 0.36, 0, 0, 0.02, SAND)
	k.band(0.5, 0.36, 0, 0.02, 0.24, 0.025, WARM, 0.015)
	k.windows(0.5, 0.36, 0, 0.02, 0.03, 0.24, 1, 5, 3, GLASS, 0.6, WARM, 0.7)
	k.gable(0.54, 0.12, 0.4, Vector3(0, 0.265, 0.02), TERRA, true)
	k.awning(0.42, Vector3(0, 0.12, 0.2), Vector3(0, 0, 1), accent, WHITE, 7)
	# Clock tower.
	# Phase 3: tower raised so L3 reads clearly above L2 (art direction 1.0-1.3 m).
	var th := 0.82
	k.block(0.13, th, 0.13, 0.16, 0, -0.14, CREAM)
	k.windows(0.13, 0.13, 0.16, -0.14, 0.3, th - 0.16, 2, 1, 1, GLASS, 0.25, WARM)
	k.band(0.13, 0.13, 0.16, -0.14, th - 0.01, 0.03, WARM, 0.015)
	k.cylinder(0.035, 0.035, 0.008, Vector3(0.16, th - 0.09, -0.07), GOLD, "gold", 16)
	k.box(Vector3(0.008, 0.07, 0.07), Vector3(0.226, th - 0.09, -0.14), GOLD, "gold")
	k.pyramid(0.16, 0.16, 0.16, Vector3(0.16, th + 0.02, -0.14), TERRA.darkened(0.1))
	k.cylinder(0.0, 0.012, 0.06, Vector3(0.16, th + 0.21, -0.14), GOLD, "gold", 6)


# --- D2 Cang Bien: harbour ------------------------------------------------------------

func _container(k: ModelKit, pos: Vector3, c: Color, rot := 0.0) -> void:
	k.box(Vector3(0.16, 0.06, 0.065), pos + Vector3(0, 0.03, 0), c, "metal", rot)
	k.box(Vector3(0.162, 0.008, 0.067), pos + Vector3(0, 0.062, 0), c.darkened(0.2), "metal", rot)


func harbor_l1(k: ModelKit, accent: Color) -> void:
	k.contact_shadow(0.52, 0.44)
	k.block(0.36, 0.2, 0.3, 0, 0, -0.03, Color("#c9cfd3"), "concrete")
	k.gable(0.4, 0.1, 0.34, Vector3(0, 0.2, -0.03), accent.darkened(0.15), false, "roof_tile")
	k.box(Vector3(0.16, 0.13, 0.008), Vector3(0, 0.065, 0.124), DARK, "metal")
	k.box(Vector3(0.12, 0.02, 0.008), Vector3(0, 0.17, 0.124), Color("#ffd58a"), "window_glow")
	k.windows(0.36, 0.3, 0, -0.03, 0.06, 0.18, 1, 0, 3, GLASS, 0.2, WARM)
	_container(k, Vector3(-0.14, 0, 0.2), Color("#c0392b"))
	_container(k, Vector3(0.1, 0, 0.2), Color("#2a9d8f"))


func harbor_l2(k: ModelKit, accent: Color) -> void:
	k.contact_shadow(0.56, 0.5)
	k.block(0.3, 0.52, 0.26, -0.08, 0, -0.08, WARM, "concrete")
	for f in 4:
		k.band(0.3, 0.26, -0.08, -0.08, 0.12 + f * 0.12, 0.012, accent, 0.008)
	k.windows(0.3, 0.26, -0.08, -0.08, 0.02, 0.5, 4, 3, 3, GLASS_BLUE, 0.3, WARM, 0.6)
	k.block(0.32, 0.02, 0.28, -0.08, 0.52, -0.08, CONCRETE, "concrete")
	k.cylinder(0.03, 0.03, 0.06, Vector3(-0.15, 0.57, -0.12), Color("#9aa3ab"), "metal", 10)
	# Container stack.
	_container(k, Vector3(0.15, 0, 0.12), Color("#e07a2f"), PI * 0.5)
	_container(k, Vector3(0.15, 0.065, 0.12), Color("#2f80ed"), PI * 0.5)
	_container(k, Vector3(0.0, 0, 0.2), Color("#27ae60"))


func harbor_l3(k: ModelKit, accent: Color) -> void:
	k.contact_shadow(0.56, 0.56)
	# Ferry terminal + lighthouse.
	k.block(0.42, 0.18, 0.22, -0.04, 0, 0.12, WARM, "concrete")
	k.box(Vector3(0.38, 0.1, 0.008), Vector3(-0.04, 0.09, 0.234), GLASS_BLUE, "glass")
	k.box(Vector3(0.46, 0.015, 0.26), Vector3(-0.04, 0.19, 0.12), accent, "metal")
	var r := 0.085
	var prof := PackedVector2Array([Vector2(r, 0), Vector2(r * 0.8, 0.85), Vector2(r * 0.95, 0.86), Vector2(r * 0.95, 0.9), Vector2(r * 0.6, 0.9)])
	k.lathe(prof, Vector3(0.12, 0, -0.12), WHITE, "plaster", 20)
	for i in 3:
		k.cylinder(r * (0.97 - i * 0.07), r * (1.0 - i * 0.07), 0.07, Vector3(0.12, 0.15 + i * 0.25, -0.12), Color("#c0392b"), "plaster", 20)
	k.cylinder(0.05, 0.05, 0.08, Vector3(0.12, 0.94, -0.12), Color("#ffe39a"), "window_glow", 12)
	k.cylinder(0.0, 0.065, 0.07, Vector3(0.12, 1.015, -0.12), DARK, "metal", 12)
	k.torus(0.055, 0.065, Vector3(0.12, 0.9, -0.12), DARK, "metal")


# --- D3 Ven Song: riverside living ----------------------------------------------------

func river_l1(k: ModelKit, accent: Color) -> void:
	k.contact_shadow(0.5, 0.46)
	k.block(0.28, 0.17, 0.24, -0.05, 0, -0.04, CREAM)
	k.windows(0.28, 0.24, -0.05, -0.04, 0.03, 0.15, 1, 2, 2, GLASS, 0.4, WARM, 0.6)
	k.pyramid(0.34, 0.12, 0.3, Vector3(-0.05, 0.17, -0.04), accent.darkened(0.25))
	k.box(Vector3(0.06, 0.1, 0.008), Vector3(-0.05, 0.05, 0.084), WOOD, "wood")
	k.hedge(0.42, 0.04, Vector3(0, 0, 0.21))
	k.tree_round(Vector3(0.17, 0, 0.1), 0.85)
	k.flowers(Vector3(-0.12, 0, 0.16), 6, 0.05, [Color("#f6c1d1"), Color("#ffe08a")])


func river_l2(k: ModelKit, accent: Color) -> void:
	k.contact_shadow(0.56, 0.46)
	for i in 2:
		var x := -0.12 + i * 0.24
		var h := 0.48 + 0.08 * i
		k.block(0.22, h, 0.28, x, 0, -0.02, [CREAM, Color("#e8efe0")][i])
		k.windows(0.22, 0.28, x, -0.02, 0.03, h - 0.02, 3 + i, 2, 2, GLASS, 0.35, WARM)
		k.block(0.24, 0.02, 0.3, x, h, -0.02, accent.darkened(0.2), "concrete")
		# Rooftop planter.
		k.hedge(0.16, 0.08, Vector3(x, h + 0.02, -0.05), Color("#5c9a45"))
	k.tree_round(Vector3(0.0, 0, 0.2), 0.7)


func river_l3(k: ModelKit, accent: Color) -> void:
	k.contact_shadow(0.56, 0.56)
	# Stepped terrace condo with green terraces.
	var steps := [[0.48, 0.3, 0.0], [0.4, 0.26, 0.3], [0.32, 0.22, 0.56], [0.24, 0.2, 0.82]]
	for i in steps.size():
		var s: Array = steps[i]
		var w: float = s[0]
		var h: float = s[1]
		var y0: float = s[2]
		var z := -0.04 * i
		k.block(w, h, w * 0.9, 0, y0, z, WARM)
		k.windows(w, w * 0.9, 0, z, y0 + 0.02, y0 + h - 0.02, 2, 3, 3, GLASS_BLUE, 0.3, WARM, 0.62)
		k.band(w, w * 0.9, 0, z, y0 + h - 0.012, 0.012, Color("#e3e7ea"), 0.012, "concrete")
		if i < steps.size() - 1:
			k.hedge(w * 0.9, 0.05, Vector3(0, y0 + h, z + w * 0.4), Color("#5a9a48"))
			k.box(Vector3(w, 0.03, 0.004), Vector3(0, y0 + h + 0.015, z + w * 0.45 + 0.01), Color("#a9d6e5"), "glass")
	k.cylinder(0.04, 0.04, 0.05, Vector3(0, 1.045, -0.12), accent, "metal", 10)


# --- D4 Pho Hoa: flower street ---------------------------------------------------------

func flower_l1(k: ModelKit, accent: Color) -> void:
	k.contact_shadow(0.52, 0.46)
	k.block(0.3, 0.28, 0.22, 0, 0, -0.06, Color("#f7e8ec"))
	k.windows(0.3, 0.22, 0, -0.06, 0.02, 0.26, 2, 3, 2, GLASS, 0.6, WARM, 0.62)
	k.block(0.34, 0.02, 0.26, 0, 0.28, -0.06, accent, "concrete")
	# Pergola cafe terrace.
	for x in [-0.14, 0.14]:
		k.block(0.012, 0.13, 0.012, x, 0, 0.18, WOOD, "wood")
	for i in 5:
		k.box(Vector3(0.012, 0.012, 0.16), Vector3(-0.12 + i * 0.06, 0.135, 0.12), WOOD, "wood")
	for x in [-0.08, 0.08]:
		k.cylinder(0.03, 0.03, 0.005, Vector3(x, 0.05, 0.14), WHITE, "metal", 10)
		k.cylinder(0.004, 0.004, 0.05, Vector3(x, 0.025, 0.14), DARK, "metal", 4)
	k.flowers(Vector3(0, 0, 0.22), 10, 0.04, [accent.lightened(0.2), Color("#ffe08a"), Color("#ffffff")])


func flower_l2(k: ModelKit, accent: Color) -> void:
	k.contact_shadow(0.54, 0.46)
	k.block(0.4, 0.56, 0.3, 0, 0, -0.03, Color("#f9efe9"))
	k.windows(0.4, 0.3, 0, -0.03, 0.03, 0.54, 3, 3, 2, GLASS, 0.4, WARM, 0.62)
	for f in 2:
		var y := 0.17 + f * 0.16
		k.box(Vector3(0.36, 0.02, 0.035), Vector3(0, y, 0.135), accent.darkened(0.1), "concrete")
		k.flowers(Vector3(0, y + 0.01, 0.135), 8, 0.16, [accent.lightened(0.25), Color("#ffd6e5"), Color("#fff0a8")])
	k.band(0.4, 0.3, 0, -0.03, 0.54, 0.03, WARM, 0.02)
	k.gable(0.36, 0.08, 0.26, Vector3(0, 0.57, -0.03), Color("#7b5d6e"), true)
	k.awning(0.34, Vector3(0, 0.12, 0.12), Vector3(0, 0, 1), accent, WHITE, 6)


func flower_l3(k: ModelKit, accent: Color) -> void:
	k.contact_shadow(0.56, 0.56)
	# Botanical mall: stone base + glass dome greenhouse.
	# Phase 3: two-storey base and a taller dome so L3 clearly tops L2.
	var b := 0.5
	k.block(0.5, b, 0.48, 0, 0, 0, WARM)
	k.windows(0.5, 0.48, 0, 0, 0.03, b - 0.02, 2, 4, 4, GLASS, 0.6, WARM, 0.7)
	k.band(0.5, 0.48, 0, 0, b - 0.01, 0.025, accent, 0.02)
	var dome := PackedVector2Array()
	for i in 9:
		var a := PI * 0.5 * i / 8.0
		dome.append(Vector2(0.21 * cos(a), b + 0.015 + 0.45 * sin(a)))
	k.lathe(dome, Vector3.ZERO, Color("#9fd3c7"), "glass", 24)
	for i in 6:
		var ang := TAU * i / 6.0
		k.box(Vector3(0.008, 0.42, 0.008), Vector3(cos(ang) * 0.15, b + 0.22, sin(ang) * 0.15), WHITE, "metal")
	k.sphere(0.13, Vector3(0, b + 0.08, 0), Color("#5d9f4e"), "foliage", 10, 0.7)
	k.cylinder(0.0, 0.03, 0.08, Vector3(0, b + 0.48, 0), GOLD, "gold", 8)
	k.flowers(Vector3(0, b + 0.015, 0.2), 8, 0.03, [accent.lightened(0.2), Color("#ffe08a")])


# --- D5 Khu Nghi Duong: resort ---------------------------------------------------------

func resort_l1(k: ModelKit, accent: Color) -> void:
	k.contact_shadow(0.52, 0.46)
	k.block(0.28, 0.02, 0.26, -0.04, 0, -0.03, WOOD, "wood")
	k.block(0.22, 0.13, 0.2, -0.04, 0.02, -0.04, Color("#f6ecd9"))
	k.windows(0.22, 0.2, -0.04, -0.04, 0.03, 0.14, 1, 2, 2, GLASS, 0.6, WARM, 0.6)
	k.pyramid(0.32, 0.17, 0.3, Vector3(-0.04, 0.15, -0.04), Color("#c9a66b"))
	k.palm(Vector3(0.17, 0, 0.12), 0.8)
	k.box(Vector3(0.12, 0.006, 0.08), Vector3(-0.08, 0.004, 0.17), Color("#5fc3d9"), "glass")


func resort_l2(k: ModelKit, accent: Color) -> void:
	k.contact_shadow(0.56, 0.5)
	# Three-storey resort wing with balconies over a pool deck.
	k.block(0.46, 0.58, 0.22, 0, 0, -0.12, WHITE)
	for f in 4:
		k.box(Vector3(0.46, 0.012, 0.05), Vector3(0, 0.11 + f * 0.12, 0.012), WHITE, "concrete")
		k.box(Vector3(0.46, 0.025, 0.004), Vector3(0, 0.125 + f * 0.12, 0.036), Color("#a9d6e5"), "glass")
	k.windows(0.46, 0.22, 0, -0.12, 0.02, 0.57, 4, 4, 2, GLASS, 0.4, WARM, 0.6)
	k.block(0.48, 0.02, 0.24, 0, 0.58, -0.12, accent, "concrete")
	# Pool deck.
	k.block(0.4, 0.015, 0.16, 0, 0, 0.14, WOOD, "wood")
	k.box(Vector3(0.28, 0.006, 0.1), Vector3(0, 0.018, 0.14), Color("#4fc1d6"), "glass")
	for x in [-0.17, 0.17]:
		k.palm(Vector3(x, 0, 0.2), 0.8)


func resort_l3(k: ModelKit, accent: Color) -> void:
	k.contact_shadow(0.56, 0.56)
	# Curved hotel: thin white floor slabs (balconies) over recessed glass.
	var floors := 8
	for f in floors:
		var y := 0.05 + f * 0.13
		var r := 0.2 - 0.006 * f
		k.cylinder(r - 0.025, r - 0.025, 0.116, Vector3(0, y + 0.07, 0), Color("#5d9bb5"), "glass", 24)
		k.cylinder(r, r, 0.016, Vector3(0, y + 0.008, 0), WHITE, "plaster", 24)
		k.cylinder(r - 0.004, r - 0.004, 0.022, Vector3(0, y + 0.027, 0), Color("#cfe9f2"), "glass", 24)
		if f % 3 == 1:
			k.cylinder(r - 0.022, r - 0.022, 0.05, Vector3(0, y + 0.07, 0), Color("#ffd58a"), "window_glow", 12)
	k.cylinder(0.2 - 0.006 * floors, 0.2 - 0.006 * floors, 0.016, Vector3(0, 0.05 + floors * 0.13 + 0.008, 0), WHITE, "plaster", 24)
	k.cylinder(0.24, 0.25, 0.05, Vector3(0, 0.025, 0), accent.darkened(0.1), "concrete", 24)
	k.cylinder(0.12, 0.17, 0.05, Vector3(0, 1.12, 0), accent, "metal", 20)
	k.cylinder(0.05, 0.05, 0.02, Vector3(0, 1.155, 0), Color("#ffe39a"), "window_glow", 12)
	k.palm(Vector3(0.18, 0, 0.18), 0.7)


# --- D6 Trung Tam Tai Chinh: finance ----------------------------------------------------

func _fins(k: ModelKit, w: float, d: float, y0: float, h: float, n: int, color: Color) -> void:
	for i in n:
		var x := -w * 0.5 + w * (i + 0.5) / n
		k.box(Vector3(0.012, h, 0.02), Vector3(x, y0 + h * 0.5, d * 0.5 + 0.01), color, "metal")
		k.box(Vector3(0.012, h, 0.02), Vector3(x, y0 + h * 0.5, -d * 0.5 - 0.01), color, "metal")


func finance_l1(k: ModelKit, accent: Color) -> void:
	k.contact_shadow(0.52, 0.48)
	k.block(0.4, 0.06, 0.34, 0, 0, 0, CONCRETE, "concrete")
	k.block(0.36, 0.3, 0.3, 0, 0.06, 0, GLASS_BLUE, "glass")
	k.windows(0.36, 0.3, 0, 0, 0.07, 0.35, 3, 4, 3, Color("#2e4a63"), 0.35, WHITE, 0.7)
	_fins(k, 0.36, 0.3, 0.06, 0.3, 6, Color("#dfe6ec"))
	k.block(0.38, 0.02, 0.32, 0, 0.36, 0, accent, "metal")


func finance_l2(k: ModelKit, accent: Color) -> void:
	k.contact_shadow(0.56, 0.52)
	k.block(0.46, 0.08, 0.4, 0, 0, 0, CONCRETE, "concrete")
	k.block(0.38, 0.42, 0.32, 0, 0.08, 0, GLASS_BLUE, "glass")
	k.windows(0.38, 0.32, 0, 0, 0.09, 0.49, 5, 4, 3, Color("#2e4a63"), 0.3, WHITE, 0.72)
	k.band(0.38, 0.32, 0, 0, 0.5, 0.015, Color("#dfe6ec"), 0.01, "metal")
	k.block(0.28, 0.2, 0.24, 0.03, 0.515, -0.02, GLASS_BLUE.lightened(0.1), "glass")
	k.windows(0.28, 0.24, 0.03, -0.02, 0.52, 0.71, 2, 3, 2, Color("#2e4a63"), 0.4, WHITE, 0.72)
	k.block(0.3, 0.02, 0.26, 0.03, 0.715, -0.02, accent, "metal")


func finance_l3(k: ModelKit, accent: Color) -> void:
	k.contact_shadow(0.56, 0.56)
	k.block(0.48, 0.07, 0.48, 0, 0, 0, CONCRETE, "concrete")
	var tiers := [[0.36, 0.5], [0.3, 0.32], [0.22, 0.2]]
	var y := 0.07
	for t in tiers:
		var w: float = t[0]
		var h: float = t[1]
		k.block(w, h, w, 0, y, 0, Color("#5f8fb9"), "glass")
		k.windows(w, w, 0, 0, y + 0.01, y + h - 0.01, int(h / 0.065), 4, 4, Color("#2c4860"), 0.3, WHITE, 0.72)
		# Vertical corner fins in the accent colour.
		for cx in [-1, 1]:
			for cz in [-1, 1]:
				k.box(Vector3(0.014, h, 0.014), Vector3(cx * w * 0.5, y + h * 0.5, cz * w * 0.5), Color("#e9eef2"), "metal")
		y += h
		k.band(w, w, 0, 0, y - 0.01, 0.014, accent, 0.012, "metal")
	k.cylinder(0.0, 0.03, 0.17, Vector3(0, y + 0.085, 0), Color("#e9eef2"), "metal", 8)
	k.sphere(0.014, Vector3(0, y + 0.175, 0), Color("#ff6b6b"), "window_glow", 6)


# --- D7 Dinh Thuong Luu: elite -----------------------------------------------------------

func elite_l1(k: ModelKit, accent: Color) -> void:
	k.contact_shadow(0.54, 0.5)
	# Modern villa: two offset volumes, cantilever and pool.
	k.block(0.34, 0.13, 0.22, -0.03, 0, -0.08, WHITE)
	k.block(0.26, 0.14, 0.24, 0.04, 0.13, -0.04, Color("#2f3238"), "concrete")
	k.box(Vector3(0.24, 0.09, 0.008), Vector3(0.04, 0.2, 0.084), Color("#ffd58a"), "window_glow")
	k.box(Vector3(0.28, 0.08, 0.008), Vector3(-0.03, 0.065, 0.034), GLASS, "glass")
	k.block(0.28, 0.012, 0.26, 0.04, 0.27, -0.04, accent, "concrete")
	k.box(Vector3(0.3, 0.008, 0.1), Vector3(0, 0.006, 0.18), Color("#4fc1d6"), "glass")
	k.tree_cone(Vector3(-0.2, 0, 0.18), 0.8)


func elite_l2(k: ModelKit, accent: Color) -> void:
	k.contact_shadow(0.56, 0.52)
	# Neoclassical mansion: columns, pediment, dome.
	k.block(0.46, 0.04, 0.38, 0, 0, 0, Color("#e8e2d6"), "marble")
	var lift := 0.13  # Phase 3: taller body so L2 reads between L1 and L3
	k.block(0.4, 0.3 + lift, 0.28, 0, 0.04, -0.04, WARM)
	k.windows(0.4, 0.28, 0, -0.04, 0.06, 0.32 + lift, 3, 4, 3, GLASS, 0.5, WARM, 0.6)
	for i in 6:
		k.cylinder(0.014, 0.016, 0.26 + lift, Vector3(-0.15 + i * 0.06, 0.17 + lift * 0.5, 0.13), WHITE, "marble", 10)
	k.block(0.4, 0.03, 0.08, 0, 0.3 + lift, 0.12, WHITE, "marble")
	k.gable(0.42, 0.07, 0.1, Vector3(0, 0.33 + lift, 0.12), WHITE, true, "marble")
	k.band(0.4, 0.28, 0, -0.04, 0.33 + lift, 0.02, Color("#ddd5c6"), 0.015, "marble")
	var dome := PackedVector2Array()
	for i in 7:
		var a := PI * 0.5 * i / 6.0
		dome.append(Vector2(0.1 * cos(a), 0.35 + lift + 0.1 * sin(a)))
	k.lathe(dome, Vector3(0, 0, -0.06), accent.darkened(0.2), "metal", 20)
	k.cylinder(0.0, 0.012, 0.06, Vector3(0, 0.48 + lift, -0.06), GOLD, "gold", 6)


func elite_l3(k: ModelKit, accent: Color) -> void:
	k.contact_shadow(0.56, 0.56)
	# Luxury tower: dark glass shaft, gold bands, crown.
	k.block(0.46, 0.08, 0.46, 0, 0, 0, Color("#d9d2c4"), "marble")
	var prof := PackedVector2Array([Vector2(0.19, 0.08), Vector2(0.17, 0.6), Vector2(0.15, 1.02), Vector2(0.11, 1.08)])
	k.lathe(prof, Vector3.ZERO, Color("#5b4f86"), "glass", 8)
	for i in 7:
		var y := 0.18 + i * 0.13
		var r := 0.19 - 0.04 * (y - 0.08) / 1.0
		k.cylinder(r + 0.008, r + 0.008, 0.012, Vector3(0, y, 0), GOLD, "gold", 8)
	# Lit floors read as warm slits between the gold bands.
	for i in [1, 3, 4, 6]:
		var y: float = 0.24 + i * 0.13
		var r: float = 0.19 - 0.04 * (y - 0.08)
		k.cylinder(r + 0.003, r + 0.003, 0.03, Vector3(0, y, 0), Color("#ffd58a"), "window_glow", 8)
	# Crown.
	for i in 8:
		var a := TAU * i / 8.0
		k.box(Vector3(0.02, 0.12, 0.02), Vector3(cos(a) * 0.1, 1.13, sin(a) * 0.1), GOLD, "gold")
	k.cylinder(0.11, 0.11, 0.02, Vector3(0, 1.08, 0), GOLD, "gold", 16)
	k.sphere(0.035, Vector3(0, 1.22, 0), accent.lightened(0.3), "window_glow", 10)
