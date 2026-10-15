class_name RemotePlayer
extends CharacterBody2D
## 다른 플레이어의 햄스터 (네트워크 상태를 받아 부드럽게 따라감).
## 호스트에서는 고양이가 이 대상을 보고 공격하며, 피해는 주인에게 전달된다.

var peer := 0
var nickname := ""
var net_pos := Vector2.ZERO
var aim_dir := Vector2(0, 1)
var recoil := 0.0
var melee_anim := 0.0
var dodge_t := 0.0
var crouching := false
var cloak_t := 0.0
var burrow_t := 0.0
var heal_t := 0.0
var flash := 0.0
var dead := false
var hp := 100.0
var max_hp := 100.0
var hdata: Dictionary = {}
var weapon := ""
var scout_t := 0.0
var _vis := 1.0
var _seen := 0.0

func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 14.0
	cs.shape = c
	cs.position = Vector2(0, -8)
	add_child(cs)
	add_to_group("players")

func current_weapon() -> String:
	return weapon if weapon != "" else "bat"

func visibility() -> float:
	return _vis

func apply(st: Array) -> void:
	# [pos, aim, hp, max_hp, flags, weapon, hamster, vis, dodge_t, melee_anim, recoil, heal_t]
	net_pos = st[0]
	aim_dir = st[1]
	hp = st[2]
	max_hp = st[3]
	var f: int = st[4]
	crouching = (f & 1) != 0
	cloak_t = 1.0 if (f & 2) != 0 else 0.0
	burrow_t = 1.0 if (f & 4) != 0 else 0.0
	dead = (f & 8) != 0
	weapon = st[5]
	var hid: String = st[6]
	if hdata.is_empty() or hdata.get("_id", "") != hid:
		hdata = DB.HAMSTERS.get(hid, DB.HAMSTERS.baragi).duplicate()
		hdata["_id"] = hid
	_vis = st[7]
	dodge_t = st[8]
	melee_anim = st[9]
	recoil = st[10]
	heal_t = st[11]
	if _seen == 0.0:
		global_position = net_pos
	_seen = 1.0

func _physics_process(delta: float) -> void:
	var to := net_pos - global_position
	if to.length() > 160.0:
		global_position = net_pos
	else:
		global_position += to * (1.0 - exp(-14.0 * delta))
	velocity = to * 10.0
	flash = maxf(0.0, flash - delta * 6.0)

## 호스트의 고양이가 이 햄스터를 공격 → 실제 주인에게 피해 전달
func take_damage(amount: float, from_pos: Vector2) -> void:
	if dead:
		return
	flash = 1.0
	Net.hurt_peer(peer, amount, from_pos)
