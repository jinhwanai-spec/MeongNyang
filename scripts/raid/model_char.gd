class_name ModelChar
extends Node3D
## 3D 모델 캐릭터 (Meshy AI 햄스터).
## 뼈대 넣은 모델이면 대기·걷기·달리기 애니메이션을 이동 속도에 맞춰 재생하고(뒤로 걸으면 거꾸로),
## 그 위에 조준 방향 회전·기울기·반동·구르기·웅크리기를 얹는다. 뼈대가 없으면 몸 전체를 통통 튀긴다.

const T := float(DB.TILE)
const HAMSTER := "res://assets/models/hamster_meshy.glb"
const HAMSTER_RIG := "res://assets/models/hamster_rigged.glb"
## 총을 떼어 낸 햄스터 (손에 실제 무기 모델을 쥐여 준다)
const HAMSTER_NOGUN := "res://assets/models/hamster_nogun.scn"
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
var frozen := false    # 탈출 연출 중: 위치를 연출(트윈)에 맡긴다

static func available() -> bool:
	return ResourceLoader.exists(HAMSTER) or ResourceLoader.exists(HAMSTER_RIG)

## play_idle: 메뉴·대기실처럼 혼자 서 있는 모델이면 대기 애니메이션을 바로 재생
static func load_model(play_idle: bool = false) -> Node3D:
	var path := HAMSTER_RIG if ResourceLoader.exists(HAMSTER_RIG) else HAMSTER
	if ResourceLoader.exists(HAMSTER_NOGUN):
		path = HAMSTER_NOGUN
	var m := (load(path) as PackedScene).instantiate() as Node3D
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var a := anim_player(m)
	if a and play_idle and a.has_animation("idle"):
		a.play("idle")
		a.seek(randf() * 2.0)
	return m

## 메뉴·대기실용 가만히 서 있는 모델에 총·갑옷을 쥐여 준다
static func arm_static(m: Node3D, wid: String, mods: Dictionary = {}, helmet: String = "", vest: String = "") -> void:
	var sk := m.find_children("*", "Skeleton3D", true, false)
	if sk.is_empty() or not ResourceLoader.exists(HAMSTER_NOGUN):
		return
	var skel0 := sk[0] as Skeleton3D
	if skel0.find_bone("chest") >= 0:
		var ba := BoneAttachment3D.new()
		ba.bone_name = "chest"
		skel0.add_child(ba)
		if DB.WEAPONS.has(wid):
			var hold := Node3D.new()
			hold.position = Vector3(-0.17, -0.02, 0.36)
			hold.rotation = Vector3(0.05, 0.3, 0)
			ba.add_child(hold)
			var g := EnemyModel.weapon_scene(wid)
			if g:
				ProcModels.attach_mods(g, wid, mods)
				hold.add_child(g)
		if vest != "" and DB.ITEMS.has(vest):
			var v := ProcModels.vest(int(DB.ITEMS[vest].tier))
			v.position = Vector3(0, -0.03, -0.07)
			ba.add_child(v)
	if helmet != "" and DB.ITEMS.has(helmet) and skel0.find_bone("head") >= 0:
		var bh := BoneAttachment3D.new()
		bh.bone_name = "head"
		skel0.add_child(bh)
		var h := ProcModels.helmet(int(DB.ITEMS[helmet].tier))
		h.position = Vector3(0, 0.3, 0.02)
		h.scale = Vector3.ONE * 1.28
		bh.add_child(h)

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
	_setup_gear()
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
	if frozen:
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
	_update_gear(delta)
	_update_buff_fx()

# ── 장비: 손에 든 총 / 근접 무기 / 헬멧 / 조끼 ────────
var skel: Skeleton3D
var chest_att: Node3D
var head_att: Node3D
var gun_hold: Node3D
var gun_node: Node3D
var gun_key := ""
var melee_hold: Node3D
var melee_node: Node3D
var melee_key := ""
var back_hold: Node3D
var pack_node: Node3D
var vest_node: Node3D
var vest_key := ""
var helmet_node: Node3D
var helmet_key := ""
var laser: MeshInstance3D

func _setup_gear() -> void:
	if not ResourceLoader.exists(HAMSTER_NOGUN):
		return
	var sk := model.find_children("*", "Skeleton3D", true, false)
	if sk.is_empty():
		return
	skel = sk[0]
	chest_att = _bone_att("chest")
	head_att = _bone_att("head")
	if chest_att == null:
		return
	gun_hold = Node3D.new()
	gun_hold.position = Vector3(-0.17, -0.02, 0.36)
	gun_hold.rotation = Vector3(0.05, 0.3, 0)
	chest_att.add_child(gun_hold)
	melee_hold = Node3D.new()
	melee_hold.position = Vector3(-0.19, 0.0, 0.38)
	chest_att.add_child(melee_hold)
	# 등에 멘 배낭: 가방이 찰수록 커진다 (전리품을 많이 들었다는 게 눈에 보이게)
	pack_node = ProcModels.backpack(Color("#8A6A45"))
	pack_node.position = Vector3(0, -0.2, -0.38)
	pack_node.rotation = Vector3(0.12, PI, 0)
	pack_node.scale = Vector3.ONE * 0.62
	chest_att.add_child(pack_node)
	back_hold = Node3D.new()
	back_hold.position = Vector3(0.12, -0.12, -0.46)
	back_hold.rotation = Vector3(-PI * 0.5 + 0.25, 0, 0.9)
	chest_att.add_child(back_hold)

func _bone_att(bone: String) -> Node3D:
	if skel.find_bone(bone) < 0:
		return null
	var ba := BoneAttachment3D.new()
	ba.bone_name = bone
	skel.add_child(ba)
	return ba

## 지금 들고 있는 장비 (원정 플레이어 / 은신처 / 협동 동료 공통)
func _gear() -> Dictionary:
	var g := {"gun": "", "melee": "bat", "helmet": "", "vest": "", "mods": {}}
	if ent.has_method("current_weapon"):
		g.gun = str(ent.current_weapon())
	elif ent.get("weapon") != null:
		g.gun = str(ent.get("weapon"))
	if ent is LobbyPlayer:
		g.melee = str(GameState.loadout.get("melee", "bat"))
		g.helmet = str(GameState.loadout.get("helmet", ""))
		g.vest = str(GameState.loadout.get("vest", ""))
		g.mods = GameState.mods
	else:
		if ent.get("melee_id") != null:
			g.melee = str(ent.get("melee_id"))
		if ent.get("helmet") != null:
			g.helmet = str(ent.get("helmet"))
			g.vest = str(ent.get("vest"))
		if ent.get("mods") != null:
			g.mods = ent.get("mods")
	return g

func _update_gear(_delta: float) -> void:
	if chest_att == null or not is_instance_valid(ent):
		return
	if pack_node:
		var load_k := 0.0
		var rd = ent.get("raid")
		if rd != null and is_instance_valid(rd) and rd.get("bag") != null and ent == rd.get("player"):
			load_k = float(rd.bag.load_ratio())
		var want := 0.7 + 0.3 * load_k
		pack_node.scale = pack_node.scale.lerp(Vector3.ONE * want, 0.1)
	var g := _gear()
	var gun: String = g.gun if DB.WEAPONS.has(g.gun) else ""
	var mods: Dictionary = g.mods.get(gun, {}) if gun != "" else {}
	var gk := gun + str(mods)
	if gk != gun_key:
		gun_key = gk
		if gun_node:
			gun_node.queue_free()
			gun_node = null
		laser = null
		if gun != "":
			gun_node = EnemyModel.weapon_scene(gun)
			if gun_node:
				ProcModels.attach_mods(gun_node, gun, mods)
				gun_hold.add_child(gun_node)
				if mods.values().has("laser"):
					_add_laser()
	var mel: String = g.melee if DB.MELEES.has(g.melee) else "bat"
	if mel != melee_key:
		melee_key = mel
		if melee_node:
			melee_node.queue_free()
		melee_node = EnemyModel.weapon_scene(mel)
		if melee_node:
			melee_hold.add_child(melee_node)
	# 근접: 휘두를 때(또는 총이 없을 때) 손에, 아니면 등에 멘다
	var ma := _f("melee_anim")
	var swinging := ma > 0.0
	if melee_node:
		var in_hand := swinging or gun_node == null
		var want_parent: Node3D = melee_hold if in_hand else back_hold
		if melee_node.get_parent() != want_parent:
			melee_node.reparent(want_parent, false)
			melee_node.transform = Transform3D.IDENTITY
		if in_hand:
			if swinging:
				var k := 1.0 - ma / 0.22
				k = 1.0 - pow(1.0 - k, 2.0)
				melee_hold.rotation = Vector3(lerpf(-1.9, 0.7, k), lerpf(-0.9, 1.0, k), lerpf(0.4, -0.3, k))
			else:
				melee_hold.rotation = Vector3(-1.0, 0.25, 0.1)
	if gun_node:
		gun_node.visible = not swinging
	# 갑옷
	var vk: String = g.vest
	if vk != vest_key:
		vest_key = vk
		if vest_node:
			vest_node.queue_free()
			vest_node = null
		if vk != "" and DB.ITEMS.has(vk):
			vest_node = ProcModels.vest(int(DB.ITEMS[vk].tier))
			vest_node.position = Vector3(0, -0.03, -0.07)
			chest_att.add_child(vest_node)
	var hk: String = g.helmet
	if hk != helmet_key and head_att:
		helmet_key = hk
		if helmet_node:
			helmet_node.queue_free()
			helmet_node = null
		if hk != "" and DB.ITEMS.has(hk):
			helmet_node = ProcModels.helmet(int(DB.ITEMS[hk].tier))
			helmet_node.position = Vector3(0, 0.3, 0.02)
			helmet_node.scale = Vector3.ONE * 1.28
			head_att.add_child(helmet_node)

# ── 물약 효과 보이기: 강철 피부 = 푸른 막, 질풍 = 발밑 바람 ──
var iron_fx: MeshInstance3D
var swift_fx: CPUParticles3D
func _update_buff_fx() -> void:
	var b = ent.get("buffs")
	if typeof(b) != TYPE_DICTIONARY:
		return
	var iron: bool = b.has("iron")
	if iron and iron_fx == null:
		iron_fx = MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.62
		sm.height = 1.3
		iron_fx.mesh = sm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.albedo_color = Color(0.45, 0.7, 1.0, 0.18)
		m.cull_mode = BaseMaterial3D.CULL_FRONT
		iron_fx.material_override = m
		iron_fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		iron_fx.position = Vector3(0, 0.62, 0)
		pivot.add_child(iron_fx)
	elif not iron and iron_fx:
		iron_fx.queue_free()
		iron_fx = null
	if iron_fx:
		var k := 0.15 + 0.08 * sin(t * 6.0)
		(iron_fx.material_override as StandardMaterial3D).albedo_color.a = k
	var swift: bool = b.has("swift") or b.has("carrot")
	if swift and swift_fx == null:
		swift_fx = ProcModels.embers(Vector3(0, 0.05, -0.1), Color("#9CFFB4"), 18, 0.5, 0.03)
		swift_fx.direction = Vector3(0, 0.3, -1)
		swift_fx.gravity = Vector3.ZERO
		pivot.add_child(swift_fx)
	elif not swift and swift_fx:
		swift_fx.queue_free()
		swift_fx = null

## 레이저 지시기: 총구 방향으로 빨간 선
func _add_laser() -> void:
	laser = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.008, 0.008, 6.0)
	laser.mesh = bm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1, 0.1, 0.1, 0.55)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = Color(1, 0.1, 0.1)
	m.emission_energy_multiplier = 3.0
	laser.material_override = m
	laser.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	laser.position = Vector3(0, -0.04, 3.0)
	gun_node.add_child(laser)

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
