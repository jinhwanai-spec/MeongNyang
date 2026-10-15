class_name ProcModels
extends RefCounted
## 코드로 만드는 3D 소품 (블렌더 없이도 바로 쓰는 둥글둥글한 저폴리 모델).
## 가방·헬멧·조끼·물약·총 부품·제작소·셔터·탈출구 표식 등.
## 단위: 1 = 타일 1칸 (햄스터 키 ≈ 1.2)

static var _mats := {}

# ── 재질 ─────────────────────────────────────────────
static func mat(c: Color, rough: float = 0.75, metal: float = 0.0, emit: float = 0.0) -> StandardMaterial3D:
	var k := "%s_%.2f_%.2f_%.2f" % [c.to_html(), rough, metal, emit]
	if _mats.has(k):
		return _mats[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	if c.a < 0.99:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats[k] = m
	return m

static func glass(c: Color, emit: float = 0.0, a: float = 0.55) -> StandardMaterial3D:
	var m := mat(Color(c, a), 0.08, 0.0, emit)
	return m

static func _mi(parent: Node3D, mesh: Mesh, m: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO, sc: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	mi.scale = sc
	parent.add_child(mi)
	return mi

static func box(parent: Node3D, size: Vector3, pos: Vector3, m: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _mi(parent, b, m, pos, rot)

static func cyl(parent: Node3D, r_top: float, r_bot: float, h: float, pos: Vector3, m: Material, rot: Vector3 = Vector3.ZERO, segs: int = 16) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = segs
	c.rings = 1
	return _mi(parent, c, m, pos, rot)

static func sphere(parent: Node3D, r: float, pos: Vector3, m: Material, sc: Vector3 = Vector3.ONE, hemi: bool = false) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * (1.0 if hemi else 2.0)
	s.is_hemisphere = hemi
	s.radial_segments = 20
	s.rings = 10
	return _mi(parent, s, m, pos, Vector3.ZERO, sc)

static func capsule(parent: Node3D, r: float, h: float, pos: Vector3, m: Material, rot: Vector3 = Vector3.ZERO, sc: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = maxf(h, r * 2.0)
	c.radial_segments = 16
	c.rings = 6
	return _mi(parent, c, m, pos, rot, sc)

static func torus(parent: Node3D, r_in: float, r_out: float, pos: Vector3, m: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = r_in
	t.outer_radius = r_out
	t.rings = 20
	t.ring_segments = 8
	return _mi(parent, t, m, pos, rot)

static func _root(n: String) -> Node3D:
	var r := Node3D.new()
	r.name = n
	return r

# ── 가방 (쓰러진 자리) ───────────────────────────────
static func backpack(c: Color = Color("#D9822B")) -> Node3D:
	var r := _root("backpack")
	var body := mat(c, 0.85)
	var dark := mat(c.darkened(0.35), 0.85)
	var strap := mat(Color("#3A3330"), 0.7)
	var buckle := mat(Color("#E8C26A"), 0.35, 0.7)
	capsule(r, 0.2, 0.52, Vector3(0, 0.27, 0), body, Vector3.ZERO, Vector3(1.0, 1.0, 0.72))
	sphere(r, 0.2, Vector3(0, 0.44, 0), dark, Vector3(1.02, 0.55, 0.78), true)       # 덮개
	box(r, Vector3(0.28, 0.2, 0.1), Vector3(0, 0.2, 0.15), dark)                     # 앞주머니
	box(r, Vector3(0.05, 0.3, 0.03), Vector3(-0.08, 0.32, 0.155), strap)
	box(r, Vector3(0.05, 0.3, 0.03), Vector3(0.08, 0.32, 0.155), strap)
	box(r, Vector3(0.06, 0.04, 0.03), Vector3(-0.08, 0.22, 0.175), buckle)
	box(r, Vector3(0.06, 0.04, 0.03), Vector3(0.08, 0.22, 0.175), buckle)
	torus(r, 0.03, 0.06, Vector3(0, 0.6, -0.02), strap, Vector3(PI * 0.5, 0, 0))     # 손잡이
	capsule(r, 0.07, 0.36, Vector3(0, 0.08, 0.02), mat(Color("#6E8B4E"), 0.9), Vector3(0, 0, PI * 0.5))  # 침낭 말이
	return r

# ── 헬멧 ─────────────────────────────────────────────
## 원점 = 머리 꼭대기 아래 중심. 햄스터 머리에 씌울 때는 크기만 맞춘다.
static func helmet(tier: int) -> Node3D:
	var r := _root("helmet_%d" % tier)
	match tier:
		1:   # 냄비
			var steel := mat(Color("#B9C0C8"), 0.35, 0.85)
			cyl(r, 0.25, 0.27, 0.2, Vector3(0, 0.1, 0), steel)
			cyl(r, 0.255, 0.255, 0.012, Vector3(0, 0.2, 0), mat(Color("#8E969F"), 0.4, 0.8))
			for sx in [-1.0, 1.0]:
				torus(r, 0.03, 0.055, Vector3(sx * 0.29, 0.14, 0), mat(Color("#2B2B2B"), 0.6), Vector3(0, 0, PI * 0.5))
			cyl(r, 0.04, 0.05, 0.03, Vector3(0, 0.215, 0), mat(Color("#2B2B2B"), 0.6))
		2:   # 안전모
			var y := mat(Color("#F2C230"), 0.4)
			sphere(r, 0.26, Vector3(0, 0.0, 0), y, Vector3(1, 0.95, 1.08), true)
			cyl(r, 0.31, 0.32, 0.025, Vector3(0, 0.0, 0.04), y)
			box(r, Vector3(0.05, 0.05, 0.5), Vector3(0, 0.24, 0), mat(Color("#E0AE1E"), 0.4))
			box(r, Vector3(0.14, 0.05, 0.02), Vector3(0, 0.1, 0.27), mat(Color("#FFFFFF"), 0.5))
		_:   # 전술 헬멧
			var olive := mat(Color("#4E5A3A"), 0.8)
			sphere(r, 0.27, Vector3(0, 0.0, 0), olive, Vector3(1.05, 0.98, 1.1), true)
			torus(r, 0.25, 0.29, Vector3(0, 0.06, 0), mat(Color("#2A2A26"), 0.7), Vector3(0, 0, 0))
			box(r, Vector3(0.36, 0.08, 0.08), Vector3(0, 0.12, 0.26), mat(Color("#1E1E1E"), 0.3))
			for sx in [-1.0, 1.0]:
				cyl(r, 0.055, 0.055, 0.04, Vector3(sx * 0.09, 0.12, 0.3), glass(Color("#FF9A3A"), 1.2), Vector3(PI * 0.5, 0, 0))
			box(r, Vector3(0.06, 0.08, 0.1), Vector3(0, 0.27, 0.17), mat(Color("#2A2A26"), 0.6))
			for sx in [-1.0, 1.0]:
				box(r, Vector3(0.02, 0.1, 0.16), Vector3(sx * 0.28, 0.06, 0.0), mat(Color("#3A4430"), 0.7))
	return r

# ── 조끼 ─────────────────────────────────────────────
## 원점 = 햄스터 몸통 가운데 (실제 크기). 앞이 +Z. 앞판·뒤판·허리띠·어깨끈으로 몸에 맞춘다.
static func vest(tier: int) -> Node3D:
	var r := _root("vest_%d" % tier)
	var main_c: Color = [Color("#B88A55"), Color("#6B7550"), Color("#8B7A55")][clampi(tier - 1, 0, 2)]
	var band_c: Color = [Color("#C9C9C2"), Color("#4A5538"), Color("#2A2C30")][clampi(tier - 1, 0, 2)]
	var m := mat(main_c, 0.9 if tier < 3 else 0.7)
	var band := mat(band_c, 0.8)
	# 허리띠 (몸을 감싸는 띠)
	var ring := cyl(r, 0.355, 0.36, 0.13, Vector3(0, -0.07, 0.0), band, Vector3.ZERO, 20)
	ring.scale = Vector3(1.0, 1.0, 0.86)
	# 앞판 / 뒤판
	box(r, Vector3(0.46, 0.32, 0.06), Vector3(0, 0.0, 0.27), m, Vector3(-0.1, 0, 0))
	box(r, Vector3(0.5, 0.34, 0.06), Vector3(0, 0.0, -0.3), m, Vector3(0.1, 0, 0))
	# 어깨끈
	for sx in [-1.0, 1.0]:
		box(r, Vector3(0.09, 0.05, 0.56), Vector3(sx * 0.17, 0.17, -0.02), band)
	match tier:
		1:
			box(r, Vector3(0.48, 0.06, 0.065), Vector3(0, 0.06, 0.285), mat(Color("#C9C9C2"), 0.5), Vector3(-0.1, 0, 0))
			box(r, Vector3(0.14, 0.11, 0.01), Vector3(-0.1, -0.06, 0.305), mat(Color("#3C6FB5"), 0.8), Vector3(-0.1, 0, 0))
		2:
			for i in 3:
				box(r, Vector3(0.12, 0.13, 0.07), Vector3(-0.14 + i * 0.14, -0.06, 0.32), mat(main_c.darkened(0.2), 0.9))
		_:
			for i in 3:
				box(r, Vector3(0.1, 0.14, 0.08), Vector3(-0.13 + i * 0.13, -0.05, 0.33), mat(Color("#2A2C30"), 0.7))
				box(r, Vector3(0.07, 0.03, 0.02), Vector3(-0.13 + i * 0.13, 0.03, 0.37), mat(Color("#C9A34E"), 0.4, 0.6))
			box(r, Vector3(0.12, 0.04, 0.02), Vector3(0.13, 0.13, 0.305), mat(Color("#D64545"), 0.5))
			box(r, Vector3(0.1, 0.06, 0.02), Vector3(-0.13, 0.13, 0.305), mat(Color("#2A2C30"), 0.6))
	return r

# ── 물약 병 ──────────────────────────────────────────
const POTION_COLOR := {"potion_heal": Color("#FF4F6A"), "potion_big": Color("#FF2E55"), "potion_stamina": Color("#FFD23F"),
	"potion_iron": Color("#9AA8B8"), "potion_swift": Color("#56E39F"), "potion_shadow": Color("#8A5CF6"), "potion_focus": Color("#3FC1FF")}

static func potion(id: String) -> Node3D:
	var r := _root(id)
	var c: Color = POTION_COLOR.get(id, Color("#FF4F6A"))
	var big := id == "potion_big"
	var k := 1.35 if big else 1.0
	sphere(r, 0.115 * k, Vector3(0, 0.12 * k, 0), mat(c, 0.25, 0.0, 0.5), Vector3(1, 0.85, 1))
	sphere(r, 0.13 * k, Vector3(0, 0.13 * k, 0), glass(Color(0.85, 0.95, 1.0), 0.0, 0.18))
	cyl(r, 0.045 * k, 0.05 * k, 0.12 * k, Vector3(0, 0.28 * k, 0), glass(Color(0.85, 0.95, 1.0)))
	cyl(r, 0.05 * k, 0.045 * k, 0.05 * k, Vector3(0, 0.36 * k, 0), mat(Color("#8B5A2B"), 0.9))
	torus(r, 0.04 * k, 0.06 * k, Vector3(0, 0.3 * k, 0), mat(Color("#E8C26A"), 0.4, 0.6))
	return r

# ── 제작 재료 아이콘용 ───────────────────────────────
static func material_item(id: String) -> Node3D:
	var r := _root(id)
	match id:
		"herb":
			var g := mat(Color("#5DB34A"), 0.7)
			for i in 5:
				var a := TAU * i / 5.0
				sphere(r, 0.12, Vector3(cos(a) * 0.12, 0.06 + i * 0.01, sin(a) * 0.12), g, Vector3(1.0, 0.25, 0.55)).rotation.y = -a
			cyl(r, 0.015, 0.015, 0.22, Vector3(0, 0.08, 0.1), mat(Color("#3E7A2E"), 0.8), Vector3(0.9, 0, 0))
		"bottle":
			var gl := glass(Color(0.75, 0.92, 0.85))
			cyl(r, 0.1, 0.1, 0.26, Vector3(0, 0.13, 0), gl)
			cyl(r, 0.04, 0.1, 0.08, Vector3(0, 0.3, 0), gl)
			cyl(r, 0.04, 0.04, 0.08, Vector3(0, 0.37, 0), gl)
		"cloth":
			var c1 := mat(Color("#C85A5A"), 0.95)
			box(r, Vector3(0.44, 0.06, 0.3), Vector3(0, 0.03, 0), c1, Vector3(0, 0.2, 0.08))
			box(r, Vector3(0.4, 0.06, 0.28), Vector3(0.03, 0.09, 0.02), mat(Color("#E8E2D0"), 0.95), Vector3(0, -0.25, -0.06))
		"metal_sheet":
			var st := mat(Color("#9AA3AD"), 0.35, 0.85)
			box(r, Vector3(0.6, 0.03, 0.32), Vector3(0, 0.02, 0), st, Vector3(0, 0.15, 0.05))
			for i in 4:
				cyl(r, 0.018, 0.018, 0.012, Vector3(-0.25 + (i % 2) * 0.5, 0.045, -0.12 + (i / 2) * 0.24), mat(Color("#6E767F"), 0.4, 0.8))
		"gunpowder":
			var bag := mat(Color("#8C7A5B"), 0.95)
			sphere(r, 0.17, Vector3(0, 0.15, 0), bag, Vector3(1, 0.95, 0.85))
			cyl(r, 0.05, 0.09, 0.08, Vector3(0, 0.32, 0), bag)
			torus(r, 0.04, 0.065, Vector3(0, 0.3, 0), mat(Color("#C23B22"), 0.7))
			box(r, Vector3(0.12, 0.1, 0.01), Vector3(0, 0.15, 0.15), mat(Color("#1E1E1E"), 0.6))
		"lens":
			torus(r, 0.13, 0.17, Vector3(0, 0.15, 0), mat(Color("#2B2B2E"), 0.4, 0.6), Vector3(PI * 0.5, 0, 0))
			cyl(r, 0.135, 0.135, 0.03, Vector3(0, 0.15, 0), glass(Color("#9FD8FF"), 0.3), Vector3(PI * 0.5, 0, 0))
	return r

# ── 총 부품 ──────────────────────────────────────────
## 원점 = 부품이 붙는 자리. 총의 앞 = +Z, 위 = +Y.
static func attachment(att: String) -> Node3D:
	var r := _root(att)
	var blk := mat(Color("#1E2024"), 0.45, 0.4)
	var gry := mat(Color("#3A3E45"), 0.5, 0.5)
	match att:
		"red_dot":
			box(r, Vector3(0.05, 0.03, 0.08), Vector3(0, 0.015, 0), blk)
			torus(r, 0.025, 0.035, Vector3(0, 0.055, 0.0), blk, Vector3(PI * 0.5, 0, 0))
			sphere(r, 0.006, Vector3(0, 0.055, 0.0), mat(Color("#FF2020"), 0.2, 0.0, 4.0))
		"holo":
			box(r, Vector3(0.06, 0.02, 0.1), Vector3(0, 0.01, 0), blk)
			box(r, Vector3(0.008, 0.06, 0.008), Vector3(-0.03, 0.05, 0.04), blk)
			box(r, Vector3(0.008, 0.06, 0.008), Vector3(0.03, 0.05, 0.04), blk)
			box(r, Vector3(0.068, 0.008, 0.01), Vector3(0, 0.08, 0.04), blk)
			box(r, Vector3(0.05, 0.045, 0.004), Vector3(0, 0.052, 0.04), glass(Color("#7FD7FF"), 0.6))
		"scope_4x":
			cyl(r, 0.032, 0.032, 0.24, Vector3(0, 0.07, 0), blk, Vector3(PI * 0.5, 0, 0))
			cyl(r, 0.045, 0.034, 0.06, Vector3(0, 0.07, 0.13), blk, Vector3(PI * 0.5, 0, 0))
			cyl(r, 0.04, 0.034, 0.05, Vector3(0, 0.07, -0.12), blk, Vector3(PI * 0.5, 0, 0))
			cyl(r, 0.036, 0.036, 0.004, Vector3(0, 0.07, 0.161), glass(Color("#6FB8FF"), 0.5), Vector3(PI * 0.5, 0, 0))
			box(r, Vector3(0.025, 0.05, 0.03), Vector3(0, 0.025, 0.06), gry)
			box(r, Vector3(0.025, 0.05, 0.03), Vector3(0, 0.025, -0.06), gry)
			cyl(r, 0.012, 0.012, 0.03, Vector3(0, 0.11, 0.0), gry)
		"suppressor":
			cyl(r, 0.032, 0.032, 0.22, Vector3(0, 0, 0.11), blk, Vector3(PI * 0.5, 0, 0))
			cyl(r, 0.026, 0.026, 0.006, Vector3(0, 0, 0.222), gry, Vector3(PI * 0.5, 0, 0))
		"compensator":
			cyl(r, 0.026, 0.026, 0.07, Vector3(0, 0, 0.035), gry, Vector3(PI * 0.5, 0, 0), 8)
			for i in 3:
				box(r, Vector3(0.06, 0.008, 0.01), Vector3(0, 0.02, 0.015 + i * 0.02), blk)
		"choke":
			cyl(r, 0.034, 0.028, 0.06, Vector3(0, 0, 0.03), mat(Color("#8E7A4E"), 0.35, 0.8), Vector3(PI * 0.5, 0, 0))
		"ext_mag":
			box(r, Vector3(0.04, 0.2, 0.06), Vector3(0, -0.1, 0), gry, Vector3(0.18, 0, 0))
			box(r, Vector3(0.044, 0.02, 0.064), Vector3(0, -0.2, -0.02), blk, Vector3(0.18, 0, 0))
		"quick_mag":
			box(r, Vector3(0.04, 0.13, 0.055), Vector3(0, -0.065, 0), gry, Vector3(0.12, 0, 0))
			box(r, Vector3(0.046, 0.03, 0.06), Vector3(0, -0.06, 0), mat(Color("#C9C9C2"), 0.5), Vector3(0.12, 0, 0))
			torus(r, 0.008, 0.02, Vector3(0, -0.14, -0.012), mat(Color("#D64545"), 0.6))
		"drum_mag":
			cyl(r, 0.09, 0.09, 0.06, Vector3(0, -0.1, 0), gry, Vector3(0, 0, PI * 0.5))
			cyl(r, 0.03, 0.03, 0.07, Vector3(0, -0.1, 0), blk, Vector3(0, 0, PI * 0.5))
			box(r, Vector3(0.035, 0.05, 0.04), Vector3(0, -0.02, 0), blk)
		"foregrip":
			cyl(r, 0.018, 0.022, 0.1, Vector3(0, -0.06, 0), blk)
			box(r, Vector3(0.03, 0.015, 0.05), Vector3(0, -0.008, 0), gry)
		"laser":
			box(r, Vector3(0.035, 0.03, 0.06), Vector3(0, -0.02, 0), blk)
			cyl(r, 0.008, 0.008, 0.01, Vector3(0, -0.02, 0.032), mat(Color("#FF2020"), 0.2, 0.0, 5.0), Vector3(PI * 0.5, 0, 0))
		"stock":
			box(r, Vector3(0.05, 0.1, 0.04), Vector3(0, -0.02, -0.02), mat(Color("#3B2A20"), 0.9))
		"bow_string":
			torus(r, 0.05, 0.06, Vector3(0, 0, 0), mat(Color("#E8D9A0"), 0.6), Vector3(PI * 0.5, 0, 0))
			torus(r, 0.03, 0.04, Vector3(0, 0, 0), mat(Color("#C9A34E"), 0.4, 0.6), Vector3(PI * 0.5, 0, 0))
	return r

## 무기 모델(앞 +Z, 손잡이 원점)에 부품을 붙인다. len = 총 길이(원점→총구)
static func attach_mods(gun: Node3D, wid: String, mods: Dictionary) -> void:
	if gun == null or mods.is_empty():
		return
	var aabb := _aabb(gun)
	var front := aabb.end.z
	var top := aabb.end.y
	var bottom := aabb.position.y
	var zc := (aabb.position.z + front) * 0.5
	for slot in mods:
		var att := str(mods[slot])
		if not DB.att_fits(att, wid):
			continue
		var p := attachment(att)
		var s := maxf(0.6, minf(1.6, (front - aabb.position.z) / 0.7))
		p.scale = Vector3.ONE * s
		match slot:
			"optic": p.position = Vector3(0, top - 0.01, zc + (front - zc) * 0.05)
			"muzzle": p.position = Vector3(0, top * 0.35 + bottom * 0.15, front - 0.01)
			"mag": p.position = Vector3(0, bottom * 0.3, zc + (front - zc) * 0.15)
			"grip": p.position = Vector3(0, bottom * 0.4, zc + (front - zc) * 0.6)
			"stock": p.position = Vector3(0, top * 0.2, aabb.position.z + 0.03)
		if DB.family(wid) == "bow" and slot == "stock":
			p.position = Vector3(0, top * 0.5, zc + (front - zc) * 0.5)
		gun.add_child(p)

static func _aabb(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var xf := _rel_xf(n, m)
		var a := xf * m.mesh.get_aabb()
		if first:
			out = a
			first = false
		else:
			out = out.merge(a)
	return out

static func _rel_xf(root: Node3D, n: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur and cur != root:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf

# ── 제작소 ───────────────────────────────────────────
## 물약 제작소: 작업대 + 끓는 솥 + 병 선반 + 매달린 약초 + 초록 불빛
static func potion_lab() -> Node3D:
	var r := _root("potion_lab")
	var wood := mat(Color("#7A5233"), 0.85)
	var wood_d := mat(Color("#5B3B24"), 0.85)
	# 작업대
	box(r, Vector3(1.5, 0.08, 0.7), Vector3(0, 0.72, 0), wood)
	for sx in [-0.68, 0.68]:
		for sz in [-0.28, 0.28]:
			box(r, Vector3(0.08, 0.72, 0.08), Vector3(sx, 0.36, sz), wood_d)
	# 병들
	for i in 5:
		var p := potion(POTION_COLOR.keys()[i])
		p.position = Vector3(-0.55 + i * 0.22, 0.76, -0.1 + (i % 2) * 0.16)
		p.scale = Vector3.ONE * 0.7
		r.add_child(p)
	# 절구
	cyl(r, 0.1, 0.07, 0.1, Vector3(0.5, 0.81, 0.15), mat(Color("#9C9A92"), 0.8))
	cyl(r, 0.015, 0.02, 0.2, Vector3(0.53, 0.9, 0.15), wood_d, Vector3(0, 0, 0.5))
	# 솥 (옆)
	var pot := mat(Color("#2C2C30"), 0.5, 0.6)
	sphere(r, 0.36, Vector3(1.15, 0.36, 0.1), pot, Vector3(1, 0.85, 1))
	cyl(r, 0.31, 0.31, 0.04, Vector3(1.15, 0.62, 0.1), mat(Color("#5CFF8A"), 0.3, 0.0, 2.2))
	torus(r, 0.29, 0.34, Vector3(1.15, 0.62, 0.1), pot)
	for k in 3:
		var a := TAU * k / 3.0
		box(r, Vector3(0.05, 0.2, 0.05), Vector3(1.15 + cos(a) * 0.24, 0.06, 0.1 + sin(a) * 0.24), pot)
	# 장작불
	for k in 3:
		cyl(r, 0.04, 0.04, 0.4, Vector3(1.15, 0.05, 0.1), wood_d, Vector3(PI * 0.5, TAU * k / 3.0, 0))
	sphere(r, 0.12, Vector3(1.15, 0.09, 0.1), mat(Color("#FF8A2A"), 0.4, 0.0, 3.0), Vector3(1, 0.6, 1))
	var gl := OmniLight3D.new()
	gl.light_color = Color("#7CFF9C")
	gl.light_energy = 1.6
	gl.omni_range = 2.6
	gl.position = Vector3(1.15, 0.9, 0.1)
	r.add_child(gl)
	# 벽 선반 + 병
	box(r, Vector3(1.4, 0.05, 0.25), Vector3(0, 1.55, -0.3), wood)
	for i in 6:
		var p2 := potion(POTION_COLOR.keys()[(i + 2) % POTION_COLOR.size()])
		p2.position = Vector3(-0.6 + i * 0.24, 1.58, -0.3)
		p2.scale = Vector3.ONE * 0.6
		r.add_child(p2)
	# 매달린 약초
	for i in 4:
		var hx := -0.5 + i * 0.33
		cyl(r, 0.006, 0.006, 0.25, Vector3(hx, 1.95, -0.25), mat(Color("#8B7355"), 0.9))
		sphere(r, 0.09, Vector3(hx, 1.8, -0.25), mat(Color("#6BAF4A"), 0.8), Vector3(0.8, 1.4, 0.8))
	box(r, Vector3(1.4, 0.04, 0.04), Vector3(0, 2.08, -0.25), wood_d)
	return r

## 갑옷 제작소: 모루 + 화덕(불빛) + 갑옷 거치대 + 망치
static func armor_forge() -> Node3D:
	var r := _root("armor_forge")
	var iron := mat(Color("#3A3D44"), 0.45, 0.8)
	var brick := mat(Color("#8A4B36"), 0.9)
	var brick_d := mat(Color("#5E3022"), 0.9)
	var wood := mat(Color("#6B4A2E"), 0.85)
	# 모루
	box(r, Vector3(0.3, 0.42, 0.3), Vector3(-0.5, 0.21, 0.2), wood)
	box(r, Vector3(0.5, 0.12, 0.22), Vector3(-0.5, 0.48, 0.2), iron)
	cyl(r, 0.0, 0.11, 0.24, Vector3(-0.15, 0.49, 0.2), iron, Vector3(0, 0, -PI * 0.5), 8)
	box(r, Vector3(0.2, 0.08, 0.16), Vector3(-0.5, 0.38, 0.2), iron)
	# 망치
	cyl(r, 0.018, 0.018, 0.36, Vector3(-0.55, 0.6, 0.2), wood, Vector3(0, 0.3, PI * 0.5 - 0.15))
	box(r, Vector3(0.07, 0.07, 0.13), Vector3(-0.72, 0.62, 0.15), iron, Vector3(0, 0.3, 0))
	# 화덕
	box(r, Vector3(0.9, 0.7, 0.7), Vector3(0.55, 0.35, -0.1), brick)
	box(r, Vector3(0.5, 0.32, 0.05), Vector3(0.55, 0.42, 0.26), brick_d)
	box(r, Vector3(0.4, 0.22, 0.06), Vector3(0.55, 0.42, 0.27), mat(Color("#FF7A1A"), 0.4, 0.0, 4.0))
	cyl(r, 0.16, 0.22, 1.2, Vector3(0.55, 1.3, -0.15), brick_d)
	for k in 5:
		box(r, Vector3(0.92, 0.02, 0.72), Vector3(0.55, 0.12 + k * 0.14, -0.1), brick_d)
	var fl := OmniLight3D.new()
	fl.light_color = Color("#FF8A3A")
	fl.light_energy = 2.2
	fl.omni_range = 3.0
	fl.position = Vector3(0.55, 0.6, 0.6)
	r.add_child(fl)
	r.set_meta("fire_light", fl)
	# 갑옷 거치대 (마네킹)
	var stand := Node3D.new()
	stand.position = Vector3(-1.25, 0, -0.1)
	r.add_child(stand)
	cyl(stand, 0.2, 0.24, 0.05, Vector3(0, 0.025, 0), wood)
	cyl(stand, 0.03, 0.03, 0.75, Vector3(0, 0.4, 0), wood)
	var v := vest(3)
	v.position = Vector3(0, 0.75, 0)
	stand.add_child(v)
	capsule(stand, 0.3, 0.6, Vector3(0, 0.75, 0), wood, Vector3.ZERO, Vector3(1.05, 1, 0.85))
	var h := helmet(3)
	h.position = Vector3(0, 1.08, 0)
	h.scale = Vector3.ONE * 0.85
	stand.add_child(h)
	sphere(stand, 0.17, Vector3(0, 1.07, 0), wood)
	return r

## 무기 제작소 총 거치대: 진짜 무기 모델을 세워 둔다 (기존 나무 거치대 앞)
static func weapon_wall(ids: Array) -> Node3D:
	var r := _root("weapon_wall")
	var i := 0
	var n := ids.size()
	for wid in ids:
		var w := EnemyModel.weapon_scene(str(wid))
		if w == null:
			continue
		var hold := Node3D.new()
		hold.position = Vector3(-0.3 * (n - 1) * 0.5 + i * 0.3, 0.3, 0.0)
		hold.scale = Vector3.ONE * 1.25
		hold.rotation = Vector3(-PI * 0.5 + 0.08, 0, 0)     # 총구가 위로
		r.add_child(hold)
		hold.add_child(w)
		i += 1
	box(r, Vector3(0.3 * n + 0.1, 0.06, 0.16), Vector3(0, 0.03, 0), mat(Color("#5B3B24"), 0.85))
	box(r, Vector3(0.3 * n + 0.1, 0.05, 0.08), Vector3(0, 0.95, -0.06), mat(Color("#5B3B24"), 0.85))
	return r

# ── 셔터 (원정 지도, 세로 3칸) ────────────────────────
static func shutter_door(width: float, height: float) -> Node3D:
	var r := _root("shutter")
	var frame := mat(Color("#4C586B"), 0.5, 0.6)
	box(r, Vector3(0.18, height, 0.22), Vector3(0, height * 0.5, -width * 0.5), frame)
	box(r, Vector3(0.18, height, 0.22), Vector3(0, height * 0.5, width * 0.5), frame)
	box(r, Vector3(0.3, 0.3, width + 0.2), Vector3(0, height + 0.1, 0), frame)
	var panel := Node3D.new()
	panel.name = "panel"
	r.add_child(panel)
	var slat := mat(Color("#8D96A3"), 0.45, 0.7)
	var slat_d := mat(Color("#6F7884"), 0.45, 0.7)
	var n := int(height / 0.16)
	for k in n:
		box(panel, Vector3(0.06, 0.15, width - 0.1), Vector3(0, 0.08 + k * 0.16, 0), slat if k % 2 == 0 else slat_d)
	box(panel, Vector3(0.09, 0.12, width - 0.08), Vector3(0, 0.06, 0), mat(Color("#F2C14E"), 0.5))
	# 경고 줄무늬
	for k in 6:
		box(panel, Vector3(0.1, 0.05, 0.22), Vector3(0, 0.06, -width * 0.5 + 0.3 + k * (width - 0.6) / 5.0), mat(Color("#1B1A22"), 0.6), Vector3(0.6, 0, 0))
	return r

# ── 탈출구 표식 ──────────────────────────────────────
static func light_beam(c: Color, h: float = 6.0, rad: float = 0.5) -> Node3D:
	var r := _root("beam")
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(c, 0.22)
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	gt.gradient = g
	gt.fill_from = Vector2(0, 1)
	gt.fill_to = Vector2(0, 0)
	m.albedo_texture = gt
	var c1 := cyl(r, rad * 0.7, rad, h, Vector3(0, h * 0.5, 0), m, Vector3.ZERO, 20)
	c1.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m2 := m.duplicate() as StandardMaterial3D
	m2.albedo_color = Color(c, 0.35)
	var c2 := cyl(r, rad * 0.25, rad * 0.35, h * 0.8, Vector3(0, h * 0.4, 0), m2, Vector3.ZERO, 12)
	c2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return r

static func manhole() -> Node3D:
	var r := _root("manhole")
	var iron := mat(Color("#3E434C"), 0.6, 0.7)
	cyl(r, 0.62, 0.66, 0.06, Vector3(0, 0.03, 0), mat(Color("#2A2E35"), 0.8))
	var lid := cyl(r, 0.55, 0.55, 0.05, Vector3(0.0, 0.07, 0.0), iron)
	lid.name = "lid"
	for k in 4:
		box(r, Vector3(0.8, 0.012, 0.05), Vector3(0, 0.1, -0.24 + k * 0.16), mat(Color("#2A2E35"), 0.6, 0.6))
	# 구멍 (어둠)
	cyl(r, 0.5, 0.5, 0.02, Vector3(0, 0.02, 0), mat(Color("#050608"), 1.0))
	# 신호탄
	var flare := Node3D.new()
	flare.name = "flare"
	flare.position = Vector3(0.9, 0, -0.5)
	r.add_child(flare)
	cyl(flare, 0.04, 0.04, 0.3, Vector3(0, 0.15, 0), mat(Color("#C23B22"), 0.6), Vector3(0.2, 0, 0.1))
	sphere(flare, 0.06, Vector3(0.015, 0.31, 0.03), mat(Color("#7CFF8A"), 0.2, 0.0, 6.0))
	var ol := OmniLight3D.new()
	ol.light_color = Color("#7CFF8A")
	ol.light_energy = 2.5
	ol.omni_range = 4.0
	ol.position = Vector3(0, 0.6, 0)
	flare.add_child(ol)
	return r

## 하역장 탈출 트럭 (택배 트럭)
static func truck() -> Node3D:
	var r := _root("truck")
	var white := mat(Color("#D8DEE6"), 0.5, 0.1)
	var blue := mat(Color("#3E5C8A"), 0.45, 0.2)
	var tire := mat(Color("#1C1C1F"), 0.9)
	var glass_m := glass(Color("#8FB3C9"), 0.2)
	# 짐칸 (뒤가 -Z) / 운전석 (+Z)
	box(r, Vector3(1.7, 1.5, 2.6), Vector3(0, 1.15, -0.5), white)
	box(r, Vector3(1.6, 1.0, 1.0), Vector3(0, 0.85, 1.35), blue)
	box(r, Vector3(1.4, 0.45, 0.06), Vector3(0, 1.1, 1.86), glass_m)
	box(r, Vector3(1.7, 0.12, 3.8), Vector3(0, 0.38, 0.1), mat(Color("#2B2F36"), 0.7, 0.4))
	for sx in [-0.78, 0.78]:
		for sz in [-1.3, 1.25]:
			cyl(r, 0.3, 0.3, 0.22, Vector3(sx, 0.3, sz), tire, Vector3(0, 0, PI * 0.5))
	# 열린 뒷문 + 경사판
	box(r, Vector3(0.06, 1.4, 0.8), Vector3(-0.86, 1.15, -2.15), white, Vector3(0, -1.2, 0))
	box(r, Vector3(1.2, 0.05, 1.1), Vector3(0, 0.25, -2.3), mat(Color("#6E767F"), 0.5, 0.7), Vector3(0.38, 0, 0))
	box(r, Vector3(1.5, 1.3, 0.04), Vector3(0, 1.15, -1.79), mat(Color("#141418"), 1.0))
	var l := Label3D.new()
	l.text = "멍냥택배"
	l.font = FX.font()
	l.font_size = 64
	l.outline_size = 12
	l.modulate = Color("#F2994A")
	l.pixel_size = 0.006
	l.position = Vector3(0.87, 1.3, -0.5)
	l.rotation.y = PI * 0.5
	r.add_child(l)
	for sx in [-0.5, 0.5]:
		sphere(r, 0.08, Vector3(sx, 0.75, 1.86), mat(Color("#FFF2C0"), 0.2, 0.0, 3.0))
	return r

# ── 항구 소품 ────────────────────────────────────────
const CONTAINER_COLORS := [Color("#B8452F"), Color("#2F6FA8"), Color("#3E8A55"), Color("#C9902F")]

static func proc_prop(n: String) -> Node3D:
	if n.begins_with("container"):
		var i := int(n.get_slice("_", 1)) if n.contains("_") else 0
		return shipping_container(CONTAINER_COLORS[i % CONTAINER_COLORS.size()])
	if n == "boat":
		return boat()
	return backpack()

## 선적 컨테이너 (가로 2칸, 원점 = 바닥 가운데). 골판 무늬 + 문짝 손잡이
static func shipping_container(c: Color) -> Node3D:
	var r := _root("container")
	var body := mat(c, 0.6, 0.35)
	var dark := mat(c.darkened(0.3), 0.6, 0.35)
	var L := 1.96
	var D := 0.92
	var Hh := 1.25
	box(r, Vector3(L, Hh, D), Vector3(0, Hh * 0.5, 0), body)
	# 골판 (세로 홈)
	var n := 14
	for k in n:
		var x := -L * 0.5 + 0.07 + k * (L - 0.14) / float(n - 1)
		box(r, Vector3(0.04, Hh - 0.12, D + 0.03), Vector3(x, Hh * 0.5, 0), dark)
	# 위·아래 테두리
	box(r, Vector3(L + 0.04, 0.07, D + 0.05), Vector3(0, Hh - 0.03, 0), dark)
	box(r, Vector3(L + 0.04, 0.07, D + 0.05), Vector3(0, 0.035, 0), dark)
	# 문짝 쪽 손잡이 (앞쪽이 +Z 인 면 오른쪽 끝)
	for k in 4:
		box(r, Vector3(0.025, Hh - 0.2, 0.025), Vector3(L * 0.5 - 0.06 - k * 0.12, Hh * 0.5, D * 0.5 + 0.03), mat(Color("#2A2C30"), 0.4, 0.8))
	# 글씨 (회사 이름)
	var l := Label3D.new()
	l.text = ["MEOW LINE", "NYANG SHIP", "PAW CARGO", "TUNA EXP"][CONTAINER_COLORS.find(c) % 4]
	l.font = FX.font()
	l.font_size = 48
	l.outline_size = 0
	l.modulate = Color(1, 1, 1, 0.85)
	l.pixel_size = 0.004
	l.position = Vector3(-0.2, Hh * 0.62, D * 0.5 + 0.03)
	r.add_child(l)
	return r

## 선착장 탈출 보트
static func boat() -> Node3D:
	var r := _root("boat")
	var hull := mat(Color("#E8E2D0"), 0.5)
	var stripe := mat(Color("#D64545"), 0.5)
	var wood := mat(Color("#8B5A2B"), 0.85)
	capsule(r, 0.55, 2.6, Vector3(0, 0.25, 0), hull, Vector3(PI * 0.5, 0, 0), Vector3(1.0, 1.0, 0.55))
	box(r, Vector3(1.05, 0.12, 2.3), Vector3(0, 0.5, 0), wood)
	capsule(r, 0.57, 2.65, Vector3(0, 0.38, 0), stripe, Vector3(PI * 0.5, 0, 0), Vector3(1.0, 1.0, 0.12))
	box(r, Vector3(0.7, 0.55, 0.6), Vector3(0, 0.82, -0.45), mat(Color("#3E5C8A"), 0.5))
	box(r, Vector3(0.6, 0.25, 0.04), Vector3(0, 0.95, -0.14), glass(Color("#8FB3C9"), 0.2))
	cyl(r, 0.12, 0.12, 0.4, Vector3(0, 0.45, -1.35), mat(Color("#2A2C30"), 0.5, 0.6))
	var fl := OmniLight3D.new()
	fl.light_color = Color("#7CFF8A")
	fl.light_energy = 2.0
	fl.omni_range = 4.0
	fl.position = Vector3(0, 1.4, 0)
	r.add_child(fl)
	return r

## 바다: 반짝이는 물결 면 (셰이더)
static func water_plane(size: Vector2) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	pm.subdivide_width = 1
	pm.subdivide_depth = 1
	mi.mesh = pm
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode blend_mix, specular_schlick_ggx, cull_disabled;
uniform vec4 deep : source_color = vec4(0.07, 0.22, 0.34, 0.92);
uniform vec4 shallow : source_color = vec4(0.16, 0.45, 0.55, 0.9);
float h(vec2 p){ return sin(p.x*1.7+TIME*1.3)*0.5+sin(p.y*2.3-TIME*1.1)*0.5+sin((p.x+p.y)*3.1+TIME*2.0)*0.25; }
void fragment(){
	vec2 p = (INV_VIEW_MATRIX * vec4(VERTEX,1.0)).xz;
	float w = h(p);
	float e = 0.08;
	vec3 n = normalize(vec3(h(p+vec2(e,0.0))-w, 4.0, h(p+vec2(0.0,e))-w));
	NORMAL = (VIEW_MATRIX * vec4(n,0.0)).xyz;
	vec3 c = mix(deep.rgb, shallow.rgb, 0.5+0.25*w);
	float sparkle = pow(max(0.0, sin(p.x*7.0+TIME*3.0)*sin(p.y*6.0-TIME*2.5)), 24.0);
	ALBEDO = c + vec3(sparkle*0.6);
	ROUGHNESS = 0.08;
	METALLIC = 0.1;
	SPECULAR = 0.7;
	ALPHA = deep.a;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
