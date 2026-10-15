class_name ModelChar
extends Node3D
## 통짜 3D 모델 캐릭터 (Meshy 등 AI 에셋: 뼈대 없음).
## 몸 전체를 절차적으로 움직인다: 조준 방향으로 돌기, 걸음마다 통통·뒤뚱, 앞으로 기울기, 구르기, 웅크리기, 반동.

const T := float(DB.TILE)
const HAMSTER := "res://assets/models/hamster_meshy.glb"

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

static func available() -> bool:
	return ResourceLoader.exists(HAMSTER)

static func load_model() -> Node3D:
	var m := (load(HAMSTER) as PackedScene).instantiate() as Node3D
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return m

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

func _process(delta: float) -> void:
	t += delta
	if not is_instance_valid(ent) or bool(ent.get("dead")):
		_death(delta)
		return
	var pos := ent.global_position
	var vel := (pos - last_pos) / maxf(delta, 0.001)
	last_pos = pos
	position = Vector3(pos.x / T, 0, pos.y / T)
	var sp := vel.length()
	var m := clampf(sp / 230.0, 0.0, 1.3)
	# 조준 방향으로 몸 돌리기 (모델 정면 = +Z)
	var dir: Vector2 = ent.get("aim_dir") if ent.get("aim_dir") != null else vel
	if dir.length() > 0.01:
		yaw = lerp_angle(yaw, atan2(dir.x, dir.y), 1.0 - exp(-16.0 * delta))
	pivot.rotation.y = yaw
	# 걸음: 통통 튀고 좌우로 뒤뚱, 진행 방향으로 기울기
	var dodge := _f("dodge_t")
	if sp > 25.0 and dodge <= 0.0:
		wp += delta * (2.6 + sp / T * 0.95)
	else:
		wp = lerpf(wp, roundf(wp), 1.0 - exp(-10.0 * delta))
	var hop := absf(sin(wp * PI))
	var mm := minf(m, 1.0)
	var lean := 0.16 * mm
	var waddle := sin(wp * PI) * 0.11 * mm
	var squash := 1.0
	if mm > 0.2 and hop < 0.25:
		squash = 1.0 - (0.25 - hop) * 0.3
	var breathe := sin(t * 2.4) * 0.012 * (1.0 - mm)
	var rec := minf(_f("recoil"), 14.0)
	var rx := lean - rec * 0.012
	if dodge > 0.0:
		rx += (1.0 - dodge / Player.DODGE_TIME) * TAU   # 앞구르기
	if _f("melee_anim") > 0.0:
		rx += sin(_f("melee_anim") / 0.22 * PI) * 0.35
	body.rotation = Vector3(rx, 0, waddle)
	body.position = Vector3(0, hop * 0.08 * mm + (0.25 if dodge > 0.0 else 0.0) * sin((1.0 - dodge / Player.DODGE_TIME) * PI), -rec * 0.004)
	var crouch := 0.8 if bool(ent.get("crouching")) else 1.0
	var pop := 1.0 + clampf(_f("flash"), 0.0, 1.0) * 0.12
	body.scale = Vector3((2.0 - squash) * pop, squash * crouch * pop * (1.0 + breathe), (2.0 - squash) * pop)
	model.visible = _f("burrow_t") <= 0.0
	_set_alpha(0.35 if _f("cloak_t") > 0.0 else 1.0)

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
