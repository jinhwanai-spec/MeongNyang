class_name CharBillboard
extends Node3D
## 캐릭터를 레퍼런스 시트 그림 그대로 3D 세상에 세워서 보여준다 (HD-2D 방식).
## - 원정 Player/Enemy: 2D 스프라이트(프레임·뒤집기·통통 튀기)를 그대로 따라 그림
## - 로비 햄스터·다른 플레이어: 같은 시트 애니메이션(걷기·정면·뒷모습)을 직접 재생
## 원근 카메라에서 원래 키로 보이도록 세로를 1/cos(카메라 각도)만큼 늘이고, 바닥엔 부드러운 그림자.

const T := float(DB.TILE)

var ent: Node2D
var s3: Sprite3D
var blob: MeshInstance3D
var kv := 1.5               # 세로 보정
var kind := ""              # 직접 재생할 때의 시트 이름
var own := false
var phase := 0.0
var t := 0.0
var last_pos := Vector2.ZERO
var label: Label3D
var mark: Label3D
var height := 1.5
var static_anim := ""       # NPC: 고정 애니메이션
# 페이퍼마리오식 움직임
var pivot: Node3D
var shown_flip := false
var pending_flip := false
var turn_t := 0.0
const TURN := 0.16
var wp := 0.0               # 걸음 위상
var last_hop := 0.0
var sheet_kind := ""        # 뒤집을 때 발 기준점 계산용

static func blob_shadow(w: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(w, w * 0.55)
	q.orientation = PlaneMesh.FACE_Y
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0.42))
	g.set_color(1, Color(0, 0, 0, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	m.albedo_texture = gt
	mi.material_override = m
	mi.position.y = 0.03
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

func _make_sprite() -> void:
	pivot = Node3D.new()
	add_child(pivot)
	s3 = Sprite3D.new()
	s3.billboard = BaseMaterial3D.BILLBOARD_DISABLED   # 카메라 쪽 회전은 직접 (기울기·뒤뚱거림을 얹기 위해)
	s3.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s3.alpha_scissor_threshold = 0.4
	s3.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	s3.shaded = false
	s3.double_sided = true
	s3.centered = false
	s3.pixel_size = 1.0 / T
	s3.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(s3)

## 원정 캐릭터·로비 햄스터·다른 플레이어
func setup(e: Node2D, cam_pitch_deg: float) -> void:
	ent = e
	kv = 1.0 / cos(deg_to_rad(cam_pitch_deg))
	_make_sprite()
	var radius := 0.85
	if e is Enemy:
		radius = 0.95 if (e as Enemy).type != "bulldog" else 1.25
	blob = blob_shadow(radius)
	add_child(blob)
	own = not (e.get("spr") is Sprite2D)
	sheet_kind = str(e.get("SPRITE")) if e is Player else (str(e.get("sprite_kind")) if e is Enemy else "")
	if own:
		var hid: String = str((e.get("hdata") as Dictionary).get("_id", GameState.hamster)) if e.get("hdata") is Dictionary else GameState.hamster
		if e is LobbyPlayer:
			hid = GameState.hamster
		kind = "hamster_" + hid
		if Sprites.char_info(kind).is_empty():
			kind = "hamster"
		_setup_own_sprite()
	height = 1.45 * kv * 0.66
	if e is Enemy:
		_make_labels(str(e.data.name), e.data.name_color)
	elif e is RemotePlayer:
		_make_labels((e as RemotePlayer).nickname, Color("#9CFFB4"))
		label.visible = true
	last_pos = e.global_position
	position = Vector3(last_pos.x / T, 0, last_pos.y / T)

## 정지 NPC (은신처·메인화면): 시트 이름 + 애니메이션
func setup_static(sheet: String, anim: String, cam_pitch_deg: float, scale_k: float = 1.0) -> void:
	kv = 1.0 / cos(deg_to_rad(cam_pitch_deg))
	kind = sheet
	static_anim = anim
	_make_sprite()
	blob = blob_shadow(0.9 * scale_k)
	add_child(blob)
	own = true
	_setup_own_sprite()
	s3.scale = Vector3(Sprites.char_scale(kind) * scale_k, Sprites.char_scale(kind) * scale_k * kv, 1)
	_face(1.0)
	s3.frame = Sprites.char_frame(kind, anim, 0.0)

func _setup_own_sprite() -> void:
	var info := Sprites.char_info(kind)
	s3.texture = Sprites.char_tex(kind)
	s3.hframes = int(info.count)
	var k := Sprites.char_scale(kind)
	s3.scale = Vector3(k, k * kv, 1)

func _face(face: float) -> void:
	var info := Sprites.char_info(kind)
	var flip := (face < 0.0) != bool(info.get("faces_left", false))
	s3.flip_h = flip
	var ax: float = info.anchor[0]
	if flip:
		ax = float(info.frame[0]) - ax
	var fh := float(info.frame[1])
	s3.offset = Vector2(-ax, -(-float(info.anchor[1]) + fh))

func _make_labels(text: String, col: Color) -> void:
	label = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = 0.0006
	label.font = FX.font()
	label.font_size = 22
	label.outline_size = 8
	label.text = text
	label.modulate = col
	label.visible = false
	add_child(label)
	mark = Label3D.new()
	mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	mark.no_depth_test = true
	mark.fixed_size = true
	mark.pixel_size = 0.0009
	mark.font = FX.font()
	mark.font_size = 40
	mark.outline_size = 12
	mark.visible = false
	add_child(mark)

func _face_camera() -> void:
	var c := get_viewport().get_camera_3d()
	if c:
		var d := c.global_position - global_position
		pivot.rotation.y = atan2(d.x, d.z)

func _enter_tree() -> void:
	process_physics_priority = 100   # 캐릭터가 움직인 뒤에 기록

func _process(delta: float) -> void:
	t += delta
	_face_camera()
	if static_anim != "":
		s3.frame = Sprites.char_frame(kind, static_anim, t * 6.0)
		return
	if not is_instance_valid(ent):
		queue_free()
		return
	var pos := _smooth_pos()
	var vel := (pos - last_pos) / maxf(delta, 0.001)
	last_pos = pos
	position = Vector3(pos.x / T, 0, pos.y / T)
	if own:
		_own_anim(delta, vel)
	else:
		_mirror()
	_juice(delta, vel)
	if ent is Enemy:
		_enemy_labels()
	if label:
		label.position.y = height + 0.1
	if mark:
		mark.position.y = height + 0.42 + absf(sin(t * 8.0)) * 0.05

## 원정 Player/Enemy: 2D 스프라이트를 그대로 따라 그림
func _mirror() -> void:
	var spr: Sprite2D = ent.spr
	var vis := spr.is_visible_in_tree() and not bool(ent.get("dead"))
	var mod := spr.self_modulate
	var p: Node = spr
	while p != null and p != ent.get_parent():
		if p is CanvasItem:
			mod *= (p as CanvasItem).modulate
		p = p.get_parent()
	if mod.a < 0.02 or spr.texture == null:
		vis = false
	s3.visible = vis
	blob.visible = vis or bool(ent.get("dead")) == false
	if not vis:
		return
	if s3.texture != spr.texture:
		s3.texture = spr.texture
	s3.hframes = spr.hframes
	s3.vframes = spr.vframes
	s3.frame = spr.frame
	s3.flip_h = spr.flip_h
	var fh := float(spr.texture.get_height()) / maxf(1.0, float(spr.vframes))
	s3.offset = Vector2(spr.offset.x, -(spr.offset.y + fh))
	var gs := spr.global_scale
	s3.scale = Vector3(absf(gs.x), absf(gs.y) * kv, 1.0)
	var rel := spr.global_position - ent.global_position
	s3.position = Vector3(rel.x / T, -rel.y / T * kv, 0.0)
	s3.rotation.z = -spr.global_rotation
	if spr.material is ShaderMaterial:
		var f = (spr.material as ShaderMaterial).get_shader_parameter("flash")
		if f != null and float(f) > 0.05:
			mod = mod.lerp(Color(2.4, 2.4, 2.4, mod.a), clampf(float(f), 0.0, 1.0) * 0.7)
	s3.modulate = mod
	if mod.a < 0.98:
		s3.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		s3.transparent = true
	else:
		s3.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD

## 로비 햄스터·다른 플레이어: 같은 시트 애니메이션을 직접 재생
func _own_anim(delta: float, vel: Vector2) -> void:
	if ent is LobbyPlayer and kind != "hamster_" + GameState.hamster and not Sprites.char_info("hamster_" + GameState.hamster).is_empty():
		kind = "hamster_" + GameState.hamster
		_setup_own_sprite()
	var moving := vel.length() > 30.0
	var aim: Vector2 = ent.get("aim_dir") if ent.get("aim_dir") != null else Vector2(0, 1)
	var view := ""
	if aim.y > 0.62:
		view = "_front"
	elif aim.y < -0.62:
		view = "_back"
	phase += delta * (vel.length() / 25.0 + 1.0) if moving else delta * 2.5
	var anim := ("walk" if moving else "idle") + view
	if float(ent.get("dodge_t") if ent.get("dodge_t") != null else 0.0) > 0.0:
		anim = "dodge"
	elif float(ent.get("heal_t") if ent.get("heal_t") != null else 0.0) > 0.0:
		anim = "heal"
	if bool(ent.get("dead")):
		s3.visible = false
		blob.visible = false
		return
	s3.visible = float(ent.get("burrow_t") if ent.get("burrow_t") != null else 0.0) <= 0.0
	s3.frame = Sprites.char_frame(kind, anim, phase * (0.62 if moving else 0.35))
	_face(1.0 if aim.x >= 0.0 else -1.0)
	var k := Sprites.char_scale(kind)
	var sq := 1.0 + (sin(phase * TAU * 0.62) * 0.025 if moving else sin(t * 2.6) * 0.018)
	var bob := absf(sin(phase * PI * 0.62)) * 3.0 / T if moving else 0.0
	var crouch := 0.86 if bool(ent.get("crouching")) else 1.0
	s3.scale = Vector3(k / sq, k * sq * kv * crouch, 1)
	s3.position = Vector3(0, bob * kv, 0)
	s3.rotation.z = 0.0
	var a := 0.35 if float(ent.get("cloak_t") if ent.get("cloak_t") != null else 0.0) > 0.0 else 1.0
	var fl := float(ent.get("flash") if ent.get("flash") != null else 0.0)
	var c := Color(1, 1, 1, a).lerp(Color(2.4, 2.4, 2.4, a), clampf(fl, 0.0, 1.0) * 0.7)
	s3.modulate = c
	if a < 0.98:
		s3.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		s3.transparent = true
	else:
		s3.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		s3.transparent = true

func _enemy_labels() -> void:
	var e: Enemy = ent
	label.visible = e.show_bar_t > 0.0 or e.is_aware()
	if e.state == Enemy.S.CHASE or (e.icon_t > 0.0 and e.state != Enemy.S.PATROL):
		mark.text = "!"
		mark.modulate = DB.C_DANGER
		mark.visible = true
	elif e.state == Enemy.S.SUSPICIOUS or e.state == Enemy.S.SEARCH:
		mark.text = "?"
		mark.modulate = DB.C_LEGEND
		mark.visible = true
	else:
		mark.visible = false


## 걸음에 맞춘 뒤뚱거림·통통 튀기·기울기, 방향 바꿀 때 종이 뒤집기
func _juice(delta: float, vel: Vector2) -> void:
	if not s3.visible:
		return
	var sp := vel.length()
	var m := clampf(sp / 230.0, 0.0, 1.3)
	var dodging := float(ent.get("dodge_t") if ent.get("dodge_t") != null else 0.0) > 0.0
	# 종이 뒤집기: 원하는 방향(s3.flip_h)이 바뀌면 납작해졌다가 반대로 펴진다
	var want := s3.flip_h
	if want != shown_flip and turn_t <= 0.0:
		turn_t = TURN
		pending_flip = want
	var sx := 1.0
	if turn_t > 0.0:
		turn_t -= delta
		var p := 1.0 - maxf(turn_t, 0.0) / TURN
		if p >= 0.5:
			shown_flip = pending_flip
		sx = maxf(0.08, absf(cos(p * PI)))
	if shown_flip != s3.flip_h:
		s3.flip_h = shown_flip
		var kk := sheet_kind if sheet_kind != "" else kind
		var info := Sprites.char_info(kk)
		if not info.is_empty():
			var ax: float = info.anchor[0]
			if shown_flip:
				ax = float(info.frame[0]) - ax
			s3.offset.x = -ax
	# 걸음: 한 걸음마다 좌우로 기울고, 발 디딜 때 살짝 눌림
	if sp > 25.0 and not dodging:
		wp += delta * (2.4 + sp / T * 0.9)
	else:
		wp = lerpf(wp, roundf(wp), 1.0 - exp(-10.0 * delta))
	var hop := absf(sin(wp * PI))
	var waddle := sin(wp * PI) * 0.085 * minf(m, 1.0)
	var lean := clampf(-vel.x / T * 0.018, -0.13, 0.13)
	if dodging:
		lean *= 2.0
	s3.rotation.z += waddle + lean
	s3.position.y += hop * 0.07 * minf(m, 1.0)
	var squash := 1.0
	if m > 0.2 and hop < 0.25:
		squash = 1.0 - (0.25 - hop) * 0.28
	s3.scale.x *= sx * (2.0 - squash)
	s3.scale.y *= squash
	# 그림자: 뜰 때 작아짐
	blob.scale = Vector3.ONE * (1.0 - hop * 0.12 * minf(m, 1.0))
	last_hop = hop

# ── 물리 보간 (화면 주사율 ≠ 물리 60Hz 일 때 끊김 방지) ──
var _p0 := Vector2.ZERO
var _p1 := Vector2.ZERO
var _interp_ready := false

func _physics_process(_d: float) -> void:
	if not is_instance_valid(ent):
		return
	_p0 = _p1 if _interp_ready else ent.global_position
	_p1 = ent.global_position
	_interp_ready = true

func _smooth_pos() -> Vector2:
	if not _interp_ready or not is_instance_valid(ent):
		return ent.global_position
	if _p1.distance_squared_to(_p0) > 140.0 * 140.0:
		return _p1   # 순간이동은 그대로
	return _p0.lerp(_p1, Engine.get_physics_interpolation_fraction())
