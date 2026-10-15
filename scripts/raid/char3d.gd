class_name Char3D
extends Node3D
## 3D 캐릭터 (햄스터·고양이). 2D 게임 로직의 상태(위치·조준·이동·구르기 등)를 읽어
## 부위별(머리·몸·팔·다리)로 절차적 애니메이션을 한다.

const T := float(DB.TILE)
const CAT_WEAPON := {"hyena": "knife", "bulldog": "hammer", "cat": "sniper"}

var ent: Node2D
var kind := "hamster"
var model: Node3D
var parts := {}
var rest := {}
var meshes: Array[MeshInstance3D] = []
var grip: Node3D
var weapon_node: Node3D
var weapon_id := "-"
var phase := 0.0
var t := 0.0
var last_pos := Vector2.ZERO
var yaw := 0.0
var dead_t := -1.0
var label: Label3D
var mark: Label3D
var height := 1.0
var base_scale := 1.0
var _alpha := 1.0

func setup(e: Node2D, k: String) -> void:
	ent = e
	kind = k
	var path := "res://assets/models/hamster.glb" if k == "hamster" else "res://assets/models/cat_%s.glb" % k
	var ps: PackedScene = load(path)
	model = ps.instantiate()
	add_child(model)
	base_scale = 0.9 if k == "hamster" else 0.95
	model.scale = Vector3.ONE * base_scale
	height = (1.3 if k == "hamster" else (1.85 if k == "bulldog" else 1.55)) * base_scale
	for n in ["body", "head", "arm_l", "arm_r", "leg_l", "leg_r"]:
		var nd := model.find_child(n, true, false) as Node3D
		if nd:
			parts[n] = nd
			rest[n] = nd.transform
	grip = model.find_child("grip", true, false) as Node3D
	_collect(model)
	if k == "hamster" and ent.get("hdata") is Dictionary and not (ent.get("hdata") as Dictionary).is_empty():
		_recolor_fur(Color(str(ent.hdata.get("fur", "#E9A15E"))))
	if ent is RemotePlayer:
		var nl := Label3D.new()
		nl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		nl.no_depth_test = true
		nl.fixed_size = true
		nl.pixel_size = 0.0006
		nl.font = FX.font()
		nl.font_size = 22
		nl.outline_size = 8
		nl.text = (ent as RemotePlayer).nickname
		nl.modulate = Color("#9CFFB4")
		nl.position = Vector3(0, height + 0.15, 0)
		add_child(nl)
	if k != "hamster":
		label = Label3D.new()
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.fixed_size = true
		label.pixel_size = 0.0006
		label.font = FX.font()
		label.font_size = 22
		label.outline_size = 8
		label.position = Vector3(0, height + 0.15, 0)
		label.text = str(ent.data.name)
		label.modulate = ent.data.name_color
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
		mark.position = Vector3(0, height + 0.45, 0)
		mark.visible = false
		add_child(mark)
	last_pos = ent.global_position
	position = Vector3(last_pos.x / T, 0, last_pos.y / T)
	_set_weapon(_want_weapon())

func _collect(n: Node) -> void:
	if n is MeshInstance3D:
		meshes.append(n)
		(n as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		toon_mesh(n as MeshInstance3D)
	for c in n.get_children():
		_collect(c)

# ── 일러스트풍: 만화 명암(2단) + 진한 외곽선 ───────────
static var _outline: ShaderMaterial
static var _toon_cache := {}

static func outline_mat() -> ShaderMaterial:
	if _outline == null:
		_outline = ShaderMaterial.new()
		_outline.shader = load("res://scripts/raid/outline.gdshader")
	return _outline

static func toon_mesh(mi: MeshInstance3D) -> void:
	if mi.mesh == null:
		return
	for i in mi.mesh.get_surface_count():
		var src := mi.get_surface_override_material(i)
		if src == null:
			src = mi.mesh.surface_get_material(i)
		if not (src is StandardMaterial3D):
			continue
		if not _toon_cache.has(src):
			var d := (src as StandardMaterial3D).duplicate() as StandardMaterial3D
			d.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
			d.specular_mode = BaseMaterial3D.SPECULAR_TOON
			d.roughness = maxf(d.roughness, 0.55)
			d.metallic = 0.0
			d.rim_enabled = true
			d.rim = 0.18
			d.rim_tint = 0.7
			if not d.emission_enabled:
				d.next_pass = outline_mat()
			_toon_cache[src] = d
		mi.set_surface_override_material(i, _toon_cache[src])

static func toonify(root: Node) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		toon_mesh(mi as MeshInstance3D)

func _recolor_fur(c: Color) -> void:
	var cache := {}
	for mi in meshes:
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			if m and m.resource_name == "fur":
				if not cache.has(m):
					var d := (m as StandardMaterial3D).duplicate() as StandardMaterial3D
					d.albedo_color = c
					cache[m] = d
				mi.set_surface_override_material(i, cache[m])
		toon_mesh(mi)

func _want_weapon() -> String:
	if kind == "hamster":
		var w: String = ent.current_weapon() if is_instance_valid(ent) else ""
		return w if w != "" else "bat"
	return CAT_WEAPON.get(kind, "")

func _set_weapon(id: String) -> void:
	if id == weapon_id or grip == null:
		return
	weapon_id = id
	if weapon_node:
		weapon_node.queue_free()
		weapon_node = null
	var p := "res://assets/models/w_%s.glb" % id
	if id != "" and ResourceLoader.exists(p):
		weapon_node = (load(p) as PackedScene).instantiate()
		grip.add_child(weapon_node)
		_collect(weapon_node)

func _rot(n: String, rx: float, ry: float = 0.0, rz: float = 0.0, off: Vector3 = Vector3.ZERO) -> void:
	if not parts.has(n):
		return
	var tr: Transform3D = rest[n]
	var b := tr.basis * Basis.from_euler(Vector3(rx, ry, rz))
	(parts[n] as Node3D).transform = Transform3D(b, tr.origin + off)

func _set_alpha(a: float) -> void:
	if is_equal_approx(a, _alpha):
		return
	_alpha = a
	for mi in meshes:
		if is_instance_valid(mi):
			mi.transparency = 1.0 - a

func _process(delta: float) -> void:
	t += delta
	var alive := is_instance_valid(ent) and not bool(ent.get("dead"))
	if not alive:
		_death(delta)
		return
	var pos := ent.global_position
	var vel := (pos - last_pos) / maxf(delta, 0.001)
	last_pos = pos
	position = Vector3(pos.x / T, 0, pos.y / T)
	var speed := vel.length()
	var moving := speed > 25.0
	# 바라보는 방향
	var dir := Vector2.ZERO
	if kind == "hamster":
		dir = ent.aim_dir
	else:
		dir = ent.aim if (ent.is_aware() or ent.windup > 0.0) else (vel if moving else Vector2(ent.facing, 0.3))
	if dir.length() > 0.01:
		yaw = lerp_angle(yaw, atan2(dir.x, dir.y), 1.0 - exp(-14.0 * delta))   # 모델 정면 = +Z
	rotation.y = yaw
	# 걷기
	var m := clampf(speed / 220.0, 0.0, 1.3)
	phase += delta * (4.0 + speed / T * 1.9) * (1.0 if moving else 0.0)
	var sw := sin(phase) * m
	var bob := absf(sin(phase)) * 0.05 * m
	var breathe := sin(t * 2.4) * 0.012
	_rot("leg_l", sw * 0.75)
	_rot("leg_r", -sw * 0.75)
	_rot("arm_l", -sw * 0.25 - 0.1, 0, 0)
	var arm_r_x := sw * 0.12
	var arm_r_y := 0.0
	var body_off := Vector3(0, bob, 0)
	var lean := 0.1 * m
	var squash := 1.0
	var roll := 0.0
	var vis := true
	var alpha := 1.0
	if kind == "hamster":
		if float(ent.recoil) > 0.1:
			body_off.z -= minf(float(ent.recoil), 12.0) * 0.006
			arm_r_x -= minf(float(ent.recoil), 12.0) * 0.03
		if float(ent.melee_anim) > 0.0:
			arm_r_y = -sin(float(ent.melee_anim) / 0.22 * PI) * 1.6
		if float(ent.dodge_t) > 0.0:
			roll = (1.0 - float(ent.dodge_t) / Player.DODGE_TIME) * TAU
		if bool(ent.crouching):
			squash = 0.8
		if float(ent.cloak_t) > 0.0:
			alpha = 0.3
		if float(ent.get("burrow_t")) > 0.0:
			vis = false
		if float(ent.heal_t) > 0.0:
			arm_r_x = -0.9
	else:
		if float(ent.windup) > 0.0:
			var k := 1.0 - float(ent.windup) / maxf(0.01, float(ent.windup_total))
			arm_r_x = -1.2 * k if kind != "cat" else 0.0
			body_off.y += sin(t * 60.0) * 0.01 * k
		if float(ent.lunge) > 0.0:
			arm_r_x = 0.7
		if float(ent.stun) > 0.0:
			roll = 0.0
			lean = sin(t * 9.0) * 0.18
	_rot("arm_r", arm_r_x, arm_r_y)
	_rot("body", lean * 0.5, 0, 0, body_off)
	_rot("head", -0.3 + breathe, 0, 0, body_off)   # 카메라 쪽으로 고개를 살짝 든다
	model.visible = vis
	var pop := 1.0 + clampf(float(ent.flash), 0.0, 1.0) * 0.14
	model.scale = Vector3(base_scale * pop, base_scale * squash * pop * (1.0 + breathe), base_scale * pop)
	model.rotation = Vector3(roll + lean * 0.4, 0, 0)
	_set_alpha(alpha)
	if kind == "hamster":
		_set_weapon(_want_weapon())
	else:
		_update_labels()

func _update_labels() -> void:
	var aware: bool = ent.is_aware()
	label.visible = float(ent.show_bar_t) > 0.0 or aware
	var st = ent.state
	if st == Enemy.S.CHASE or (float(ent.icon_t) > 0.0 and st != Enemy.S.PATROL):
		mark.text = "!"
		mark.modulate = DB.C_DANGER
		mark.visible = true
	elif st == Enemy.S.SUSPICIOUS or st == Enemy.S.SEARCH:
		mark.text = "?"
		mark.modulate = DB.C_LEGEND
		mark.visible = true
	else:
		mark.visible = false
	mark.position.y = height + 0.45 + absf(sin(t * 8.0)) * 0.06

func _death(delta: float) -> void:
	if dead_t < 0.0:
		dead_t = 0.0
		if label:
			label.visible = false
		if mark:
			mark.visible = false
	dead_t += delta
	var k := clampf(dead_t / 0.35, 0.0, 1.0)
	model.rotation = Vector3(0, 0, -k * PI * 0.5)
	model.position.y = k * 0.25 * base_scale
	if dead_t > 6.0:
		_set_alpha(clampf(1.0 - (dead_t - 6.0) / 1.5, 0.0, 1.0))
	if dead_t > 7.6:
		queue_free()
