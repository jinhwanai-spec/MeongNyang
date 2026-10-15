class_name EnemyModel
extends Node3D
## 3D 고양이 적 (Meshy AI 모델 · 사람형 뼈대 · Meshy 애니메이션).
## Enemy 상태를 그대로 따라: 몸 방향(조준·이동), 대기/걷기/달리기(속도에 맞춘 배속),
## 공격 동작(예비동작 끝에 맞춰 휘두르기), 맞으면 움찔 + 하얗게 번쩍, 죽으면 쓰러지는 동작.
## 오른손에 들고 있는 무기(30종 중 하나)를 3D 모델로 쥐고 다닌다.
## "!"·"?" 경계 표시와 이름표는 머리 위 3D 글자.

const T := float(DB.TILE)
## 게임 속 키(타일). 햄스터 ≈ 1.19
const HEIGHT := {"hyena": 1.15, "bulldog": 1.35, "cat": 1.15}
const SHADOW := {"hyena": 0.8, "bulldog": 1.0, "cat": 0.8}
const WALK_RATE := 1.25
const RUN_RATE := 1.35
## 애니메이션 이름 찾기 (Meshy 동작 이름 일부)
const ANIMS := {
	"idle": ["Combat_Stance", "Idle"],
	"walk": ["Walk_Forward_While_Shooting", "Walk_Fight_Forward", "Walking"],
	"run": ["Rifle_Charge", "Standard_Forward_Charge", "Running"],
	"attack": ["Heavy_Hammer_Swing", "Attack"],
	"hit": ["Hit_Reaction"],
	"death": ["Shot_and_Fall_Forward", "Dead"],
}

var ent: Enemy
var type := "hyena"
var pivot: Node3D
var body: Node3D
var model: Node3D
var meshes: Array[MeshInstance3D] = []
var ap: AnimationPlayer
var names := {}
var anim_now := ""
var lock_t := 0.0          # 공격·피격 동작 중엔 이동 애니메이션으로 안 바꿈
var yaw := 0.0
var t := 0.0
var sp_s := 0.0
var dead_t := -1.0
var height := 1.15
var label: Label3D
var mark: Label3D
var flash_mat: StandardMaterial3D
var _flash_on := false
var _prev_windup := 0.0
var _prev_flash := 0.0
var _recoil := 0.0
var weapon_root: Node3D     # 손 위치를 따라감
var weapon_mesh: Node3D
var weapon_id := ""

static func path_for(tp: String) -> String:
	return "res://assets/models/enemy2_%s.glb" % tp

static func available(tp: String) -> bool:
	return ResourceLoader.exists(path_for(tp))

static func find_anim(a: AnimationPlayer, key: String) -> String:
	if a == null:
		return ""
	for want in ANIMS.get(key, []):
		for n in a.get_animation_list():
			if str(n).contains(want):
				return n
	return ""

static func load_model(tp: String, play_idle: bool = false) -> Node3D:
	var m := (load(path_for(tp)) as PackedScene).instantiate() as Node3D
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var list := m.find_children("*", "AnimationPlayer", true, false)
	if not list.is_empty():
		var a := list[0] as AnimationPlayer
		for n in a.get_animation_list():
			var an := a.get_animation(n)
			an.loop_mode = Animation.LOOP_NONE if (str(n).contains("Fall") or str(n).contains("Dead") or str(n).contains("Hit") or str(n).contains("Attack") or str(n).contains("Swing") or str(n).contains("Shot")) and not str(n).contains("Walk") else Animation.LOOP_LINEAR
		var idle := find_anim(a, "idle")
		if play_idle and idle != "":
			a.play(idle)
			a.seek(randf() * 1.5)
	var k := float(HEIGHT.get(tp, 1.15)) / _native_height(m)
	m.scale = Vector3.ONE * k
	return m

static func _native_height(m: Node3D) -> float:
	var h := 0.0
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		h = maxf(h, (mi as MeshInstance3D).get_aabb().end.y)
	return maxf(h, 0.1)

## 무기 모델 (assets/models/weapons/<id>.glb, 앞 = +Z, 손잡이 = 원점)
static func weapon_scene(wid: String) -> Node3D:
	var p := "res://assets/models/weapons/%s.glb" % wid
	if wid == "" or not ResourceLoader.exists(p):
		return null
	var w := (load(p) as PackedScene).instantiate() as Node3D
	for mi in w.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return w

func setup(e: Enemy) -> void:
	ent = e
	type = e.type
	height = float(HEIGHT.get(type, 1.15))
	pivot = Node3D.new()
	add_child(pivot)
	body = Node3D.new()
	pivot.add_child(body)
	model = load_model(type)
	body.add_child(model)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		meshes.append(mi)
	var list := model.find_children("*", "AnimationPlayer", true, false)
	if not list.is_empty():
		ap = list[0]
		for k in ANIMS:
			names[k] = find_anim(ap, k)
		if names.idle != "":
			ap.play(names.idle)
			ap.seek(randf() * 1.5)
			anim_now = "idle"
	_attach_weapon(e.weapon)
	flash_mat = StandardMaterial3D.new()
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	flash_mat.albedo_color = Color(1, 1, 1, 0)
	add_child(CharBillboard.blob_shadow(float(SHADOW.get(type, 0.8))))
	_make_labels(str(e.data.name), e.data.name_color)
	position = Vector3(e.global_position.x / T, 0, e.global_position.y / T)
	yaw = atan2(e.facing, 0.25)
	pivot.rotation.y = yaw

func _attach_weapon(wid: String) -> void:
	weapon_id = wid
	var sk_list := model.find_children("*", "Skeleton3D", true, false)
	if sk_list.is_empty():
		return
	var sk := sk_list[0] as Skeleton3D
	var bi := sk.find_bone("RightHand")
	if bi < 0:
		return
	var ba := BoneAttachment3D.new()
	ba.bone_name = "RightHand"
	sk.add_child(ba)
	weapon_root = Node3D.new()
	ba.add_child(weapon_root)
	weapon_mesh = weapon_scene(wid)
	if weapon_mesh:
		weapon_root.add_child(weapon_mesh)
		for mi in weapon_mesh.find_children("*", "MeshInstance3D", true, false):
			meshes.append(mi)

## 손 위치는 뼈를 따라가고, 방향은 몸 정면 기준으로 (총은 앞으로, 근접 무기는 위로 들고 있다가 휘두를 때 내려침)
func _aim_weapon(delta: float) -> void:
	if weapon_root == null:
		return
	var fwd := pivot.global_basis.orthonormalized()
	var tilt := Basis()
	if DB.MELEES.has(weapon_id):
		var raise := 1.05   # 위로 세워 듦
		if ent and is_instance_valid(ent):
			if ent.windup > 0.0 and ent.windup_total > 0.0:
				raise = 1.05 + 0.5 * (1.0 - ent.windup / ent.windup_total)   # 뒤로 젖힘
			if ent.lunge > 0.0:
				raise = -0.35   # 내려침
		tilt = Basis(Vector3.RIGHT, -raise)
	else:
		tilt = Basis(Vector3.RIGHT, _recoil * 0.35)
	weapon_root.global_basis = (fwd * tilt).scaled(Vector3.ONE * 0.95)

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
	label.position.y = height + 0.2
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
	position = Vector3(pos.x / T, 0, pos.y / T)
	# 화면 밖 먼 고양이는 그리기·애니메이션 쉬기 (성능)
	var far := false
	var r: Raid = ent.raid
	if r and r.player:
		far = pos.distance_squared_to(r.player.global_position) > 1100.0 * 1100.0
	if far != not pivot.visible:
		pivot.visible = not far
		if ap:
			ap.active = not far
	if far:
		_labels()
		return
	var v2: Vector2 = ent.velocity
	sp_s = lerpf(sp_s, v2.length(), 1.0 - exp(-10.0 * delta))
	var sp := sp_s
	# 몸 방향: 싸우는 중이면 조준 방향, 아니면 걷는 방향, 서 있으면 두리번(facing) 쪽
	var engaged := ent.windup > 0.0 or ent.lunge > 0.0 or ent.charge_t > 0.0 or ent._burst > 0 \
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
	lock_t = maxf(0.0, lock_t - delta)
	# 공격: 예비동작이 시작되면 휘두르는 동작을 시작 → 예비동작 끝에 타격 순간이 오도록 배속
	if ent.windup > 0.0 and _prev_windup <= 0.0 and not ent.gunner and names.get("attack", "") != "" and not ent._charge_pending:
		var an: Animation = ap.get_animation(names.attack)
		var hit_at := an.length * 0.42
		ap.play(names.attack, 0.08)
		ap.speed_scale = clampf(hit_at / maxf(ent.windup_total, 0.1), 0.6, 4.0)
		anim_now = "attack"
		lock_t = ent.windup_total + 0.35
	# 총 쏜 순간: 반동
	if ent.shot_flash > 0.1:
		_recoil = 1.0
	_recoil = maxf(0.0, _recoil - delta * 6.0)
	# 맞았을 때: 움찔
	if ent.flash > 0.9 and _prev_flash < 0.9 and lock_t <= 0.0 and names.get("hit", "") != "":
		ap.play(names.hit, 0.05)
		ap.speed_scale = 2.2
		anim_now = "hit"
		lock_t = 0.3
	_prev_flash = ent.flash
	_prev_windup = ent.windup
	if ap and lock_t <= 0.0:
		_animate(v2, sp, ent.stun > 0.0)
	# 몸 전체 연출 (기울기·찌르기·기절 비틀거림·크기 펄스)
	var fwd := Vector2(sin(yaw), cos(yaw))
	var rx := clampf(v2.dot(fwd) / 300.0, -1.0, 1.0) * 0.07 - _recoil * 0.12
	var rz := 0.0
	var fz := -_recoil * 0.06
	if ent.lunge > 0.0:
		fz += 0.28 * ent.lunge / 0.25
	if ent.charge_t > 0.0:
		rx += 0.25
	if ent.windup > 0.0 and ent._charge_pending:
		rz += sin(t * 60.0) * 0.04
	if ent.stun > 0.0:
		rz += sin(t * 9.0) * 0.16
		rx += sin(t * 6.3) * 0.08
	body.rotation = Vector3(rx, 0, rz)
	body.position = Vector3(0, 0, fz)
	var pop := 1.0 + clampf(ent.flash, 0.0, 1.0) * 0.08
	body.scale = Vector3.ONE * pop
	_aim_weapon(delta)
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
	var nm: String = names.get(want, "")
	if nm == "":
		return
	if want != anim_now:
		ap.play(nm, 0.18)
		anim_now = want
	ap.speed_scale = clampf(rate, -3.0, 3.0)

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
	mark.position.y = height + 0.5 + absf(sin(t * 8.0)) * 0.05

func _set_flash(a: float) -> void:
	if a > 0.02:
		flash_mat.albedo_color = Color(1, 1, 1, a)
		if not _flash_on:
			for mi in meshes:
				if is_instance_valid(mi):
					mi.material_overlay = flash_mat
			_flash_on = true
	elif _flash_on:
		for mi in meshes:
			if is_instance_valid(mi):
				mi.material_overlay = null
		_flash_on = false

## 쓰러지기: 쓰러지는 동작 → 잠깐 누워 있다가 바닥으로 스르르
func _death(delta: float) -> void:
	if dead_t < 0.0:
		dead_t = 0.0
		label.visible = false
		mark.visible = false
		_set_flash(0.9)
		if ap and names.get("death", "") != "":
			ap.play(names.death, 0.06)
			ap.speed_scale = 1.6
		else:
			body.rotation.z = PI * 0.5
		# 손에 든 무기는 떨어뜨림 (바닥에 드랍 상자가 대신 생김)
		if weapon_root:
			weapon_root.visible = false
	dead_t += delta
	_set_flash(maxf(0.0, 0.9 - dead_t * 4.0))
	body.rotation.x = 0.0
	body.position = Vector3.ZERO
	if dead_t > 2.6:
		var s := clampf((dead_t - 2.6) / 0.6, 0.0, 1.0)
		position.y = -s * 0.9
	if dead_t > 3.2:
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
