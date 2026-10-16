class_name View3D
extends Node3D
## 레이드 3D 화면.
## 게임 로직(이동·충돌·AI·전투)은 기존 2D 그대로 돌고, 이 노드가 그 상태를 3D로 그린다.
##  - 바닥: 블렌더에서 위에서 렌더한 floor.png / 벽: LevelData로 만든 3D 벽
##  - 캐릭터: 블렌더 3D 모델(Char3D)을 부위별로 절차 애니메이션
##  - 소품: 블렌더 3D 모델(GLB)
##  - 총알·링·발자국 같은 2D 효과는 서브뷰포트로 그려 바닥에 투영한다
##  - 원근 카메라 (덕코프식 비스듬한 시점)

const T := float(DB.TILE)
const PITCH := 49.0         # 카메라 내려다보는 각도
const CAM_DIST := 16.0
var cam_dist := CAM_DIST   # 테스트·연출용으로 바꿀 수 있음
var _aim_dist := CAM_DIST
const FOV := 34.0
const WALL_H := 2.6         # 벽 높이 (타일 단위) — 햄스터보다 훨씬 높은 인간 세계
const GLASS_LOW := 0.32
const L_OVERLAY := 1 << 1   # 바닥 투영으로 보일 2D (효과·표시)
const L_HIDDEN := 1 << 2    # 3D 모델로 대체된 2D 그림 (어디에도 안 그림)
const OV_TILES := 40.0      # 바닥 투영 범위 (타일)
const OV_PX := 2048
const AIM_H := 0.5          # 조준 평면 높이 (타일) — 화면에서 적 몸통을 가리키면 그 적을 노리게

var raid: Raid
var cam: Camera3D
var wall_mats: Array[ShaderMaterial] = []
var old_mask := 0xFFFFFFFF
var ov_vp: SubViewport
var ov_cam: Camera2D
var ov_quad: MeshInstance3D
var cam_target := Vector3.ZERO
var registered := {}
var look_t := Vector3.ZERO
var tracers := {}           # Projectile -> MeshInstance3D
var _pp0 := Vector2.ZERO
var _pp1 := Vector2.ZERO
var env: Environment
var shutter3d: Node3D
var shutter_panel: Node3D
var exit3d := {}            # ExitZone -> {root, beam, ...}
var player_model: Node3D
var extracting := false

func build(r: Raid) -> void:
	raid = r
	_env()
	_floor()
	_walls()
	_lights()
	cam = Camera3D.new()
	cam.fov = FOV
	cam.near = 1.0
	cam.far = 120.0
	cam.current = true
	add_child(cam)
	_overlay()
	old_mask = get_viewport().canvas_cull_mask
	get_viewport().canvas_cull_mask = 1
	for root in [raid.world, raid.fx_layer]:
		for n in _all_children(root):
			_classify(n)
	for c in raid.get_children():
		if c is ExitZone or c is Shutter:
			c.visibility_layer = L_OVERLAY
			for n in _all_children(c):
				if n is CanvasItem:
					n.visibility_layer = L_OVERLAY
	get_tree().node_added.connect(_on_node_added)
	_build_gates()
	_warmup()
	var fx3 := FX3D.new()
	add_child(fx3)
	FX.fx3d = fx3
	FX.NO_CORPSE = EnemyModel.available("hyena") and EnemyModel.available("bulldog") and EnemyModel.available("cat")
	if raid.player:
		var p := raid.player.global_position
		cam_target = Vector3(p.x / T, 0, p.y / T)

func _enter_tree() -> void:
	process_physics_priority = 100

func _physics_process(_d: float) -> void:
	if raid and raid.player:
		_pp0 = _pp1 if _pp1 != Vector2.ZERO else raid.player.global_position
		_pp1 = raid.player.global_position

func _player_smooth() -> Vector2:
	if _pp1 == Vector2.ZERO or _pp0.distance_squared_to(_pp1) > 140.0 * 140.0:
		return raid.player.global_position
	return _pp0.lerp(_pp1, Engine.get_physics_interpolation_fraction())

## 셰이더 미리 굽기: 시작 직후 어두운 화면 뒤에서 모든 모델·빛줄기를 한 번씩 그려
## 첫 몇 초의 끊김(셰이더 컴파일)을 없앤다
func _warmup() -> void:
	var w := Node3D.new()
	add_child(w)
	var paths := []
	var d := DirAccess.open("res://assets/models/props")
	if d:
		for f in d.get_files():
			if f.ends_with(".glb"):
				paths.append("res://assets/models/props/" + f)
	var i := 0
	for p in paths:
		var m := (load(p) as PackedScene).instantiate() as Node3D
		m.scale = Vector3.ONE * 0.3
		m.position = Vector3((i % 8) * 0.5 - 2.0, 0, (i / 8) * 0.5 - 1.0)
		w.add_child(m)
		i += 1
	if ModelChar.available():
		w.add_child(ModelChar.load_model(true))
	for tp in ["hyena", "bulldog", "cat"]:
		if EnemyModel.available(tp):
			w.add_child(EnemyModel.load_model(tp, true))
	var tr := MeshInstance3D.new()
	tr.mesh = BoxMesh.new()
	tr.material_override = _tracer_mat(Color(1.0, 0.86, 0.5))
	w.add_child(tr)
	var fl := OmniLight3D.new()
	fl.omni_range = 2.0
	w.add_child(fl)
	var p0 := raid.player.global_position if raid.player else Vector2.ZERO
	w.position = Vector3(p0.x / T, 0, p0.y / T)
	get_tree().create_timer(1.1).timeout.connect(w.queue_free)

func _exit_tree() -> void:
	FX.NO_CORPSE = false
	FX.fx3d = null
	if get_viewport():
		get_viewport().canvas_cull_mask = old_mask
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)

# ── 환경·조명 ────────────────────────────────────────
func _env() -> void:
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#1A2030")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.72, 0.78, 0.95)
	e.ambient_light_energy = 0.72
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = 1.0
	e.tonemap_white = 6.0
	e.ssao_enabled = true
	e.ssao_radius = 1.2
	e.ssao_intensity = 1.8
	e.ssil_enabled = true
	e.ssil_intensity = 0.6
	e.glow_enabled = true
	e.glow_intensity = 0.4
	e.glow_bloom = 0.04
	e.glow_hdr_threshold = 1.1
	e.adjustment_enabled = true
	e.adjustment_saturation = 1.12
	e.adjustment_contrast = 1.04
	we.environment = e
	add_child(we)
	env = e
	var moon := DirectionalLight3D.new()
	# 늦은 오후의 따뜻한 해 (부드러운 그림자)
	moon.light_color = Color(1.0, 0.86, 0.68)
	moon.light_energy = 1.25
	moon.shadow_enabled = true
	moon.shadow_blur = 2.5
	moon.directional_shadow_max_distance = 45.0
	moon.rotation_degrees = Vector3(-48, -38, 0)
	add_child(moon)
	Settings.apply_env(e, moon)

func _lights() -> void:
	# [타일 위치, 색, 반경(타일), 세기]
	var L: Array = Regions.cur().lights
	for l in L:
		var o := OmniLight3D.new()
		var p: Vector2 = l[0]
		o.position = Vector3(p.x, 2.1, p.y)
		o.light_color = Color(str(l[1]))
		o.omni_range = float(l[2])
		o.light_energy = float(l[3])
		o.omni_attenuation = 1.4
		add_child(o)

# ── 바닥 ─────────────────────────────────────────────
func _floor() -> void:
	var W := float(LevelData.width())
	var H := float(LevelData.height())
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(W, H)
	mi.mesh = pm
	mi.position = Vector3(W * 0.5, 0.0, H * 0.5)
	var m := StandardMaterial3D.new()
	var fp: String = Regions.cur().floor
	if ResourceLoader.exists(fp):
		m.albedo_texture = load(fp)
	else:
		m.albedo_color = Color("#3A3F48")
	m.albedo_color = Color(0.92, 0.9, 0.88)
	m.roughness = 0.9
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_water()

## 바다 칸(~): 가로로 이어진 칸마다 물결 면
func _water() -> void:
	for y in LevelData.height():
		var x := 0
		while x < LevelData.width():
			if LevelData.code(x, y) == "~":
				var x0 := x
				while x < LevelData.width() and LevelData.code(x, y) == "~":
					x += 1
				var wp := ProcModels.water_plane(Vector2(x - x0, 1.0), LevelData.region == "town")
				wp.position = Vector3((x0 + x) * 0.5, 0.012, y + 0.5)
				add_child(wp)
			else:
				x += 1
	if LevelData.region == "town":
		_pond_dress()

## 공원 연못: 연잎·연꽃, 물가 갈대와 돌
func _pond_dress() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7331
	var pad := ProcModels.mat(Color("#4E9A4A"), 0.7)
	var pad2 := ProcModels.mat(Color("#6DB65A"), 0.7)
	var flower := ProcModels.mat(Color("#FFB3CF"), 0.5)
	var reed := ProcModels.mat(Color("#7FA650"), 0.8)
	var stone := ProcModels.mat(Color("#6F6B63"), 0.95)
	for y in LevelData.height():
		for x in LevelData.width():
			if LevelData.code(x, y) != "~":
				continue
			var shore := false
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if LevelData.code(x + d.x, y + d.y) != "~":
					shore = true
			if shore:
				# 물가: 돌 1~2개 + 갈대 한 무더기
				for i in rng.randi_range(0, 1):
					var s := MeshInstance3D.new()
					var sm := SphereMesh.new()
					var r := rng.randf_range(0.12, 0.22)
					sm.radius = r
					sm.height = r * 1.1
					s.mesh = sm
					s.material_override = stone
					s.position = Vector3(x + rng.randf_range(0.1, 0.9), 0.0, y + rng.randf_range(0.1, 0.9))
					s.rotation.y = rng.randf() * TAU
					s.scale = Vector3(1.3, 1.0, 1.0)
					add_child(s)
				if rng.randf() < 0.45:
					var cx := x + rng.randf_range(0.2, 0.8)
					var cz := y + rng.randf_range(0.2, 0.8)
					for i in 6:
						var c := MeshInstance3D.new()
						var cm := CylinderMesh.new()
						var h := rng.randf_range(0.35, 0.7)
						cm.top_radius = 0.008
						cm.bottom_radius = 0.02
						cm.height = h
						cm.radial_segments = 5
						c.mesh = cm
						c.material_override = reed
						c.position = Vector3(cx + rng.randf_range(-0.12, 0.12), h * 0.5, cz + rng.randf_range(-0.12, 0.12))
						c.rotation = Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2))
						add_child(c)
			elif rng.randf() < 0.22:
				var p := MeshInstance3D.new()
				var pm := CylinderMesh.new()
				var pr := rng.randf_range(0.14, 0.26)
				pm.top_radius = pr
				pm.bottom_radius = pr
				pm.height = 0.01
				pm.radial_segments = 14
				p.mesh = pm
				p.material_override = pad if rng.randf() < 0.6 else pad2
				p.position = Vector3(x + rng.randf_range(0.2, 0.8), 0.03, y + rng.randf_range(0.2, 0.8))
				add_child(p)
				if rng.randf() < 0.3:
					var f := MeshInstance3D.new()
					var fm := SphereMesh.new()
					fm.radius = 0.06
					fm.height = 0.07
					f.mesh = fm
					f.material_override = flower
					f.position = p.position + Vector3(0, 0.03, 0)
					add_child(f)

# ── 벽 ───────────────────────────────────────────────
func _is_wall(x: int, y: int) -> bool:
	return LevelData.code(x, y) == "#"

func _style(x: int, y: int) -> String:
	if _is_wall(x - 1, y - 1) and _is_wall(x, y - 1) and _is_wall(x + 1, y - 1) and _is_wall(x - 1, y) and _is_wall(x + 1, y) \
			and _is_wall(x - 1, y + 1) and _is_wall(x, y + 1) and _is_wall(x + 1, y + 1):
		return "roof"
	for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
		var n := LevelData.code(x + d.x, y + d.y)
		if n == "_" or "SsFQCRMLV".contains(n):
			return "store"
		if "=GK".contains(n):
			return "storage"
	return "concrete"

var _hcache := {}

func _height(x: int, y: int) -> float:
	if not _is_wall(x, y):
		return 0.0
	var key := Vector2i(x, y)
	if _hcache.has(key):
		return _hcache[key]
	var h := WALL_H
	if y == int(Regions.cur().glass_row) and x >= 9 and x <= 36 and x != 30 and _style(x, y) == "store":
		h = GLASS_LOW
	elif _is_wall(x, y + 1) and y + 1 < LevelData.height():
		# 남쪽으로 이어지는 벽(두꺼운 건물·세로 벽)은 북쪽 끝을 낮춰서
		# 그 북쪽 통로(보도·골목)를 덮지 않게 한다: 북쪽 끝 0.4 → 1.6 → 전체 높이
		var d := 0
		while d < 4 and _is_wall(x, y - d - 1):
			d += 1
		if y - d - 1 >= 0:   # 북쪽에 통로가 있을 때만
			h = minf(WALL_H, 0.4 + d * 1.2)
	_hcache[key] = h
	return h

func _wall_mat(tex_name: String, tint: float = 1.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://scripts/raid/wall3d.gdshader")
	var p := "res://assets/textures/%s.png" % tex_name
	if ResourceLoader.exists(p):
		m.set_shader_parameter("tex", load(p))
	m.set_shader_parameter("tint", tint)
	wall_mats.append(m)
	return m

func _walls() -> void:
	var W := LevelData.width()
	var H := LevelData.height()
	var side := {}   # style -> SurfaceTool
	var top := {}
	for st in ["store", "storage", "concrete", "roof"]:
		side[st] = SurfaceTool.new()
		side[st].begin(Mesh.PRIMITIVE_TRIANGLES)
		top[st] = SurfaceTool.new()
		top[st].begin(Mesh.PRIMITIVE_TRIANGLES)
	var glass := SurfaceTool.new()
	glass.begin(Mesh.PRIMITIVE_TRIANGLES)
	var has_glass := false
	for y in H:
		for x in W:
			if not _is_wall(x, y):
				continue
			var st := _style(x, y)
			var h := _height(x, y)
			var x0 := float(x)
			var z0 := float(y)
			# 윗면
			_quad(top[st], Vector3(x0, h, z0), Vector3(x0 + 1, h, z0), Vector3(x0 + 1, h, z0 + 1), Vector3(x0, h, z0 + 1),
				Vector2(x0, z0) * 0.5, Vector2(x0 + 1, z0) * 0.5, Vector2(x0 + 1, z0 + 1) * 0.5, Vector2(x0, z0 + 1) * 0.5)
			var sst: String = st if st != "roof" else "concrete"
			# 옆면: 이웃이 더 낮을 때만
			var nb := [[Vector2i(0, 1), "s"], [Vector2i(0, -1), "n"], [Vector2i(1, 0), "e"], [Vector2i(-1, 0), "w"]]
			for e in nb:
				var d: Vector2i = e[0]
				var nx := x + d.x
				var ny := y + d.y
				if nx < 0 or ny < 0 or nx >= W or ny >= H:
					continue
				var nh := _height(nx, ny)
				if nh >= h:
					continue
				var v0 := 1.0 - h / WALL_H
				var v1 := 1.0 - nh / WALL_H
				match e[1]:
					"s":
						_quad(side[sst], Vector3(x0, h, z0 + 1), Vector3(x0 + 1, h, z0 + 1), Vector3(x0 + 1, nh, z0 + 1), Vector3(x0, nh, z0 + 1),
							Vector2(x0 * 0.5, v0), Vector2((x0 + 1) * 0.5, v0), Vector2((x0 + 1) * 0.5, v1), Vector2(x0 * 0.5, v1))
					"n":
						_quad(side[sst], Vector3(x0 + 1, h, z0), Vector3(x0, h, z0), Vector3(x0, nh, z0), Vector3(x0 + 1, nh, z0),
							Vector2(-(x0 + 1) * 0.5, v0), Vector2(-x0 * 0.5, v0), Vector2(-x0 * 0.5, v1), Vector2(-(x0 + 1) * 0.5, v1))
					"e":
						_quad(side[sst], Vector3(x0 + 1, h, z0 + 1), Vector3(x0 + 1, h, z0), Vector3(x0 + 1, nh, z0), Vector3(x0 + 1, nh, z0 + 1),
							Vector2(-(z0 + 1) * 0.5, v0), Vector2(-z0 * 0.5, v0), Vector2(-z0 * 0.5, v1), Vector2(-(z0 + 1) * 0.5, v1))
					"w":
						_quad(side[sst], Vector3(x0, h, z0), Vector3(x0, h, z0 + 1), Vector3(x0, nh, z0 + 1), Vector3(x0, nh, z0),
							Vector2(z0 * 0.5, v0), Vector2((z0 + 1) * 0.5, v0), Vector2((z0 + 1) * 0.5, v1), Vector2(z0 * 0.5, v1))
			# 편의점 유리창
			if h == GLASS_LOW:
				has_glass = true
				var gz := z0 + 0.5
				_quad(glass, Vector3(x0, WALL_H - 0.1, gz), Vector3(x0 + 1, WALL_H - 0.1, gz), Vector3(x0 + 1, h, gz), Vector3(x0, h, gz),
					Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))
	var names := {"store": "wall_store", "storage": "wall_storage", "concrete": "wall_concrete"}
	for st in ["store", "storage", "concrete"]:
		_add_mesh(side[st], _wall_mat(names[st], 1.0))
	for st in ["store", "storage", "concrete", "roof"]:
		var tn: String = "roof" if st == "roof" else names[st] + "_top"
		_add_mesh(top[st], _wall_mat(tn, 0.9))
	if has_glass:
		var gm := StandardMaterial3D.new()
		gm.albedo_color = Color(0.55, 0.75, 0.92, 0.28)
		gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		gm.roughness = 0.05
		gm.metallic_specular = 1.0
		gm.cull_mode = BaseMaterial3D.CULL_DISABLED
		gm.emission_enabled = true
		gm.emission = Color(0.25, 0.4, 0.55)
		gm.emission_energy_multiplier = 0.35
		var gi := _add_mesh(glass, gm)
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2) -> void:
	# a-b-c-d 시계방향(바깥에서 볼 때)
	for pair in [[a, ua], [b, ub], [c, uc], [a, ua], [c, uc], [d, ud]]:
		st.set_uv(pair[1])
		st.add_vertex(pair[0])

func _add_mesh(st: SurfaceTool, m: Material) -> MeshInstance3D:
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	add_child(mi)
	return mi


# ── 2D 노드 분류: 3D 모델로 대체 / 바닥 투영 ───────────
func _all_children(n: Node) -> Array:
	var out := []
	if n == null:
		return out
	for c in n.get_children():
		out.append(c)
		out.append_array(_all_children(c))
	return out

func _on_node_added(n: Node) -> void:
	if raid == null:
		return
	if (raid.world and raid.world.is_ancestor_of(n)) or (raid.fx_layer and raid.fx_layer.is_ancestor_of(n)):
		_classify.call_deferred(n)
	elif n.get_parent() == raid and (n is ExitZone or n is Shutter):
		(n as CanvasItem).visibility_layer = L_OVERLAY

func _classify(n: Node) -> void:
	if not is_instance_valid(n) or not (n is CanvasItem):
		return
	var ci := n as CanvasItem
	if n is Projectile:
		ci.visibility_layer = L_HIDDEN
		_add_tracer(n as Projectile)
		return
	# 스프라이트(캐릭터·소품 그림)와 그 그림자는 3D 모델로 대체
	if n is Sprite2D or (n.get_parent() is Sprite2D):
		ci.visibility_layer = L_HIDDEN
	else:
		ci.visibility_layer = L_OVERLAY
	if n.get_parent() == raid.world:
		_register(n)
	# 캐릭터 2D 그림자는 숨김 (3D 그림자)
	if n is Player:
		(n as Player).shadow_node.visibility_layer = L_HIDDEN

func _register(n: Node) -> void:
	if registered.has(n):
		return
	registered[n] = true
	if (n is Player or n is RemotePlayer) and ModelChar.available():
		var mc := ModelChar.new()
		add_child(mc)
		mc.setup(n)
		if n is Player:
			player_model = mc
	elif n is Player or n is RemotePlayer:
		var c := CharBillboard.new()
		add_child(c)
		c.setup(n, PITCH)
	elif n is Enemy and EnemyModel.available((n as Enemy).type):
		var em := EnemyModel.new()
		add_child(em)
		em.setup(n)
		for ch in n.get_children():
			if ch is Node2D and not (ch is Sprite2D) and ch != (n as Enemy).art and ch != (n as Enemy).hand:
				(ch as CanvasItem).visibility_layer = L_HIDDEN   # 2D 그림자
	elif n is Enemy:
		var c2 := CharBillboard.new()
		add_child(c2)
		c2.setup(n, PITCH)
		for ch in n.get_children():
			if ch is Node2D and not (ch is Sprite2D) and ch != (n as Enemy).art and ch != (n as Enemy).hand:
				(ch as CanvasItem).visibility_layer = L_HIDDEN   # 2D 그림자
	elif n is LootContainer:
		var pr := Prop3D.new()
		add_child(pr)
		pr.setup_container(n)
	elif n is Generator:
		var pg := Prop3D.new()
		add_child(pg)
		pg.setup_static(n, "generator", 0.0, Vector2(0, -0.5))
	elif n.has_meta("prop3d"):
		var ps := Prop3D.new()
		add_child(ps)
		ps.setup_static(n, str(n.get_meta("prop3d")), float(n.get_meta("prop_rot", 0.0)), n.get_meta("prop_off", Vector2(0, -0.5)), float(n.get_meta("prop_scale", 1.0)))

# ── 바닥 투영 레이어 ──────────────────────────────────
func _overlay() -> void:
	ov_vp = SubViewport.new()
	ov_vp.size = Vector2i(OV_PX, OV_PX)
	ov_vp.transparent_bg = true
	ov_vp.world_2d = get_viewport().world_2d
	ov_vp.canvas_cull_mask = L_OVERLAY
	ov_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	ov_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	add_child(ov_vp)
	ov_cam = Camera2D.new()
	ov_cam.zoom = Vector2.ONE * (OV_PX / (OV_TILES * T))
	ov_cam.enabled = true
	ov_vp.add_child(ov_cam)
	ov_quad = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(OV_TILES, OV_TILES)
	ov_quad.mesh = pm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = ov_vp.get_texture()
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	m.render_priority = 1
	ov_quad.material_override = m
	ov_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ov_quad)

## 마우스가 가리키는 지점 (2D 게임 좌표). 바닥이 아니라 캐릭터 몸통 높이의 평면과 만나는 점.
func mouse_ground() -> Vector2:
	var mp := get_viewport().get_mouse_position()
	var o := cam.project_ray_origin(mp)
	var d := cam.project_ray_normal(mp)
	if absf(d.y) < 0.0001:
		return raid.player.global_position
	var k := (AIM_H - o.y) / d.y
	var g := o + d * k
	return Vector2(g.x * T, g.z * T)

func world_to_screen(p: Vector2) -> Vector2:
	return cam.unproject_position(Vector3(p.x / T, 0, p.y / T))

func _process(delta: float) -> void:
	if raid == null or raid.player == null:
		return
	# 카메라: 플레이어(부드럽게 보간한 위치) + 마우스 쪽으로 살짝 앞당김.
	# 앞당김은 '화면 좌표'로 계산해서 카메라↔조준점이 서로 끌고 다니지 않게 한다.
	var pp: Vector2 = _player_smooth()
	var vs0 := get_viewport().get_visible_rect().size
	var mo := (get_viewport().get_mouse_position() - vs0 * 0.5) / vs0.y
	mo = mo.limit_length(0.5)
	# 우클릭 조준: 더 멀리 내다보고, 스코프를 달았으면 카메라도 멀어진다
	var pl: Player = raid.player
	var scoped := pl.aim_k > 0.0 and str(pl.mods.get(pl.current_weapon(), {}).get("optic", "")) == "scope_4x"
	var look := Vector2(mo.x, mo.y / sin(deg_to_rad(PITCH))) * lerpf(3.2, 6.5 if scoped else 4.6, pl.aim_k)
	_aim_dist = lerpf(_aim_dist, (CAM_DIST + 5.0) if scoped else CAM_DIST, 1.0 - exp(-4.0 * delta))
	if cam_dist >= CAM_DIST - 0.01 and absf(cam_dist - CAM_DIST) < 6.0:
		cam_dist = _aim_dist
	var want := Vector3(pp.x / T + look.x, 0, pp.y / T + look.y)
	look_t = look_t.lerp(want - Vector3(pp.x / T, 0, pp.y / T), 1.0 - exp(-6.0 * delta))
	cam_target = Vector3(pp.x / T, 0, pp.y / T) + look_t
	var sh := raid.player.camera().offset / T * 0.6
	var pr := deg_to_rad(PITCH)
	cam.position = cam_target + Vector3(sh.x, sin(pr) * cam_dist, cos(pr) * cam_dist + sh.y)
	cam.look_at(cam_target + Vector3(sh.x, 0, sh.y), Vector3.UP)
	# 바닥 투영 레이어를 카메라 중심에 맞춤 (타일 단위로 눌러 붙여 흔들림 방지)
	var oc := Vector2(snappedf(cam_target.x, 0.25), snappedf(cam_target.z - 2.0, 0.25))
	ov_cam.position = oc * T
	ov_quad.position = Vector3(oc.x, 0.025, oc.y)
	_update_tracers()
	_update_gates(delta)
	# 벽 뚫기
	var vs := get_viewport().get_visible_rect().size
	var p3 := Vector3(pp.x / T, 0.0, pp.y / T)
	var sp := cam.unproject_position(p3 + Vector3(0, 0.6, 0))
	for m in wall_mats:
		m.set_shader_parameter("ppos", p3)
		m.set_shader_parameter("pscreen", sp / vs)
		m.set_shader_parameter("aspect", vs.x / vs.y)


# ── 셔터·탈출구 3D ────────────────────────────────────
func _build_gates() -> void:
	if raid.shutter:
		var sp := raid.shutter.position / T
		shutter3d = ProcModels.shutter_door(float(raid.shutter.tiles), WALL_H)
		shutter3d.position = Vector3(sp.x + 0.5, 0, sp.y + raid.shutter.tiles * 0.5)
		add_child(shutter3d)
		shutter_panel = shutter3d.get_node("panel")
		raid.shutter.visibility_layer = L_HIDDEN
	for ex in raid.exits:
		var c: Vector2 = ex.rect.get_center() / T
		var root := Node3D.new()
		root.position = Vector3(c.x, 0, c.y)
		add_child(root)
		var info := {"root": root, "kind": ex.kind}
		match ex.kind:
			"manhole":
				var mh := ProcModels.manhole()
				root.add_child(mh)
				info.model = mh
			"boat":
				var bt := ProcModels.boat()
				bt.position = Vector3(-4.2, 0.05, 0.6)
				bt.rotation.y = PI * 0.5
				root.add_child(bt)
				info.model = bt
				var fl := ProcModels.manhole().get_node("flare")
				fl.get_parent().remove_child(fl)
				fl.position = Vector3(1.4, 0, 0.8)
				root.add_child(fl)
			_:
				var tr := ProcModels.truck()
				tr.position = Vector3(0.2, 0, 0.6)
				root.add_child(tr)
				info.model = tr
		var col := Color("#7CFF8A") if not ex.locked else Color("#FF5A4A")
		var bm := ProcModels.light_beam(col, 7.0, 0.8 if ex.kind == "truck" else 0.55)
		root.add_child(bm)
		info.beam = bm
		info.locked = ex.locked
		var lb := Label3D.new()
		lb.text = ex.label + (" (잠김)" if ex.locked else "")
		lb.font = FX.font()
		lb.font_size = 34
		lb.outline_size = 10
		lb.modulate = col
		lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lb.fixed_size = true
		lb.pixel_size = 0.0007
		lb.position = Vector3(0, 3.4 if ex.kind == "truck" else 2.8, 0)
		root.add_child(lb)
		info.label = lb
		exit3d[ex] = info
		ex.flat_3d = true

func _update_gates(delta: float) -> void:
	if shutter_panel and raid.shutter:
		var k: float = raid.shutter.open_k
		shutter_panel.position.y = k * (WALL_H - 0.15)
		shutter_panel.scale.y = 1.0 - k * 0.92
		if raid.shutter.opening and k < 1.0:
			shutter_panel.position.x = sin(Time.get_ticks_msec() * 0.05) * 0.01
	for ex in exit3d:
		var info: Dictionary = exit3d[ex]
		if info.locked != ex.locked:
			info.locked = ex.locked
			var col := Color("#7CFF8A") if not ex.locked else Color("#FF5A4A")
			info.beam.queue_free()
			var bm := ProcModels.light_beam(col, 7.0, 0.8)
			info.root.add_child(bm)
			info.beam = bm
			info.label.text = ex.label
			info.label.modulate = col
		var t := Time.get_ticks_msec() * 0.001
		(info.beam as Node3D).scale = Vector3.ONE * (1.0 + sin(t * 2.5) * 0.06)
		# 탈출 중이면 빛기둥이 밝아진다
		var active: bool = raid.extract_active and raid.extract_zone == ex
		(info.beam as Node3D).scale.y = 1.4 if active else 1.0

## 탈출 성공 연출: A 맨홀이면 햄스터가 쏙 들어가고, B 트럭이면 트럭에 타고 떠난다
## 쓰러질 때: 가방이 바닥에 툭 떨어지고 빛기둥이 선다 (다음 원정에서 회수)
func play_death_bag(p: Vector2, stays: bool) -> void:
	var bp := ProcModels.backpack()
	bp.scale = Vector3.ONE * 1.6
	var at := Vector3(p.x / T + 0.35, 0.0, p.y / T + 0.15)
	bp.position = at + Vector3(0, 1.4, 0)
	bp.rotation = Vector3(0.0, randf() * TAU, 0.0)
	add_child(bp)
	var tw := create_tween()
	tw.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	tw.tween_property(bp, "position", at, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(bp, "rotation:z", 0.35, 0.45)
	tw.tween_callback(func(): Sfx.play("bag_found", -4.0, 0.7))
	if stays:
		var beam := ProcModels.light_beam(DB.C_LEGEND, 3.0, 0.22)
		beam.position = at
		beam.scale = Vector3(1, 0.01, 1)
		add_child(beam)
		tw.tween_property(beam, "scale:y", 1.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func play_extract(ex: ExitZone) -> void:
	if extracting or not exit3d.has(ex):
		return
	extracting = true
	var info: Dictionary = exit3d[ex]
	var root: Node3D = info.root
	if is_instance_valid(player_model):
		player_model.set("frozen", true)
	if info.kind == "boat":
		var bt: Node3D = info.model
		if is_instance_valid(player_model):
			var twb := create_tween()
			twb.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
			twb.tween_property(player_model, "position", root.position + bt.position + Vector3(0, 0.45, 0), 0.5).set_trans(Tween.TRANS_QUAD)
			twb.tween_callback(func(): player_model.reparent(bt, true))
		var twc := create_tween()
		twc.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
		twc.tween_interval(0.6)
		twc.tween_callback(func(): Sfx.play("truck", -6.0, 0.3))
		twc.tween_property(bt, "position:x", bt.position.x - 9.0, 1.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	elif info.kind == "manhole":
		var mh: Node3D = info.model
		var lid: Node3D = mh.get_node("lid")
		var tw := create_tween()
		tw.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
		tw.tween_property(lid, "position", Vector3(0.9, 0.05, 0.4), 0.35).set_trans(Tween.TRANS_BACK)
		Sfx.play("manhole", -2.0)
		if is_instance_valid(player_model):
			var tw2 := create_tween()
			tw2.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
			tw2.tween_property(player_model, "position", Vector3(root.position.x, 0.25, root.position.z), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw2.tween_property(player_model, "position:y", -1.6, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw2.tween_callback(func(): Sfx.play("splash", -4.0))
		FX.fx3d.dust(Vector2(root.position.x, root.position.z) * T, Vector2.ZERO, 8)
	else:
		var tr: Node3D = info.model
		if is_instance_valid(player_model):
			var tw3 := create_tween()
			tw3.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
			tw3.tween_property(player_model, "position", root.position + tr.position + Vector3(0, 0.3, -2.2), 0.45)
			tw3.tween_property(player_model, "scale", Vector3.ONE * 0.01, 0.2)
		var tw4 := create_tween()
		tw4.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
		tw4.tween_interval(0.7)
		tw4.tween_callback(func(): Sfx.play("truck", -2.0))
		tw4.tween_property(tr, "position:z", tr.position.z + 9.0, 1.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

# ── 총알·화살: 총 높이에서 날아가는 3D 빛줄기 ─────────
static var _tr_mats := {}

func _tracer_mat(c: Color) -> StandardMaterial3D:
	var key := c.to_html()
	if not _tr_mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = c
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 4.0
		_tr_mats[key] = m
	return _tr_mats[key]

func _add_tracer(p: Projectile) -> void:
	if tracers.has(p):
		return
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	var enemy := p.weapon == "enemy_bolt" or not p.from_player
	var bolt := p.weapon == "crossbow"
	bm.size = Vector3(0.045 if not bolt else 0.05, 0.045 if not bolt else 0.05, 1.0)
	mi.mesh = bm
	mi.material_override = _tracer_mat(Color(1.0, 0.35, 0.3) if enemy else (Color(0.95, 0.8, 0.55) if bolt else Color(1.0, 0.93, 0.7)))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	tracers[p] = mi
	# 총구 섬광 (총 높이)
	if p.travelled < 1.0:
		var fl := OmniLight3D.new()
		fl.light_color = Color(1.0, 0.8, 0.45) if not enemy else Color(1.0, 0.4, 0.3)
		fl.light_energy = 3.0
		fl.omni_range = 3.5
		fl.position = Vector3(p.global_position.x / T, AIM_H + 0.05, p.global_position.y / T)
		add_child(fl)
		var tw := fl.create_tween()
		tw.tween_property(fl, "light_energy", 0.0, 0.08)
		tw.tween_callback(fl.queue_free)

func _update_tracers() -> void:
	for key in tracers.keys():
		var mi: MeshInstance3D = tracers[key]
		if not is_instance_valid(key):
			mi.queue_free()
			tracers.erase(key)
			continue
		var p: Projectile = key
		var d := p.vel.normalized()
		var length := clampf(p.travelled / T, 0.15, 1.1 if p.weapon != "crossbow" else 0.5)
		var head := Vector3(p.global_position.x / T, AIM_H, p.global_position.y / T)
		var dir3 := Vector3(d.x, 0, d.y)
		mi.position = head - dir3 * length * 0.5
		mi.basis = Basis.looking_at(dir3, Vector3.UP).scaled(Vector3(1, 1, length))
