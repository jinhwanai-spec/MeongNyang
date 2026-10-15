class_name ModelChar
extends Node3D
## 3D 모델 캐릭터 (Meshy AI 햄스터).
## 뼈대 넣은 모델이면 대기·걷기·달리기 애니메이션을 이동 속도에 맞춰 재생하고(뒤로 걸으면 거꾸로),
## 그 위에 조준 방향 회전·기울기·반동·구르기·웅크리기를 얹는다. 뼈대가 없으면 몸 전체를 통통 튀긴다.

const T := float(DB.TILE)
const HAMSTER := "res://assets/models/hamster_meshy.glb"
const HAMSTER_RIG := "res://assets/models/hamster_rigged.glb"
const WALK_REF := 215.0    # 이 속도에서 걷기 애니메이션 배속 WALK_RATE
const WALK_RATE := 1.75
const RUN_REF := 305.0
const RUN_RATE := 2.1

var ent: Node2D
var pivot: Node3D
var body: Node3D
var model: Node3D
var meshes: Array[MeshInstance3D] = []
var yaw := 0.0
var wp := 0.0
var t := 0.0
var last_pos := Vector2.ZERO
var dead_t := -1.0
var label: Label3D
var _alpha := 1.0
var base_scale := 0.95
var ap: AnimationPlayer
var anim_now := ""
var sp_s := 0.0

static func available() -> bool:
	return ResourceLoader.exists(HAMSTER) or ResourceLoader.exists(HAMSTER_RIG)

## play_idle: 메뉴·대기실처럼 혼자 서 있는 모델이면 대기 애니메이션을 바로 재생
static func load_model(play_idle: bool = false) -> Node3D:
	var path := HAMSTER_RIG if ResourceLoader.exists(HAMSTER_RIG) else HAMSTER
	var m := (load(path) as PackedScene).instantiate() as Node3D
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var a := anim_player(m)
	if a and play_idle and a.has_animation("idle"):
		a.play("idle")
		a.seek(randf() * 2.0)
	return m

static func anim_player(m: Node) -> AnimationPlayer:
	var list := m.find_children("*", "AnimationPlayer", true, false)
	if list.is_empty():
		return null
	var a := list[0] as AnimationPlayer
	for n in a.get_animation_list():
		a.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	return a

func setup(e: Node2D) -> void:
	ent = e
	pivot = Node3D.new()
	add_child(pivot)
	body = Node3D.new()
	pivot.add_child(body)
	model = load_model()
	model.scale = Vector3.ONE * base_scale
	body.add_child(model)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		meshes.append(mi)
	ap = anim_player(model)
	if ap:
		ap.play("idle")
	add_child(CharBillboard.blob_shadow(0.8))
	if e is RemotePlayer:
		label = Label3D.new()
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.fixed_size = true
		label.pixel_size = 0.0006
		label.font = FX.font()
		label.font_size = 22
		label.outline_size = 8
		label.text = (e as RemotePlayer).nickname
		label.modulate = Color("#9CFFB4")
		label.position = Vector3(0, 1.45, 0)
		add_child(label)
	last_pos = e.global_position
	position = Vector3(last_pos.x / T, 0, last_pos.y / T)
	var a: Vector2 = e.get("aim_dir") if e.get("aim_dir") != null else Vector2(0, 1)
	yaw = atan2(a.x, a.y)

func _f(n: String) -> float:
	var v = ent.get(n)
	return float(v) if v != null else 0.0

func _set_alpha(a: float) -> void:
	if is_equal_approx(a, _alpha):
		return
	_alpha = a
	for mi in meshes:
		mi.transparency = 1.0 - a

func _enter_tree() -> void:
	process_physics_priority = 100   # 캐릭터가 움직인 뒤에 기록

func _process(delta: float) -> void:
	t += delta
	if not is_instance_valid(ent) or bool(ent.get("dead")):
		_death(delta)
		return
	var pos := _smooth_pos()
	var vel := (pos - last_pos) / maxf(delta, 0.001)
	last_pos = pos
	position = Vector3(pos.x / T, 0, pos.y / T)
	# 실제 이동 속도 (캐릭터 몸의 velocity가 있으면 그걸로 — 덜 떨린다)
	var v2: Vector2 = ent.velocity if ent is CharacterBody2D else vel
	sp_s = lerpf(sp_s, v2.length(), 1.0 - exp(-12.0 * delta))
	var sp := sp_s
	var m := clampf(sp / 230.0, 0.0, 1.3)
	# 조준 방향으로 몸 돌리기 (모델 정면 = +Z)
	var dir: Vector2 = ent.get("aim_dir") if ent.get("aim_dir") != null else v2
	if dir.length() > 0.01:
		yaw = lerp_angle(yaw, atan2(dir.x, dir.y), 1.0 - exp(-18.0 * delta))
	pivot.rotation.y = yaw
	var dodge := _f("dodge_t")
	var mm := minf(m, 1.0)
	var hop := 0.0
	var waddle := 0.0
	if ap:
		_animate(v2, sp, dodge)
	else:
		# 뼈대 없는 모델: 몸 전체를 통통·뒤뚱
		if sp > 25.0 and dodge <= 0.0:
			wp += delta * (2.6 + sp / T * 0.95)
		else:
			wp = lerpf(wp, roundf(wp), 1.0 - exp(-10.0 * delta))
		hop = absf(sin(wp * PI)) * 0.08 * mm
		waddle = sin(wp * PI) * 0.11 * mm
	# 이동 방향 쪽으로 몸 기울기 (조준 방향 기준으로 앞/옆)
	var fwd := Vector2(sin(yaw), cos(yaw))
	var side := Vector2(cos(yaw), -sin(yaw))
	var lean_f := clampf(v2.dot(fwd) / 300.0, -1.0, 1.0) * 0.10
	var lean_s := clampf(v2.dot(side) / 300.0, -1.0, 1.0) * 0.08
	var rec := minf(_f("recoil"), 14.0)
	var rx := lean_f - rec * 0.012
	if dodge > 0.0:
		rx += (1.0 - dodge / Player.DODGE_TIME) * TAU   # 앞구르기
	if _f("melee_anim") > 0.0:
		rx += sin(_f("melee_anim") / 0.22 * PI) * 0.35
	body.rotation = Vector3(rx, 0, waddle - lean_s)
	body.position = Vector3(0, hop + (0.25 if dodge > 0.0 else 0.0) * sin((1.0 - dodge / Player.DODGE_TIME) * PI), -rec * 0.004)
	var crouch := 0.8 if bool(ent.get("crouching")) else 1.0
	var pop := 1.0 + clampf(_f("flash"), 0.0, 1.0) * 0.12
	body.scale = Vector3(pop, crouch * pop, pop)
	model.visible = _f("burrow_t") <= 0.0
	_set_alpha(0.35 if _f("cloak_t") > 0.0 else 1.0)

## 속도에 맞춰 대기/걷기/달리기, 발이 미끄러지지 않게 배속 조절, 뒤로 걸으면 거꾸로
func _animate(v2: Vector2, sp: float, dodge: float) -> void:
	var want := "idle"
	var rate := 1.0
	if dodge > 0.0:
		want = "run"
		rate = RUN_RATE * 1.4
	elif sp > 265.0:
		want = "run"
		rate = RUN_RATE * sp / RUN_REF
	elif sp > 30.0:
		want = "walk"
		rate = WALK_RATE * maxf(sp, 90.0) / WALK_REF
	if want != "idle" and dodge <= 0.0:
		var fwd := Vector2(sin(yaw), cos(yaw))
		if v2.normalized().dot(fwd) < -0.35:
			rate = -rate   # 뒷걸음질
	if want != anim_now:
		ap.play(want, 0.14)
		anim_now = want
	ap.speed_scale = clampf(rate, -3.5, 3.5) if want != "idle" else 1.0

func _death(delta: float) -> void:
	if dead_t < 0.0:
		dead_t = 0.0
		if label:
			label.visible = false
	dead_t += delta
	var k := clampf(dead_t / 0.35, 0.0, 1.0)
	body.rotation = Vector3(0, 0, -k * PI * 0.5)
	body.position.y = k * 0.3
	if not is_instance_valid(ent) and dead_t > 2.0:
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
	if not _interp_ready or not is_instance_valid(ent):
		return ent.global_position
	if _p1.distance_squared_to(_p0) > 140.0 * 140.0:
		return _p1   # 순간이동은 그대로
	return _p0.lerp(_p1, Engine.get_physics_interpolation_fraction())
