class_name View3D
extends Node3D
## 레이드 3D 화면.
## 게임 로직(이동·충돌·AI·전투)은 기존 2D 그대로 돌고, 이 노드가 그 상태를 3D로 그린다.
##  - 바닥: 블렌더에서 위에서 렌더한 floor.png
##  - 벽: LevelData로 만든 실제 3D 벽 (블렌더 구운 텍스처, 플레이어 앞 벽은 디더로 뚫림)
##  - 캐릭터·소품: 2D Sprite2D를 그대로 따라 하는 세운 Sprite3D (진짜 그림자를 드리움)
##  - 직교 카메라라서 바닥면은 화면에 '세로만 눌린' 모양이 된다 → 2D 카메라 세로 줌을 맞춰 두면
##    마우스 조준·HUD·바닥 이펙트(총알·링·발자국)는 2D 그대로 정확히 겹친다.

const T := float(DB.TILE)
const ELEV := 52.0          # 카메라 내려다보는 각도
const WALL_H := 2.6         # 벽 높이 (타일 단위) — 햄스터보다 훨씬 높은 인간 세계
const GLASS_LOW := 0.32
const SPR_LAYER := 2        # 3D로 옮긴 2D 스프라이트는 이 레이어로 숨긴다

var raid: Raid
var cam: Camera3D
var sin_e := sin(deg_to_rad(ELEV))
var k_up := 1.0 / sin(deg_to_rad(ELEV))   # 세운 스프라이트를 화면에서 원래 키로 보이게
var mirrors := {}           # Sprite2D -> Sprite3D
var wall_mats: Array[ShaderMaterial] = []
var old_mask := 0xFFFFFFFF

func build(r: Raid) -> void:
	raid = r
	_env()
	_floor()
	_walls()
	_lights()
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.near = 0.5
	cam.far = 120.0
	cam.current = true
	add_child(cam)
	# 3D로 옮긴 스프라이트는 2D 화면에서 숨긴다
	old_mask = get_viewport().canvas_cull_mask
	get_viewport().canvas_cull_mask = 1
	for n in _all_children(raid.world):
		_maybe_mirror(n)
	get_tree().node_added.connect(_on_node_added)

func _exit_tree() -> void:
	if get_viewport():
		get_viewport().canvas_cull_mask = old_mask
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)

# ── 환경·조명 ────────────────────────────────────────
func _env() -> void:
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#0B0F18")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.6, 0.82)
	e.ambient_light_energy = 0.38
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 0.95
	e.ssao_enabled = true
	e.ssao_radius = 1.2
	e.ssao_intensity = 2.2
	e.glow_enabled = true
	e.glow_intensity = 0.55
	e.glow_bloom = 0.04
	e.glow_hdr_threshold = 1.1
	e.adjustment_enabled = true
	e.adjustment_saturation = 1.08
	e.adjustment_contrast = 1.04
	we.environment = e
	add_child(we)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.75, 0.82, 1.0)
	moon.light_energy = 0.42
	moon.shadow_enabled = true
	moon.shadow_blur = 1.5
	moon.directional_shadow_max_distance = 45.0
	moon.rotation_degrees = Vector3(-58, 28, 0)
	add_child(moon)

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
	m.albedo_color = Color(0.78, 0.78, 0.8)
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
		_add_mesh(side[st], _wall_mat(names[st], 0.85))
	for st in ["store", "storage", "concrete", "roof"]:
		var tn: String = "roof" if st == "roof" else names[st] + "_top"
		_add_mesh(top[st], _wall_mat(tn, 0.7))
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

# ── 2D 스프라이트 → 3D 세운 스프라이트 ────────────────
func _all_children(n: Node) -> Array:
	var out := []
	for c in n.get_children():
		out.append(c)
		out.append_array(_all_children(c))
	return out

func _on_node_added(n: Node) -> void:
	if n is Sprite2D:
		_maybe_mirror.call_deferred(n)

func _maybe_mirror(n: Node) -> void:
	if not (n is Sprite2D) or not is_instance_valid(n) or mirrors.has(n):
		return
	if raid.world == null or not raid.world.is_ancestor_of(n):
		return
	var s2: Sprite2D = n
	s2.visibility_layer = 1 << (SPR_LAYER - 1)
	for c in s2.get_children():
		if c is CanvasItem:
			c.visibility_layer = 1 << (SPR_LAYER - 1)   # 스프라이트에 딸린 2D 바닥 그림자도 숨김 (3D 그림자로 대체)
	var s3 := Sprite3D.new()
	s3.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s3.alpha_scissor_threshold = 0.45
	s3.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	s3.shaded = false
	s3.double_sided = true
	s3.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	s3.pixel_size = 1.0
	add_child(s3)
	mirrors[s2] = s3
	_sync(s2, s3)

func _entity_of(n: Node) -> Node2D:
	var e := n
	while e.get_parent() != null and e.get_parent() != raid.world:
		e = e.get_parent()
	return e as Node2D

func _l(v: Vector2) -> Vector3:
	# 2D 픽셀 벡터 → 3D (세운 평면, y는 화면 원래 키로 보이도록 k_up배)
	return Vector3(v.x / T, -v.y / T * k_up, 0.0)

func _sync(s2: Sprite2D, s3: Sprite3D) -> void:
	var ent := _entity_of(s2)
	if ent == null:
		s3.visible = false
		return
	var vis := s2.is_visible_in_tree()
	var mod := s2.self_modulate
	var p: Node = s2
	while p != null and p != raid.world:
		if p is CanvasItem:
			mod *= (p as CanvasItem).modulate
		p = p.get_parent()
	if mod.a < 0.02 or s2.texture == null:
		vis = false
	s3.visible = vis
	if not vis:
		return
	if s3.texture != s2.texture:
		s3.texture = s2.texture
	s3.hframes = s2.hframes
	s3.vframes = s2.vframes
	s3.frame = s2.frame
	s3.region_enabled = s2.region_enabled
	if s2.region_enabled:
		s3.region_rect = s2.region_rect
	s3.centered = s2.centered
	# Sprite2D는 아래로, Sprite3D(비중앙)는 위로 자란다 → 프레임 높이만큼 보정
	var fh0 := s2.region_rect.size.y if s2.region_enabled else (float(s2.texture.get_height()) / maxf(1.0, float(s2.vframes)))
	if s2.centered:
		s3.offset = Vector2(s2.offset.x, -s2.offset.y)
	else:
		s3.offset = Vector2(s2.offset.x, -(s2.offset.y + fh0))
	s3.flip_h = s2.flip_h
	s3.flip_v = s2.flip_v
	# 피격 번쩍임
	if s2.material is ShaderMaterial:
		var f = (s2.material as ShaderMaterial).get_shader_parameter("flash")
		if f != null and float(f) > 0.05:
			mod = mod.lerp(Color(1.0, 0.55, 0.55, mod.a), clampf(float(f), 0.0, 1.0))
	s3.modulate = Color(mod.r, mod.g, mod.b, mod.a)
	var tr := s2.get_global_transform()
	var foot := ent.global_position
	var bx := _l(tr.x)
	var by := -_l(tr.y)
	s3.basis = Basis(bx, by, Vector3(0, 0, 1))
	# 같은 캐릭터 안에서는 그리는 순서대로 카메라 쪽으로 아주 조금씩
	var order := float(s2.z_index) * 0.02 + float(s2.get_index()) * 0.004
	s3.position = Vector3(foot.x / T, 0.0, foot.y / T) + _l(tr.origin - foot) + Vector3(0, 0, 0.02 + order)
	# 캐릭터가 아닌 소품은 그림 아래 끝을 바닥에 붙인다 (2D에선 타일 가운데에 떠 있게 그려짐)
	if not (ent is CharacterBody2D):
		var fh := s2.region_rect.size.y if s2.region_enabled else (float(s2.texture.get_height()) / maxf(1.0, float(s2.vframes)))
		var local_bottom := s2.offset.y + (fh * 0.5 if s2.centered else fh)
		var rb := (tr * Vector2(0, local_bottom)).y - foot.y
		s3.position.y += rb / T * k_up
	if mod.a < 0.98:
		s3.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		s3.transparent = true
	else:
		s3.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD

func _process(_delta: float) -> void:
	if raid == null or raid.player == null:
		return
	# 카메라: 2D 카메라와 똑같은 화면이 되도록
	var c2 := raid.player.camera()
	var vs := get_viewport().get_visible_rect().size
	var z := c2.zoom.x
	c2.zoom = Vector2(z, z * sin_e)
	# 2D가 실제로 그리는 화면 변환에서 화면 중앙의 바닥 좌표를 구한다 (조준 앞당김·흔들림 포함)
	var center: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * (vs * 0.5)
	var tgt := Vector3(center.x / T, 0.0, center.y / T)
	cam.size = vs.y / (T * z)
	cam.position = tgt + Vector3(0, sin_e, cos(deg_to_rad(ELEV))) * 40.0
	cam.look_at(tgt, Vector3.UP)
	# 스프라이트 동기화
	for s2 in mirrors.keys():
		var s3: Sprite3D = mirrors[s2]
		if not is_instance_valid(s2):
			s3.queue_free()
			mirrors.erase(s2)
			continue
		_sync(s2, s3)
	# 벽 뚫기
	var pp: Vector2 = raid.player.global_position
	var p3 := Vector3(pp.x / T, 0.0, pp.y / T)
	var sp := cam.unproject_position(p3 + Vector3(0, 0.75 * k_up * 0.6, 0))
	for m in wall_mats:
		m.set_shader_parameter("ppos", p3)
		m.set_shader_parameter("pscreen", sp / vs)
		m.set_shader_parameter("aspect", vs.x / vs.y)
