class_name Prop3D
extends Node3D
## 맵 소품 3D 모델 (블렌더 GLB). 파밍 상자는 열리면(뒤지면) 열린 모델로 바뀐다.

const T := float(DB.TILE)
const DIR := "res://assets/models/props/%s.glb"
const CONTAINER_MODEL := {"box": "crate", "toolbox": "ammo_locker", "locker": "locker"}

var ent: Node2D
var lc: LootContainer
var cur := ""
var inst: Node3D
var off := Vector2(0, -0.5)
var sc := 1.0
var wpn: Node3D          # 떨어진 꾸러미에 든 무기: 바닥에 눕혀 보여 준다
var wpn_id := ""
var _t := 0.0

func setup_static(e: Node2D, name_: String, rot_deg: float, offset: Vector2, scale_k: float = 1.0) -> void:
	ent = e
	off = offset
	sc = scale_k
	rotation_degrees.y = rot_deg
	_place()
	_show(name_)

func setup_container(c: LootContainer) -> void:
	lc = c
	ent = c
	if c.lost_bag:
		_build_lost_bag()
		return
	if c.supply:
		_place()
		var cr := ProcModels.supply_crate()
		add_child(cr)
		beam = ProcModels.light_beam(Color("#7FC8FF"), 6.0, 0.4)
		add_child(beam)
		return
	if c.is_drop:
		sc = 0.45
		off = Vector2(0, -0.1)
	elif c.type == "dumpster":
		off = Vector2(0.5, -0.5)
	# 세로로 이어진 진열대는 옆을 보게 돌린다
	var tx := int(floor(c.position.x / T))
	var ty := int(floor(c.position.y / T)) - 1
	if c.type == "shelf" and ("Ss".contains(LevelData.code(tx, ty - 1)) or "Ss".contains(LevelData.code(tx, ty + 1))):
		rotation_degrees.y = 90.0 if (tx % 2 == 0) else -90.0
	_place()
	_show(_cname())

## 쓰러진 자리에 남은 내 가방: 큼직한 배낭 + 노란 빛기둥
var bag_node: Node3D
var beam: Node3D
func _build_lost_bag() -> void:
	_place()
	bag_node = ProcModels.backpack()
	bag_node.scale = Vector3.ONE * 1.3
	bag_node.rotation.y = randf() * TAU
	bag_node.rotation.z = 0.25
	add_child(bag_node)
	beam = ProcModels.light_beam(Color("#F2C14E"), 5.0, 0.35)
	add_child(beam)
	var l := OmniLight3D.new()
	l.light_color = Color("#FFD27A")
	l.light_energy = 1.4
	l.omni_range = 2.5
	l.position = Vector3(0, 0.8, 0)
	add_child(l)
	var lb := Label3D.new()
	lb.text = "내 가방"
	lb.font = FX.font()
	lb.font_size = 30
	lb.outline_size = 10
	lb.modulate = Color("#FFD27A")
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.fixed_size = true
	lb.pixel_size = 0.0007
	lb.no_depth_test = true
	lb.position = Vector3(0, 1.4, 0)
	add_child(lb)

func _cname() -> String:
	if lc.is_drop:
		return "box_open"
	if CONTAINER_MODEL.has(lc.type):
		var n: String = CONTAINER_MODEL[lc.type]
		if lc.type == "locker" and lc.searched:
			return "locker_open"
		return n
	return lc.prop_name()

func _place() -> void:
	var p := ent.global_position
	position = Vector3(p.x / T + off.x, 0, p.y / T + off.y)

func _show(name_: String) -> void:
	if name_ == cur:
		return
	cur = name_
	if inst:
		inst.queue_free()
	if name_.begins_with("proc:"):
		inst = ProcModels.proc_prop(name_.substr(5))
		inst.scale = Vector3.ONE * sc
		add_child(inst)
		return
	var path := DIR % name_
	if not ResourceLoader.exists(path):
		path = DIR % "box"
	inst = (load(path) as PackedScene).instantiate()
	inst.scale = Vector3.ONE * sc
	add_child(inst)

func _process(_delta: float) -> void:
	if not is_instance_valid(ent):
		queue_free()
		return
	if lc and lc.lost_bag:
		_t += _delta
		var empty: bool = lc.searched and lc.items.is_empty()
		if beam:
			beam.visible = not empty
			beam.scale = Vector3(1.0 + sin(_t * 3.0) * 0.08, 1.0, 1.0 + sin(_t * 3.0) * 0.08)
		for c in get_children():
			if c is Label3D or c is OmniLight3D:
				c.visible = not empty
		return
	if lc:
		_show(_cname())
		if lc.is_drop:
			_place()
			_drop_weapon(_delta)
			_drop_armor(_delta)

## 떨어진 꾸러미에 갑옷이 있으면 헬멧/조끼 모델도 옆에 보여 준다
var arm: Node3D
var arm_id := ""
func _drop_armor(delta: float) -> void:
	var aid := ""
	for it in lc.items:
		if str(DB.ITEMS.get(it, {}).get("cat", "")) == "armor":
			aid = str(it)
			break
	if aid != arm_id:
		arm_id = aid
		if arm:
			arm.queue_free()
			arm = null
		if aid != "":
			arm = Node3D.new()
			add_child(arm)
			var it: Dictionary = DB.ITEMS[aid]
			var m: Node3D = ProcModels.helmet(int(it.tier)) if it.slot == "helmet" else ProcModels.vest(int(it.tier))
			m.scale = Vector3.ONE * (0.75 if it.slot == "helmet" else 0.6)
			m.position.y = 0.05 if it.slot == "helmet" else 0.22
			arm.add_child(m)
			arm.position = Vector3(-0.4, 0.0, 0.3)
	if arm:
		arm.rotation.y += delta * 0.6

func _drop_weapon(delta: float) -> void:
	var wid := ""
	for it in lc.items:
		var d: Dictionary = DB.ITEMS.get(it, {})
		if d.get("cat", "") == "weapon":
			wid = String(d.get("weapon", ""))
			break
	if wid != wpn_id:
		wpn_id = wid
		if wpn:
			wpn.queue_free()
			wpn = null
		if wid != "":
			wpn = Node3D.new()
			add_child(wpn)
			var m := EnemyModel.weapon_scene(wid)
			if m:
				var holder := Node3D.new()
				holder.rotation.z = PI * 0.5   # 옆으로 눕힘 (총구는 +Z)
				m.position.z = -0.3
				holder.add_child(m)
				wpn.add_child(holder)
			var glow := MeshInstance3D.new()
			var q := QuadMesh.new()
			q.size = Vector2(1.1, 1.1)
			glow.mesh = q
			glow.rotation.x = -PI * 0.5
			glow.position.y = 0.02
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			mat.albedo_texture = FX.light_texture()
			mat.albedo_color = Color(1.0, 0.8, 0.4, 0.55)
			glow.material_override = mat
			glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			wpn.add_child(glow)
			wpn.position = Vector3(0.35, 0.0, 0.25)
			wpn.rotation.y = randf() * TAU
	if wpn:
		_t += delta
		var holder_y := 0.12 + sin(_t * 3.0) * 0.03
		for c in wpn.get_children():
			if not (c is MeshInstance3D):
				(c as Node3D).position.y = holder_y
		wpn.rotation.y += delta * 0.8
