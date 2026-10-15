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
	_warmup()
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
	var L := [
		[Vector2(14, 8), "#FFE9C4", 7.0, 1.6], [Vector2(23, 8), "#FFE9C4", 7.0, 1.6], [Vector2(31, 7), "#CFE8FF", 6.0, 1.4],
		[Vector2(14, 13.5), "#FFE9C4", 6.0, 1.3], [Vector2(26, 13.5), "#FFE9C4", 6.0, 1.3], [Vector2(33, 13), "#FFD9A0", 5.0, 1.4],
		[Vector2(44, 7), "#9FB6FF", 7.0, 1.6], [Vector2(22, 17.0), "#FF7FB0", 5.0, 2.2],
		[Vector2(6.5, 19.3), "#FFD89A", 6.0, 2.4], [Vector2(17.5, 19.3), "#FFD89A", 6.0, 2.4], [Vector2(33.5, 19.3), "#FFD89A", 6.0, 2.4],
		[Vector2(45.5, 19.3), "#FFD89A", 6.0, 2.4], [Vector2(54.5, 19.3), "#FFD89A", 6.0, 2.4],
		[Vector2(20, 33), "#FFB070", 5.5, 2.0], [Vector2(42, 33), "#B0C8FF", 6.0, 1.8], [Vector2(54, 36), "#7CFF9A", 3.5, 1.6],
	]
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
	var fp := "res://assets/sprites/map/floor.png"
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
	if y == 16 and x >= 9 and x <= 36 and x != 30 and _style(x, y) == "store":
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
	elif n is Player or n is RemotePlayer:
		var c := CharBillboard.new()
		add_child(c)
		c.setup(n, PITCH)
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
	var look := Vector2(mo.x, mo.y / sin(deg_to_rad(PITCH))) * 3.2
	var want := Vector3(pp.x / T + look.x, 0, pp.y / T + look.y)
	look_t = look_t.lerp(want - Vector3(pp.x / T, 0, pp.y / T), 1.0 - exp(-6.0 * delta))
	cam_target = Vector3(pp.x / T, 0, pp.y / T) + look_t
	var sh := raid.player.camera().offset / T * 0.6
	var pr := deg_to_rad(PITCH)
	cam.position = cam_target + Vector3(sh.x, sin(pr) * CAM_DIST, cos(pr) * CAM_DIST + sh.y)
	cam.look_at(cam_target + Vector3(sh.x, 0, sh.y), Vector3.UP)
	# 바닥 투영 레이어를 카메라 중심에 맞춤 (타일 단위로 눌러 붙여 흔들림 방지)
	var oc := Vector2(snappedf(cam_target.x, 0.25), snappedf(cam_target.z - 2.0, 0.25))
	ov_cam.position = oc * T
	ov_quad.position = Vector3(oc.x, 0.025, oc.y)
	_update_tracers()
	# 벽 뚫기
	var vs := get_viewport().get_visible_rect().size
	var p3 := Vector3(pp.x / T, 0.0, pp.y / T)
	var sp := cam.unproject_position(p3 + Vector3(0, 0.6, 0))
	for m in wall_mats:
		m.set_shader_parameter("ppos", p3)
		m.set_shader_parameter("pscreen", sp / vs)
		m.set_shader_parameter("aspect", vs.x / vs.y)


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
		m.emission_energy_multiplier = 3.0
		_tr_mats[key] = m
	return _tr_mats[key]

func _add_tracer(p: Projectile) -> void:
	if tracers.has(p):
		return
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	var enemy := p.weapon == "enemy_bolt" or not p.from_player
	var bolt := p.weapon == "crossbow"
	bm.size = Vector3(0.05 if not bolt else 0.04, 0.05 if not bolt else 0.04, 1.0)
	mi.mesh = bm
	mi.material_override = _tracer_mat(Color(1.0, 0.35, 0.3) if enemy else (Color(0.95, 0.8, 0.55) if bolt else Color(1.0, 0.86, 0.5)))
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
		var length := clampf(p.travelled / T, 0.15, 0.9 if p.weapon != "crossbow" else 0.5)
		var head := Vector3(p.global_position.x / T, AIM_H, p.global_position.y / T)
		var dir3 := Vector3(d.x, 0, d.y)
		mi.position = head - dir3 * length * 0.5
		mi.basis = Basis.looking_at(dir3, Vector3.UP).scaled(Vector3(1, 1, length))
