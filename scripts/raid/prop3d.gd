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
	var path := DIR % name_
	if not ResourceLoader.exists(path):
		path = DIR % "box"
	cur = name_
	if inst:
		inst.queue_free()
	inst = (load(path) as PackedScene).instantiate()
	inst.scale = Vector3.ONE * sc
	add_child(inst)

func _process(_delta: float) -> void:
	if not is_instance_valid(ent):
		queue_free()
		return
	if lc:
		_show(_cname())
		if lc.is_drop:
			_place()
