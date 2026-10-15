class_name LobbyPlayer
extends CharacterBody2D
## 은신처에서 걸어 다니는 햄스터 (Char3D가 그릴 수 있게 원정 Player와 같은 상태 이름을 가진다)

const SPEED := 230.0
const RUN := 330.0

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
var hdata: Dictionary = {}
var input_locked := false
var facing := 1.0

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 14.0
	cs.shape = c
	add_child(cs)
	hdata = DB.HAMSTERS.get(GameState.hamster, DB.HAMSTERS.baragi)

func current_weapon() -> String:
	var lo := GameState.loadout
	if str(lo.primary) != "":
		return str(lo.primary)
	return str(lo.sidearm)

func _physics_process(_delta: float) -> void:
	var mv := Vector2.ZERO
	if not input_locked:
		mv = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = mv * (RUN if Input.is_action_pressed("sprint") else SPEED)
	if mv.length() > 0.1:
		aim_dir = aim_dir.lerp(mv.normalized(), 0.35).normalized()
	move_and_slide()
