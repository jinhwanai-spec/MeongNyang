class_name EnemyModel
extends Node3D
## 3D 고양이 적 (Meshy AI 모델).
## Enemy 상태를 그대로 따라: 몸 방향(조준·이동), 대기/걷기/달리기 애니메이션(속도에 맞춘 배속),
## 공격 예비동작·내려치기·물기 돌진·저격 반동, 기절 비틀거림, 맞으면 하얗게 번쩍, 죽으면 옆으로 쓰러짐.
## "!"·"?" 경계 표시와 이름표는 머리 위 3D 글자.

const T := float(DB.TILE)
## 모델은 블렌더에서 키 1.0으로 맞춰 둠 → 종류별 실제 키(타일)
const HEIGHT := {"hyena": 1.2, "bulldog": 1.5, "cat": 1.25}
const SHADOW := {"hyena": 0.9, "bulldog": 1.15, "cat": 0.9}
const WALK_RATE := 1.6   # 순찰 속도에서 걷기 애니메이션 배속
const RUN_RATE := 1.9    # 추격 속도에서 달리기 배속

var ent: Enemy
var type := "hyena"
var pivot: Node3D
var body: Node3D
var model: Node3D
var meshes: Array[MeshInstance3D] = []
var ap: AnimationPlayer
var anim_now := ""
var yaw := 0.0
var t := 0.0
var wp := 0.0
var sp_s := 0.0
var dead_t := -1.0
var last_pos := Vector2.ZERO
var height := 1.3
var label: Label3D
var mark: Label3D
var flash_mat: StandardMaterial3D
var _flash_on := false
var _prev_windup := 0.0
var _recoil := 0.0
var _fall_side := 1.0

static func path_for(tp: String) -> String:
	return "res://assets/models/enemy_%s.glb" % tp

static func available(tp: String) -> bool:
	return ResourceLoader.exists(path_for(tp))

static func load_model(tp: String, play_idle: bool = false) -> Node3D:
	var m := (load(path_for(tp)) as PackedScene).instantiate() as Node3D
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var a := ModelChar.anim_player(m)
	if a and play_idle and a.has_animation("idle"):
		a.play("idle")
		a.seek(randf() * 2.0)
	return m

func setup(e: Enemy) -> void:
	ent = e
	type = e.type
	height = float(HEIGHT.get(type, 1.3))
	pivot = Node3D.new()
	add_child(pivot)
	body = Node3D.new()
	pivot.add_child(body)
	model = load_model(type)
	model.scale = Vector3.ONE * height
	body.add_child(model)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		meshes.append(mi)
	ap = ModelChar.anim_player(model)
	if ap and ap.has_animation("idle"):
		ap.play("idle")
		ap.seek(randf() * 2.0)
	flash_mat = StandardMaterial3D.new()
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	flash_mat.albedo_color = Color(1, 1, 1, 0)
	add_child(CharBillboard.blob_shadow(float(SHADOW.get(type, 0.95))))
	_make_labels(str(e.data.name), e.data.name_color)
	last_pos = e.global_position
	position = Vector3(last_pos.x / T, 0, last_pos.y / T)
	yaw = atan2(e.facing, 0.25)
	pivot.rotation.y = yaw

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
	label.position.y = height + 0.15
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

func _enter_tree() -> void:
	process_physics_priority = 100   # 적이 움직인 뒤에 기록

func _process(delta: float) -> void:
	t += delta
	if not is_instance_valid(ent) or ent.dead:
		_death(delta)
		return
	var pos := _smooth_pos()
	last_pos = pos
	position = Vector3(pos.x / T, 0, pos.y / T)
	var v2: Vector2 = ent.velocity
	sp_s = lerpf(sp_s, v2.length(), 1.0 - exp(-10.0 * delta))
	var sp := sp_s
	# 몸 방향: 싸우는 중이면 조준 방향, 아니면 걷는 방향, 서 있으면 두리번(facing) 쪽
	var engaged := ent.windup > 0.0 or ent.lunge > 0.0 or ent.charge_t > 0.0 \
		or (ent.state == Enemy.S.CHASE and (ent.sees_player or ent.puppet))
	var dir := Vector2.ZERO
	var turn := 9.0
	if ent.charge_t > 0.0:
		dir = ent.charge_dir
		turn = 20.0
	elif engaged:
		dir = ent.aim
		turn = 14.0
	elif sp > 25.0:
		dir = v2
	elif signf(sin(yaw)) != signf(ent.facing) and absf(sin(yaw)) > 0.15:
		dir = Vector2(ent.facing, 0.35)
		turn = 5.0
	if dir.length() > 0.01:
		yaw = lerp_angle(yaw, atan2(dir.x, dir.y), 1.0 - exp(-turn * delta))
	pivot.rotation.y = yaw
	var stunned := ent.stun > 0.0
	var hop := 0.0
	var waddle := 0.0
	if ap:
		_animate(v2, sp, stunned)
	else:
		# 뼈대 없는 모델: 몸 전체를 통통·뒤뚱
		var mm := clampf(sp / 200.0, 0.0, 1.0)
		if sp > 25.0:
			wp += delta * (2.4 + sp / T * 0.9)
		else:
			wp = lerpf(wp, roundf(wp), 1.0 - exp(-10.0 * delta))
		hop = absf(sin(wp * PI)) * 0.07 * mm
		waddle = sin(wp * PI) * 0.09 * mm
	# 공격 동작 (몸 전체에 얹음 — 모델 정면 = +Z, rotation.x 양수 = 앞으로 숙임)
	var rx := 0.0
	var rz := waddle
	var fz := 0.0
	var squash := 1.0
	if ent.windup > 0.0 and ent.windup_total > 0.0:
		var k := 1.0 - ent.windup / ent.windup_total
		match type:
			"bulldog":
				if not ent._charge_pending:
					rx = -0.38 * k            # 망치 들고 뒤로 젖힘
					squash = 1.0 + 0.06 * k
				else:
					rx = 0.22 * k             # 돌진 준비: 웅크림 + 부들부들
					squash = 1.0 - 0.12 * k
					rz += sin(t * 60.0) * 0.04 * k
			"hyena":
				rx = 0.18 * k
				squash = 1.0 - 0.16 * k   # 엉덩이 들썩이며 웅크림
				rz += sin(t * 38.0) * 0.03 * k
			"cat":
				squash = 1.0 - 0.06 * k   # 저격 자세
	if ent.lunge > 0.0:
		match type:
			"bulldog":
				var kb := ent.lunge / 0.25
				rx = 0.5 * kb             # 내려치기
				fz = 0.25 * kb
				squash = 1.0 - 0.1 * kb
			_:
				var kh := ent.lunge / 0.18
				rx = 0.3 * kh             # 물기 돌진
				fz = 0.35 * kh
	if ent.charge_t > 0.0:
		rx = 0.28
	# 저격수: 쏘는 순간 반동
	if type == "cat" and _prev_windup > 0.0 and ent.windup <= 0.0:
		_recoil = 1.0
	_prev_windup = ent.windup
	_recoil = maxf(0.0, _recoil - delta * 5.0)
	rx -= _recoil * 0.22
	fz -= _recoil * 0.12
	# 이동 방향 쪽으로 살짝 기울기
	var fwd := Vector2(sin(yaw), cos(yaw))
	rx += clampf(v2.dot(fwd) / 300.0, -1.0, 1.0) * 0.08
	if stunned:
		rz += sin(t * 9.0) * 0.16
		rx += sin(t * 6.3) * 0.08
	body.rotation = Vector3(rx, 0, rz)
	body.position = Vector3(0, hop, fz)
	var pop := 1.0 + clampf(ent.flash, 0.0, 1.0) * 0.1
	body.scale = Vector3(pop / sqrt(squash), squash * pop, pop / sqrt(squash))
	_set_flash(clampf(ent.flash, 0.0, 1.0) * 0.75)
	_labels()

## 속도에 맞춰 대기/걷기/달리기, 발이 미끄러지지 않게 배속 조절
func _animate(v2: Vector2, sp: float, stunned: bool) -> void:
	var walk_sp := float(ent.data.speed)
	var run_sp := float(ent.data.chase_speed)
	var want := "idle"
	var rate := 1.0
	if stunned:
		rate = 0.4
	elif ent.charge_t > 0.0:
		want = "run"
		rate = RUN_RATE * 1.5
	elif sp > (walk_sp + run_sp) * 0.5:
		want = "run"
		rate = RUN_RATE * sp / run_sp
	elif sp > 25.0:
		want = "walk"
		rate = WALK_RATE * maxf(sp, walk_sp * 0.4) / walk_sp
	if want != "idle" and ent.charge_t <= 0.0:
		var fwd := Vector2(sin(yaw), cos(yaw))
		if v2.normalized().dot(fwd) < -0.35:
			rate = -rate   # 뒷걸음질 (조준하며 물러날 때)
	if not ap.has_animation(want):
		want = "idle"
	if want != anim_now:
		ap.play(want, 0.18)
		anim_now = want
	ap.speed_scale = clampf(rate, -3.5, 3.5)

func _labels() -> void:
	label.visible = ent.show_bar_t > 0.0 or ent.is_aware()
	if ent.state == Enemy.S.CHASE or (ent.icon_t > 0.0 and ent.state != Enemy.S.PATROL):
		mark.text = "!"
		mark.modulate = DB.C_DANGER
		mark.visible = true
	elif ent.state == Enemy.S.SUSPICIOUS or ent.state == Enemy.S.SEARCH:
		mark.text = "?"
		mark.modulate = DB.C_LEGEND
		mark.visible = true
	else:
		mark.visible = false
	mark.position.y = height + 0.45 + absf(sin(t * 8.0)) * 0.05

func _set_flash(a: float) -> void:
	if a > 0.02:
		flash_mat.albedo_color = Color(1, 1, 1, a)
		if not _flash_on:
			for mi in meshes:
				mi.material_overlay = flash_mat
			_flash_on = true
	elif _flash_on:
		for mi in meshes:
			mi.material_overlay = null
		_flash_on = false

## 쓰러지기: 옆으로 픽 → 잠깐 누워 있다가 바닥으로 스르르
func _death(delta: float) -> void:
	if dead_t < 0.0:
		dead_t = 0.0
		label.visible = false
		mark.visible = false
		_fall_side = -1.0 if randf() < 0.5 else 1.0
		if ap:
			ap.speed_scale = 0.0
		_set_flash(0.8)
	dead_t += delta
	_set_flash(maxf(0.0, 0.8 - dead_t * 4.0))
	var k := clampf(dead_t / 0.32, 0.0, 1.0)
	k = 1.0 - (1.0 - k) * (1.0 - k)
	body.rotation = Vector3(0, 0, _fall_side * k * PI * 0.5)
	body.position = Vector3(0, k * 0.25 * height * 0.6, 0)
	body.scale = Vector3.ONE
	if dead_t > 2.4:
		var s := clampf((dead_t - 2.4) / 0.6, 0.0, 1.0)
		position.y = -s * 0.8
	if dead_t > 3.0:
		queue_free()

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
	if not _interp_ready:
		return ent.global_position
	if _p1.distance_squared_to(_p0) > 140.0 * 140.0:
		return _p1
	return _p0.lerp(_p1, Engine.get_physics_interpolation_fraction())
