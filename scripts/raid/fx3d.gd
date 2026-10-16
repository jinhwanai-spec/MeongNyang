class_name FX3D
extends Node3D
## 3D 화면 전용 이펙트: 총구 화염, 탄피, 불꽃 파편, 털 뭉치, 피해 숫자, 처치 연출, 히트스톱.
## 2D 게임 좌표(px)를 받아 3D(타일 단위)로 옮겨 그린다. 가벼운 자체 파티클(메시 몇 개 + 직접 움직임).

const T := float(DB.TILE)
const AIM_H := 0.5
const MAX_PARTS := 260

var parts: Array = []      # [MeshInstance3D, vel: Vector3, life, max_life, grav, spin: Vector3, scale0, fade]
var _box: BoxMesh
var _quad: QuadMesh
var _shell: CylinderMesh
var _mats := {}
var _stop_t := 0.0

func _ready() -> void:
	_box = BoxMesh.new()
	_box.size = Vector3(0.05, 0.05, 0.05)
	_quad = QuadMesh.new()
	_quad.size = Vector2(1, 1)
	_shell = CylinderMesh.new()
	_shell.top_radius = 0.018
	_shell.bottom_radius = 0.018
	_shell.height = 0.07
	_shell.radial_segments = 6
	_shell.rings = 1

static func p3(p: Vector2, h: float = AIM_H) -> Vector3:
	return Vector3(p.x / T, h, p.y / T)

func _mat(key: String, c: Color, additive: bool, billboard: bool = false, tex: Texture2D = null, emit: float = 3.0) -> StandardMaterial3D:
	var k := "%s_%s" % [key, c.to_html()]
	if _mats.has(k):
		return _mats[k]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.vertex_color_use_as_albedo = false
	if additive:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	else:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	if tex:
		m.albedo_texture = tex
	m.no_depth_test = false
	_mats[k] = m
	return m

func _spawn(mesh: Mesh, mat: Material, pos: Vector3, vel: Vector3, life: float, grav: float, sc: float, spin := Vector3.ZERO, fade := true) -> MeshInstance3D:
	if parts.size() >= MAX_PARTS:
		var old: Array = parts.pop_front()
		if is_instance_valid(old[0]):
			old[0].queue_free()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	mi.scale = Vector3.ONE * sc
	add_child(mi)
	parts.append([mi, vel, life, life, grav, spin, sc, fade])
	return mi

func _process(delta: float) -> void:
	var real := delta / maxf(Engine.time_scale, 0.01)
	if _stop_t > 0.0:
		_stop_t -= real
		if _stop_t <= 0.0:
			Engine.time_scale = 1.0
	var i := parts.size() - 1
	while i >= 0:
		var p: Array = parts[i]
		var mi: MeshInstance3D = p[0]
		p[2] -= delta
		if p[2] <= 0.0 or not is_instance_valid(mi):
			if is_instance_valid(mi):
				mi.queue_free()
			parts.remove_at(i)
			i -= 1
			continue
		var v: Vector3 = p[1]
		v.y -= p[4] * delta
		var np := mi.position + v * delta
		if np.y < 0.01 and p[4] > 0.0:
			# 바닥에 튕김
			np.y = 0.01
			v.y = -v.y * 0.35
			v.x *= 0.6
			v.z *= 0.6
		mi.position = np
		p[1] = v
		mi.rotation += p[5] * delta
		var k: float = p[2] / p[3]
		if p[7]:
			mi.scale = Vector3.ONE * p[6] * (0.4 + 0.6 * k)
		i -= 1

# ── 총구 화염: 밝은 별 모양 + 연기 한 모금 ──
func muzzle(pos: Vector2, d: Vector2, big: bool, enemy: bool = false) -> void:
	var c := Color(1.0, 0.78, 0.4) if not enemy else Color(1.0, 0.45, 0.35)
	var at := p3(pos, AIM_H + 0.05)
	var tex := FX.light_texture()
	var core := _spawn(_quad, _mat("flash", c, true, true, tex, 6.0), at, Vector3.ZERO, 0.06 if not big else 0.08, 0.0, 0.55 if not big else 0.85)
	core.rotation.z = randf() * TAU
	# 앞으로 뻗는 불꽃
	var dir3 := Vector3(d.x, 0, d.y)
	for k in 3:
		var sp := _spawn(_box, _mat("spark", c, true), at + dir3 * 0.12, dir3.rotated(Vector3.UP, randf_range(-0.35, 0.35)) * randf_range(6.0, 11.0), 0.07, 0.0, randf_range(0.6, 1.0))
		sp.look_at_from_position(sp.position, sp.position + dir3, Vector3.UP)
		sp.scale = Vector3(0.6, 0.6, 3.0)
	# 연기
	for k in (2 if not big else 4):
		_spawn(_quad, _mat("smoke", Color(0.85, 0.85, 0.85, 0.12), false, true, tex), at + dir3 * 0.2, dir3 * randf_range(0.6, 1.4) + Vector3(randf_range(-0.2, 0.2), randf_range(0.3, 0.7), randf_range(-0.2, 0.2)), randf_range(0.3, 0.5), -0.3, randf_range(0.14, 0.22), Vector3.ZERO, false)

# ── 탄피: 옆으로 튀어 나가 바닥에서 통통 ──
func shell(pos: Vector2, side: float) -> void:
	var at := p3(pos, 0.55)
	var v := Vector3(side * randf_range(1.2, 2.2), randf_range(1.8, 2.6), randf_range(-0.6, 0.6))
	var s := _spawn(_shell, _mat("brass", Color(0.95, 0.75, 0.3), false), at, v, 1.4, 9.0, 1.0, Vector3(randf_range(-20, 20), randf_range(-20, 20), randf_range(-20, 20)), false)
	s.rotation = Vector3(0, 0, PI * 0.5)
	get_tree().create_timer(0.35).timeout.connect(func(): Sfx.play_at("shell_drop", pos, -14.0, 0.2))

# ── 불꽃/파편: 벽은 하얀 불꽃 + 먼지, 몸은 노란 불꽃 ──
func sparks(pos: Vector2, d: Vector2, c: Color, n: int = 8, h: float = AIM_H) -> void:
	var at := p3(pos, h)
	var dir3 := Vector3(d.x, 0, d.y).normalized()
	for k in n:
		var v := (dir3.rotated(Vector3.UP, randf_range(-1.1, 1.1)) * randf_range(2.5, 6.0)) + Vector3(0, randf_range(0.5, 3.0), 0)
		var s := _spawn(_box, _mat("spark", c, true), at, v, randf_range(0.15, 0.3), 9.0, randf_range(0.5, 1.0))
		s.look_at_from_position(s.position, s.position + v, Vector3.UP if absf(v.normalized().y) < 0.95 else Vector3.RIGHT)
		s.scale = Vector3(0.5, 0.5, 2.6)
	var tex := FX.light_texture()
	_spawn(_quad, _mat("hitglow", c, true, true, tex, 4.0), at, Vector3.ZERO, 0.07, 0.0, 0.5)

func dust(pos: Vector2, d: Vector2, n: int = 3) -> void:
	var at := p3(pos, AIM_H)
	var tex := FX.light_texture()
	for k in n:
		_spawn(_quad, _mat("dust", Color(0.75, 0.7, 0.62, 0.18), false, true, tex), at, Vector3(d.x, 0, d.y) * randf_range(0.3, 0.9) + Vector3(randf_range(-0.3, 0.3), randf_range(0.2, 0.6), randf_range(-0.3, 0.3)), randf_range(0.4, 0.7), -0.2, randf_range(0.2, 0.35), Vector3.ZERO, false)

# ── 털 뭉치 (맞거나 쓰러질 때) ──
func fur(pos: Vector2, c: Color, n: int, h: float = 0.55) -> void:
	var at := p3(pos, h)
	for k in mini(n, 22):
		var a := randf() * TAU
		var v := Vector3(cos(a), 0, sin(a)) * randf_range(1.0, 3.5) + Vector3(0, randf_range(1.0, 3.0), 0)
		_spawn(_box, _mat("fur", c, false), at, v, randf_range(0.5, 0.9), 6.0, randf_range(0.7, 1.4), Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8)))

# ── 피해 숫자: 톡 튀어 올랐다 사라짐 (치명타는 크고 노랗게) ──
func damage_number(pos: Vector2, amount: float, crit: bool, h: float = 1.2, blocked: bool = false) -> void:
	var l := Label3D.new()
	l.text = str(int(round(amount))) if not blocked else "막힘 %d" % int(round(amount))
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.pixel_size = 0.0012 if crit else 0.0009
	l.font = FX.font()
	l.font_size = 30
	l.outline_size = 10
	l.modulate = Color("#9FC3FF") if blocked else (DB.C_LEGEND if crit else Color(1, 1, 1))
	l.outline_modulate = Color(0.15, 0.05, 0.05) if not blocked else Color(0.03, 0.06, 0.15)
	l.position = p3(pos, h) + Vector3(randf_range(-0.25, 0.25), 0, 0)
	add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y + 0.7, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "scale", Vector3.ONE * 1.35, 0.08).set_trans(Tween.TRANS_BACK)
	tw.chain().tween_property(l, "modulate:a", 0.0, 0.25)
	tw.tween_callback(l.queue_free)

# ── 처치: 하얀 링 + 별 + 짧은 멈칫(히트스톱) ──
func kill(pos: Vector2, c: Color) -> void:
	var at := p3(pos, 0.6)
	var tex := FX.light_texture()
	var ring := _spawn(_quad, _mat("killglow", Color(1, 0.85, 0.55, 0.6), true, true, tex, 2.5), at, Vector3.ZERO, 0.14, 0.0, 0.9)
	ring.scale = Vector3.ONE * 0.3
	for k in 8:
		var a := TAU * k / 8.0
		_spawn(_box, _mat("star", DB.C_LEGEND, true), at, Vector3(cos(a), 0.6, sin(a)) * 4.0, 0.3, 4.0, 1.2, Vector3(5, 5, 5))
	fur(pos, c, 18)
	Sfx.play_at("kill", pos, -4.0, 0.05)
	hitstop(0.06)

## 아주 짧게 시간을 멈칫 → 타격감 (협동 중엔 안 함)
var _dot_tex: GradientTexture2D
func _soft_dot() -> GradientTexture2D:
	if _dot_tex == null:
		_dot_tex = GradientTexture2D.new()
		var g := Gradient.new()
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
		_dot_tex.gradient = g
		_dot_tex.fill = GradientTexture2D.FILL_RADIAL
		_dot_tex.fill_from = Vector2(0.5, 0.5)
		_dot_tex.fill_to = Vector2(1.0, 0.5)
		_dot_tex.width = 64
		_dot_tex.height = 64
	return _dot_tex

## 폭발: 불덩이가 부풀었다 사라지고, 잠깐 주황 빛 + 파편 + 연기
func boom(pos: Vector2, radius_px: float) -> void:
	var r := radius_px / T
	var at := p3(pos, 0.3)
	var fire := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	fire.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(1.0, 0.62, 0.22, 0.9)
	fire.material_override = m
	fire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fire.position = at
	fire.scale = Vector3.ONE * 0.2
	add_child(fire)
	var tw := fire.create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(fire, "scale", Vector3(1.0, 0.75, 1.0) * r * 0.8, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(m, "albedo_color", Color(1.0, 0.3, 0.08, 0.0), 0.32)
	tw.tween_callback(fire.queue_free)
	# 하얗게 빛나는 속불
	var core := MeshInstance3D.new()
	core.mesh = sm
	var mc := m.duplicate() as StandardMaterial3D
	mc.albedo_color = Color(1.0, 0.95, 0.7, 1.0)
	core.material_override = mc
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	core.position = at
	core.scale = Vector3.ONE * 0.15
	add_child(core)
	var tc := core.create_tween()
	tc.set_ignore_time_scale(true)
	tc.tween_property(core, "scale", Vector3.ONE * r * 0.4, 0.08)
	tc.parallel().tween_property(mc, "albedo_color:a", 0.0, 0.2)
	tc.tween_callback(core.queue_free)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.6, 0.25)
	l.light_energy = 6.0
	l.omni_range = r * 3.0
	l.position = at + Vector3(0, 0.6, 0)
	add_child(l)
	var tl := l.create_tween()
	tl.set_ignore_time_scale(true)
	tl.tween_property(l, "light_energy", 0.0, 0.5)
	tl.tween_callback(l.queue_free)
	sparks(pos, Vector2.UP, Color(1.0, 0.7, 0.3), 18, 0.4)
	var smoke := _mat("smoke", Color(0.3, 0.3, 0.32, 0.5), false, true, _soft_dot())
	for i in 8:
		var a := randf() * TAU
		_spawn(_quad, smoke, at + Vector3(cos(a), 0.2, sin(a)) * r * 0.4, Vector3(cos(a) * 0.6, 1.2 + randf(), sin(a) * 0.6), 1.2, -0.6, 0.6 + randf() * 0.5)

## 근접 무기 휘두르기: 조준 방향으로 부채꼴 궤적이 휙 그려지고 사라진다
func slash(pos: Vector2, d: Vector2, reach_px: float, arc_deg: float, c: Color, heavy: bool = false) -> void:
	var r := reach_px / T
	var r0 := r * 0.6
	var half := deg_to_rad(arc_deg) * 0.5
	var seg := 14
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in seg:
		var a0 := -half + 2.0 * half * float(i) / seg
		var a1 := -half + 2.0 * half * float(i + 1) / seg
		var k0 := float(i) / seg
		var k1 := float(i + 1) / seg
		var o0 := Vector3(cos(a0), 0, sin(a0))
		var o1 := Vector3(cos(a1), 0, sin(a1))
		var ca := Color(c, 0.04 + 0.55 * k0)
		var cb := Color(c, 0.04 + 0.55 * k1)
		var ci := Color(c, 0.0)
		st.set_color(ci); st.add_vertex(o0 * r0)
		st.set_color(ca); st.add_vertex(o0 * r)
		st.set_color(cb); st.add_vertex(o1 * r)
		st.set_color(ci); st.add_vertex(o0 * r0)
		st.set_color(cb); st.add_vertex(o1 * r)
		st.set_color(ci); st.add_vertex(o1 * r0)
	var mesh := st.commit()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = p3(pos, 0.45)
	var ang := atan2(d.y, d.x)
	mi.rotation.y = -ang + 0.6
	mi.scale = Vector3(0.7, 1, 0.7)
	add_child(mi)
	var tw := mi.create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(mi, "rotation:y", -ang - 0.15, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(mi, "scale", Vector3(1.05, 1, 1.05) * (1.12 if heavy else 1.0), 0.1)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.14)
	tw.tween_callback(mi.queue_free)

func hitstop(dur: float, ts: float = 0.08) -> void:
	if Net.active or dur <= 0.0:
		return
	Engine.time_scale = ts
	_stop_t = maxf(_stop_t, dur)

func _exit_tree() -> void:
	Engine.time_scale = 1.0
