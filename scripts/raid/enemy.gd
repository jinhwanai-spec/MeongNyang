class_name Enemy
extends CharacterBody2D
## 적 AI: 순찰 → 경계(?) → 추격(!) → 수색. 한 마리가 발견하면 주변에 경보를 보낸다.
## 하이에나: 무리 지어 물어뜯기 / 불독: 압박·돌진·망치 / 석궁 고양이: 거리 유지·조준선 예고 후 사격·엄폐

enum S { PATROL, SUSPICIOUS, CHASE, SEARCH, COVER }

var raid: Raid
var type := "hyena"
var data: Dictionary
var hp := 30.0
var max_hp := 30.0
var radius := 15.0
var dead := false
var state := S.PATROL
var home := Vector2.ZERO
var awareness := 0.0
var target_pos := Vector2.ZERO
var last_seen := Vector2.ZERO
var sees_player := false
var path := PackedVector2Array()
var path_i := 0
var repath_t := 0.0
var wait_t := 0.0
var search_t := 0.0
var attack_cd := 0.0
var windup := 0.0
var windup_total := 0.0
var charge_t := 0.0
var charge_dir := Vector2.ZERO
var charge_cd := 0.0
var cover_t := 0.0
var strafe := 1.0
var strafe_t := 0.0
var flash := 0.0
var walk := 0.0
var facing := 1.0
var aim := Vector2.RIGHT
var icon_t := 0.0
var knock := Vector2.ZERO
var lunge := 0.0
var think_t := 0.0
var show_bar_t := 0.0
var stun := 0.0
# 협동 멀티
var net_id := 0
var puppet := false          # 클라이언트: 호스트가 보낸 상태만 따라함
var last_hitter := 1
var net_pos := Vector2.ZERO
var target: Node2D           # 노리는 햄스터 (가장 가까운 플레이어)
var weapon := ""             # 들고 있는 무기 (죽으면 떨어뜨림)
var elite := false           # 대장 고양이 (크고 단단하고 좋은 걸 떨어뜨림)
var helmet := ""             # 쓰고 있는 헬멧 / 입은 조끼 (피해를 줄이고, 죽으면 떨어뜨릴 수 있다)
var vest := ""
var gunner := false          # 총을 들었으면 거리를 두고 쏜다
var _burst := 0
var _burst_t := 0.0
var _net_hit := false
var shot_flash := 0.0        # 방금 쐈음 (3D 모델 반동용)

# AI 타입 → [스프라이트, 무기, 손 높이]
const SPRITES := {"hyena": ["cat_tabby", "knife", -30.0], "bulldog": ["cat_black", "hammer", -40.0], "cat": ["cat_white", "sniper", -34.0]}
var sprite_kind := "cat_tabby"
var spr: Sprite2D
var wspr: Sprite2D
var head_y := -80.0
var art: Node2D
var hand: Node2D

func setup(r: Raid, t: String, pos: Vector2) -> void:
	raid = r
	type = t
	data = DB.ENEMIES[t]
	hp = float(data.hp) * float(GameState.diff("enemy_hp"))
	max_hp = hp
	radius = float(data.radius)
	position = pos
	home = pos
	net_pos = pos
	target_pos = pos
	facing = 1.0 if randf() > 0.5 else -1.0
	think_t = randf() * 0.3
	var pool: Array = DB.ENEMY_WEAPONS.get(t, [])
	if not pool.is_empty():
		weapon = pool[randi() % pool.size()]
	gunner = DB.WEAPONS.has(weapon)
	_roll_armor()

## 종류별 갑옷: 흑냥이는 대부분 무장, 길냥이는 가끔, 저격수는 헬멧 위주
const ARMOR_ROLL := {
	"hyena": [[0.25, ["helmet_1", "helmet_1", "helmet_2"]], [0.3, ["vest_1", "vest_1", "vest_2"]]],
	"bulldog": [[0.6, ["helmet_2", "helmet_2", "helmet_3"]], [0.8, ["vest_2", "vest_3", "vest_3"]]],
	"cat": [[0.45, ["helmet_2", "helmet_3", "helmet_3"]], [0.25, ["vest_1", "vest_2"]]],
}
static var force_armor: Array = []   # 테스트용: [헬멧, 조끼] 강제
func _roll_armor() -> void:
	if force_armor.size() == 2:
		helmet = str(force_armor[0])
		vest = str(force_armor[1])
		return
	var rr: Array = ARMOR_ROLL.get(type, [])
	if rr.size() < 2:
		return
	if randf() < float(rr[0][0]):
		helmet = str((rr[0][1] as Array).pick_random())
	if randf() < float(rr[1][0]):
		vest = str((rr[1][1] as Array).pick_random())

## 대장: 체력 4.5배, 경기관총, 최고급 갑옷
func make_elite(title: String, wpn: String = "lmg") -> void:
	elite = true
	data = data.duplicate()
	data.name = title
	data.name_color = DB.C_LEGEND
	data.radius = float(data.radius) * 1.25
	radius = float(data.radius)
	hp = float(DB.ENEMIES[type].hp) * (4.5 if type == "bulldog" else 7.0) * float(GameState.diff("enemy_hp"))
	max_hp = hp
	weapon = wpn
	gunner = true
	helmet = "helmet_3"
	vest = "vest_3"

static var force_shield := false   # 테스트용
var shield := false          # 방패 흑냥이: 정면에서 오는 공격을 대부분 막는다

func make_shield() -> void:
	shield = true
	data = data.duplicate()
	data.name = "방패 흑냥이"
	data.name_color = Color("#9FC3FF")

## 공격이 방패 정면(±65°)에서 왔는가
func shield_blocks(from_pos: Vector2) -> bool:
	if not shield:
		return false
	var to := (from_pos - global_position)
	if to.length() < 1.0:
		return false
	return aim.normalized().dot(to.normalized()) > cos(deg_to_rad(65.0))

func armor_prot() -> float:
	var p := 0.0
	for aid in [helmet, vest]:
		if aid != "":
			p += float(DB.ITEMS[aid].prot)
	return minf(p, 0.5)

func _ready() -> void:
	add_to_group("enemy")
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = radius
	shape.shape = c
	shape.position = Vector2(0, -radius * 0.6)
	add_child(shape)
	sprite_kind = SPRITES[type][0]
	var shadow := Node2D.new()
	shadow.draw.connect(func(): Art.shadow(shadow, Vector2.ZERO, radius + 3, 6))
	add_child(shadow)
	spr = Sprite2D.new()
	Sprites.setup_char_sprite(spr, sprite_kind)
	spr.material = Sprites.flash_material()
	add_child(spr)
	head_y = -Sprites.char_height(sprite_kind) + 2.0
	art = Node2D.new()
	art.draw.connect(_draw_art)
	art.z_index = 2
	add_child(art)
	hand = Node2D.new()
	hand.position = Vector2(0, -Sprites.char_height(SPRITES[type][0]) * 0.45)
	hand.draw.connect(_draw_hand)
	add_child(hand)
	wspr = Sprite2D.new()
	Sprites.setup_weapon_sprite(wspr, sprite_kind, SPRITES[type][1])
	wspr.material = spr.material
	hand.add_child(wspr)
	wspr.visible = false  # 무기는 시트 스프라이트에 그려져 있음

func is_aware() -> bool:
	return state == S.CHASE or state == S.SEARCH or state == S.COVER

func center() -> Vector2:
	return global_position + Vector2(0, -radius)

# ── 감지 ─────────────────────────────────────────────
func hear(pos: Vector2, loud: float) -> void:
	if dead:
		return
	if state == S.CHASE and sees_player:
		return
	var d := global_position.distance_to(pos)
	if loud >= 380.0 or d < loud * 0.45:
		_go_search(pos, true)
	else:
		if state == S.PATROL:
			_set_state(S.SUSPICIOUS)
		target_pos = pos
		awareness = maxf(awareness, 0.45)
		path = PackedVector2Array()

func alert_from_ally(pos: Vector2) -> void:
	if dead or state == S.CHASE:
		return
	_go_search(pos, true)

func _go_search(pos: Vector2, fast: bool) -> void:
	last_seen = pos
	target_pos = pos
	awareness = maxf(awareness, 0.8)
	search_t = 6.0
	_set_state(S.SEARCH)
	path = PackedVector2Array()
	repath_t = 0.0
	if fast:
		wait_t = 0.0

func _set_state(s: S) -> void:
	if s == state:
		return
	if s == S.CHASE and state != S.CHASE:
		icon_t = 1.2
		Sfx.play_at("alert_" + type, global_position, -3.0)
	elif s == S.SUSPICIOUS:
		icon_t = 1.0
	state = s

## 가장 가까운 살아 있는 햄스터 (조금이라도 이미 노리던 대상을 선호)
func _tgt() -> Node2D:
	var best: Node2D = null
	var bd := 1e18
	for q in raid.players:
		if not is_instance_valid(q) or q.dead:
			continue
		var d := global_position.distance_squared_to(q.global_position)
		if q == target:
			d *= 0.6
		if d < bd:
			bd = d
			best = q
	target = best
	return best

func _cur() -> Node2D:
	if target and is_instance_valid(target) and not target.dead:
		return target
	return _tgt()

func _perceive(delta: float) -> void:
	var p = _tgt()
	sees_player = false
	if p == null or p.dead:
		return
	var to: Vector2 = (p.global_position + Vector2(0, -20)) - center()
	var dist := to.length()
	if p.cloak_t > 0.0:
		# 상자를 뒤집어쓴 햄스터는 보이지 않는다 — 쫓던 고양이도 마지막 위치를 뒤질 뿐
		if state == S.CHASE:
			_go_search(last_seen, false)
		return
	var vision: float = float(data.vision) * raid.vision_mul * p.visibility()
	var in_cone := rad_to_deg(absf(Vector2(facing, 0).angle_to(to))) <= float(data.fov) * 0.5
	if is_aware():
		in_cone = true  # 이미 경계 중이면 사방을 본다
	if dist < 70.0:
		in_cone = true
	if dist <= vision and in_cone and raid.has_los(center(), p.global_position + Vector2(0, -20)):
		sees_player = true
		last_seen = p.global_position
		var rate := (1.0 - dist / vision) * 2.6 + 0.5
		if p.velocity.length() > 250.0:
			rate *= 1.5
		awareness = minf(1.0, awareness + rate * delta)
		if awareness >= 1.0 or state == S.CHASE or state == S.SEARCH:
			if state != S.CHASE:
				_set_state(S.CHASE)
				raid.alert_group(global_position, float(data.group_call), self)
		elif awareness > 0.3:
			_set_state(S.SUSPICIOUS)
			target_pos = p.global_position
	else:
		if state == S.PATROL or state == S.SUSPICIOUS:
			awareness = maxf(0.0, awareness - delta * 0.25)

# ── 메인 루프 ────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if dead:
		return
	if puppet:
		_puppet_step(delta)
		return
	attack_cd = maxf(0.0, attack_cd - delta)
	charge_cd = maxf(0.0, charge_cd - delta)
	flash = maxf(0.0, flash - delta * 6.0)
	icon_t = maxf(0.0, icon_t - delta)
	show_bar_t = maxf(0.0, show_bar_t - delta)
	lunge = maxf(0.0, lunge - delta)
	knock = knock.lerp(Vector2.ZERO, 1.0 - exp(-delta * 9.0))
	if stun > 0.0:
		stun -= delta
		velocity = knock
		move_and_slide()
		walk += delta
		art.queue_redraw()
		_update_visuals()
		return
	think_t -= delta
	if think_t <= 0.0:
		think_t = 0.1
		_perceive(0.1)

	var desired := Vector2.ZERO
	var spd := float(data.speed)
	match state:
		S.PATROL:
			desired = _patrol(delta)
		S.SUSPICIOUS:
			desired = _move_to(target_pos, delta) * 0.75
			if global_position.distance_to(target_pos) < 30.0:
				wait_t += delta
				_look_around(delta)
				if wait_t > 2.0:
					wait_t = 0.0
					awareness = 0.0
					_set_state(S.PATROL)
		S.SEARCH:
			spd = float(data.chase_speed) * 0.85
			desired = _move_to(target_pos, delta)
			if global_position.distance_to(target_pos) < 36.0:
				search_t -= delta
				_look_around(delta)
				if search_t <= 0.0:
					awareness = 0.2
					_set_state(S.PATROL)
					target_pos = home
		S.CHASE:
			spd = float(data.chase_speed)
			desired = _combat(delta)
		S.COVER:
			spd = float(data.chase_speed)
			desired = _move_to(target_pos, delta)
			cover_t -= delta
			if cover_t <= 0.0:
				_set_state(S.CHASE)

	if _burst > 0:
		_burst_t -= delta
		if _burst_t <= 0.0:
			_burst -= 1
			var pp = _cur()
			if pp and not dead:
				aim = ((pp.global_position + Vector2(0, -20)) - (global_position + hand.position)).normalized()
				_shoot_weapon()
			_burst_t = maxf(float(DB.WEAPONS[weapon].rate), 0.08)
	shot_flash = maxf(0.0, shot_flash - delta)
	if windup > 0.0:
		desired *= 0.15
		windup -= delta
		if windup <= 0.0:
			_release_attack()
	if charge_t > 0.0:
		charge_t -= delta
		desired = charge_dir
		spd = float(data.chase_speed) * 2.5
		_check_charge_hit()

	# 서로 겹치지 않게 밀어내기
	for o in get_tree().get_nodes_in_group("enemy"):
		if o == self or o.dead:
			continue
		var d: Vector2 = global_position - o.global_position
		var l := d.length()
		if l < 40.0 and l > 0.01:
			desired += d / l * (40.0 - l) / 40.0 * 0.8

	velocity = velocity.lerp(desired.limit_length(1.0) * spd, 1.0 - exp(-delta * 10.0)) + knock
	move_and_slide()
	if velocity.length() > 20.0 and windup <= 0.0:
		if absf(velocity.x) > 10.0 and not (state == S.CHASE and sees_player):
			facing = signf(velocity.x)
	if state == S.CHASE and (sees_player or windup > 0.0):
		var to: Vector2 = (_cur().global_position if _cur() else global_position + Vector2(facing, 0)) - global_position
		if absf(to.x) > 4.0:
			facing = signf(to.x)
	walk += delta * (velocity.length() / 25.0 + 1.0)
	art.queue_redraw()
	hand.queue_redraw()
	_update_visuals()

## 클라이언트: 호스트 상태를 부드럽게 따라가기
func _puppet_step(delta: float) -> void:
	flash = maxf(0.0, flash - delta * 6.0)
	icon_t = maxf(0.0, icon_t - delta)
	show_bar_t = maxf(0.0, show_bar_t - delta)
	lunge = maxf(0.0, lunge - delta)
	var to := net_pos - global_position
	if to.length() > 220.0:
		global_position = net_pos
	else:
		global_position += to * (1.0 - exp(-12.0 * delta))
	velocity = to * 8.0
	walk += delta * (velocity.length() / 25.0 + 1.0)
	art.queue_redraw()
	hand.queue_redraw()
	_update_visuals()

func net_apply(st: Array) -> void:
	net_pos = st[1]
	aim = st[2]
	state = int(st[3]) as S
	hp = st[4]
	windup = st[5]
	windup_total = st[6]
	lunge = maxf(lunge, float(st[7]))
	stun = st[8]
	facing = st[9]
	flash = maxf(flash, float(st[10]))
	show_bar_t = maxf(show_bar_t, float(st[11]))
	icon_t = maxf(icon_t, float(st[12]))
	max_hp = st[13]
	awareness = st[14]

func _patrol(delta: float) -> Vector2:
	if wait_t > 0.0:
		wait_t -= delta
		_look_around(delta)
		return Vector2.ZERO
	if global_position.distance_to(target_pos) < 24.0 or path.is_empty() and repath_t <= 0.0:
		wait_t = randf_range(1.0, 3.0)
		target_pos = raid.random_floor_near(home, 5)
		path = PackedVector2Array()
		return Vector2.ZERO
	return _move_to(target_pos, delta) * 0.6

func _look_around(delta: float) -> void:
	strafe_t -= delta
	if strafe_t <= 0.0:
		strafe_t = randf_range(0.7, 1.4)
		facing = -facing

func _move_to(pos: Vector2, delta: float) -> Vector2:
	repath_t -= delta
	if raid.has_los(center(), pos + Vector2(0, -radius), radius * 0.8):
		var d := pos - global_position
		return d.normalized() if d.length() > 6.0 else Vector2.ZERO
	if repath_t <= 0.0 or path.is_empty():
		path = raid.find_path(global_position, pos)
		path_i = 0
		repath_t = 0.5 + randf() * 0.2
	while path_i < path.size() and global_position.distance_to(path[path_i]) < 20.0:
		path_i += 1
	if path_i >= path.size():
		return (pos - global_position).normalized() if global_position.distance_to(pos) > 8.0 else Vector2.ZERO
	return (path[path_i] - global_position).normalized()

# ── 전투 ─────────────────────────────────────────────
func _combat(delta: float) -> Vector2:
	var p = _cur()
	if p == null or p.dead:
		_set_state(S.PATROL)
		return Vector2.ZERO
	if not sees_player:
		# 마지막 위치와 발자국 쪽으로 추적
		_go_search(last_seen, true)
		return Vector2.ZERO
	var to: Vector2 = p.global_position - global_position
	var dist := to.length()
	aim = ((p.global_position + Vector2(0, -20)) - (global_position + hand.position)).normalized()
	if gunner and type != "cat":
		return _gun_combat(to, dist, delta)
	match type:
		"hyena":
			if dist <= float(data.attack_range) and attack_cd <= 0.0 and windup <= 0.0:
				_begin_windup(0.22)
			# 지그재그로 접근
			strafe_t -= delta
			if strafe_t <= 0.0:
				strafe_t = randf_range(0.4, 0.8)
				strafe = -strafe
			return (to.normalized() + to.orthogonal().normalized() * strafe * 0.35).normalized() if dist > 30 else Vector2.ZERO
		"bulldog":
			if dist <= float(data.attack_range) and attack_cd <= 0.0 and windup <= 0.0:
				_begin_windup(0.6)
			elif dist > 150.0 and dist < 330.0 and charge_cd <= 0.0 and windup <= 0.0 and charge_t <= 0.0:
				charge_cd = 5.0
				_begin_windup(0.5, true)
			return to.normalized() if dist > 44 else Vector2.ZERO
		"cat":
			if hp < max_hp * 0.4 and cover_t <= -6.0:
				_seek_cover()
				return Vector2.ZERO
			cover_t -= delta
			if dist <= float(data.attack_range) and attack_cd <= 0.0 and windup <= 0.0:
				_begin_windup(0.75)
			strafe_t -= delta
			if strafe_t <= 0.0:
				strafe_t = randf_range(1.0, 2.0)
				strafe = -strafe
			var side := to.orthogonal().normalized() * strafe * 0.7
			if dist < 230.0:
				return (-to.normalized() + side).normalized()
			elif dist > 420.0:
				return (to.normalized() + side * 0.5).normalized()
			return side
	return Vector2.ZERO

var _charge_pending := false

## 총을 든 고양이: 사거리 안에서 옆걸음치며 쏜다
func _gun_combat(to: Vector2, dist: float, delta: float) -> Vector2:
	var w: Dictionary = DB.WEAPONS[weapon]
	var rng := minf(float(w.range) * 0.75, 520.0)
	if dist <= rng and attack_cd <= 0.0 and windup <= 0.0 and _burst <= 0:
		_begin_windup(0.45 if not bool(w.auto) else 0.35)
	strafe_t -= delta
	if strafe_t <= 0.0:
		strafe_t = randf_range(0.8, 1.6)
		strafe = -strafe
	var side := to.orthogonal().normalized() * strafe * 0.7
	var keep := clampf(rng * 0.45, 120.0, 300.0)
	if dist < keep:
		return (-to.normalized() + side).normalized()
	elif dist > rng * 0.9:
		return (to.normalized() + side * 0.4).normalized()
	return side

## 들고 있는 총으로 한 번 쏘기 (산탄이면 여러 발)
func _shoot_weapon() -> void:
	var w: Dictionary = DB.WEAPONS[weapon]
	var origin := global_position + hand.position + aim * 26.0
	var dmg := maxf(4.0, float(w.dmg) * 0.4)
	for i in int(w.pellets):
		var spread := deg_to_rad(float(w.spread) * 1.4 + 2.0) * (randf() - 0.5)
		var bolt := Projectile.new()
		bolt.setup(raid, origin, aim.rotated(spread), float(w.speed) * 0.8, dmg, float(w.range), false, "enemy_bolt")
		raid.fx_layer.add_child(bolt)
		if Net.is_host():
			Net.fired(origin, bolt.vel.normalized(), float(w.speed) * 0.8, float(w.range), "enemy_bolt", true)
	Sfx.play_at(DB.shot_sfx(weapon), global_position, -5.0, 0.1)
	FX.muzzle(raid.fx_layer, origin, aim, str(w.ammo) == "shell")
	raid.emit_noise(global_position, minf(float(w.noise), 500.0))
	shot_flash = 0.12

func _begin_windup(t: float, charge: bool = false) -> void:
	windup = t
	windup_total = t
	_charge_pending = charge
	if type == "bulldog" and not charge:
		Sfx.play_at("growl", global_position, -4.0)

func _release_attack() -> void:
	var p = _cur()
	if p == null or dead:
		return
	var to: Vector2 = p.global_position - global_position
	attack_cd = float(data.attack_cd)
	if gunner:
		var w: Dictionary = DB.WEAPONS[weapon]
		attack_cd = maxf(float(data.attack_cd) * 0.8, float(w.rate) * 3.0)
		_shoot_weapon()
		if bool(w.auto):
			_burst = 3
			_burst_t = maxf(float(w.rate), 0.08)
		return
	if _charge_pending:
		_charge_pending = false
		charge_t = 0.55
		charge_dir = to.normalized()
		Sfx.play_at("charge", global_position, -2.0)
		return
	match type:
		"hyena":
			lunge = 0.18
			velocity += to.normalized() * 380.0
			if to.length() <= float(data.attack_range) + 18.0:
				p.take_damage(float(data.dmg), global_position)
			Sfx.play_at("bite", global_position, -4.0)
		"bulldog":
			lunge = 0.25
			var hit_pos := global_position + Vector2(0, -16) + to.normalized() * 42.0
			FX.ring(raid.fx_layer, hit_pos, 80.0, Color(1, 0.9, 0.7, 0.8), 0.35)
			FX.dust(raid.fx_layer, hit_pos, 10)
			raid.shake(6.0)
			Sfx.play_at("slam", global_position, 0.0)
			if (p.global_position + Vector2(0, -16)).distance_to(hit_pos) <= 70.0:
				p.take_damage(float(data.dmg), global_position)
		"cat":
			var bolt := Projectile.new()
			var origin := global_position + hand.position + aim * Sprites.muzzle_dist(sprite_kind, "sniper")
			bolt.setup(raid, origin, aim.rotated(randf_range(-0.04, 0.04)), 760.0, float(data.dmg), 700.0, false, "enemy_bolt")
			raid.fx_layer.add_child(bolt)
			if Net.is_host():
				Net.fired(origin, bolt.vel.normalized(), 760.0, 700.0, "enemy_bolt", true)
			Sfx.play_at("shot_pistol", global_position, -6.0, 0.1)
			FX.muzzle(raid.fx_layer, origin, aim, false)
			raid.emit_noise(global_position, 120.0)

func _check_charge_hit() -> void:
	var p = _cur()
	if p and global_position.distance_to(p.global_position) < 44.0:
		p.take_damage(float(data.dmg) * 0.8, global_position)
		charge_t = 0.0
		raid.shake(8.0)

func _seek_cover() -> void:
	# 플레이어 시야에서 벗어난 근처 지점으로 숨기
	var p = _cur()
	for i in 14:
		var cand: Vector2 = raid.random_floor_near(global_position, 5)
		if not raid.has_los(cand + Vector2(0, -16), p.global_position + Vector2(0, -20)):
			target_pos = cand
			path = PackedVector2Array()
			cover_t = 2.6
			_set_state(S.COVER)
			return
	cover_t = -3.0

# ── 피격·사망 ────────────────────────────────────────
func stun_for(t: float) -> void:
	stun = maxf(stun, t)
	windup = 0.0
	charge_t = 0.0
	lunge = 0.0

func take_damage(amount: float, from_pos: Vector2, kick_force: float) -> void:
	if dead:
		return
	if not _net_hit:
		last_hitter = Net.my_id()
	if puppet:
		# 클라이언트: 맞힌 건 호스트에게 알리고, 여기선 반응만
		flash = 1.0
		show_bar_t = 3.0
		FX.icon_pop(raid.fx_layer, center() + Vector2(randf_range(-8, 8), -radius), "hit")
		Sfx.play_at("hit", global_position, -4.0, 0.15)
		Net.send_hit(net_id, amount, from_pos, kick_force)
		return
	var crit := not is_aware()
	var blocked := shield_blocks(from_pos)
	if blocked:
		amount *= 0.15
		crit = false
		if is_instance_valid(FX.fx3d):
			FX.fx3d.sparks(global_position + aim.normalized() * radius, (from_pos - global_position).normalized(), Color(0.75, 0.88, 1.0), 6, 0.6)
		Sfx.play_at("ricochet", global_position, -6.0, 0.2)
	var prot := armor_prot()
	if prot > 0.0:
		amount *= 1.0 - prot
		if is_instance_valid(FX.fx3d) and randf() < 0.5:
			FX.fx3d.sparks(global_position, (global_position - from_pos).normalized(), Color(1, 0.85, 0.5), 4, 0.9)
			Sfx.play_at("impact_hard", global_position, -10.0, 0.15)
	hp -= amount
	if is_instance_valid(FX.fx3d):
		FX.fx3d.damage_number(global_position, amount, crit, 1.25 if type != "bulldog" else 1.45, blocked)
		if amount >= 40.0:
			FX.fx3d.hitstop(0.03, 0.2)
	Sfx.play_at("impact_flesh", global_position, -6.0, 0.12)
	flash = 1.0
	show_bar_t = 3.0
	knock = (global_position - from_pos).normalized() * kick_force * (0.4 if type == "bulldog" else 1.0)
	FX.icon_pop(raid.fx_layer, center() + Vector2(randf_range(-8, 8), -radius), "crit" if crit else "hit")
	Sfx.play_at("hit", global_position, -4.0, 0.15)
	if windup > 0.0 and type != "bulldog":
		windup = 0.0
	if state != S.CHASE:
		last_seen = from_pos
		_go_search(from_pos, true)
		raid.alert_group(global_position, float(data.group_call) * 0.6, self)
	if hp <= 0.0:
		_die()

func _die() -> void:
	dead = true
	if Net.is_host():
		Net.enemy_died(net_id, last_hitter)
	remove_from_group("enemy")
	FX.fur_puff(raid.fx_layer, center(), data.body, 20)
	if is_instance_valid(FX.fx3d):
		FX.fx3d.kill(global_position, data.body)
	var tint: Color = {"cat_black": Color(0.38, 0.38, 0.44), "cat_white": Color(1.7, 1.7, 1.7)}.get(sprite_kind, Color.WHITE)
	FX.corpse(raid.fx_layer, global_position, sprite_kind, facing < 0.0, tint)
	Sfx.play_at("poof", global_position, -2.0)
	raid.on_enemy_killed(self)
	queue_free()

func roll_loot() -> Array:
	var out := []
	for pair in data.loot:
		if randf() < float(pair[1]):
			out.append(pair[0])
	return out

# ── 그리기 ───────────────────────────────────────────
func _update_visuals() -> void:
	var moving := velocity.length() > 25.0
	var anim := "walk" if moving else "idle"
	if flash > 0.4:
		anim = "hurt"
	elif lunge > 0.0:
		anim = "attack"
	elif windup > 0.0:
		anim = "windup"
	elif icon_t > 0.0 and state != S.PATROL:
		anim = "alert"
	spr.frame = Sprites.char_frame(sprite_kind, anim, walk * (0.55 if moving else 0.3))
	var sq := 1.0 + (sin(walk * 2.2) * 0.03 if moving else sin(Time.get_ticks_msec() / 420.0 + home.x) * 0.02)
	spr.scale = Vector2.ONE * Sprites.char_scale(sprite_kind) * Vector2(1.0 / sq, sq)
	Sprites.face_char_sprite(spr, sprite_kind, facing)
	(spr.material as ShaderMaterial).set_shader_parameter("flash", flash)
	var off := Vector2.ZERO
	if lunge > 0.0:
		off = aim * lunge * 40.0
	if windup > 0.0 and _charge_pending:
		off = Vector2(randf_range(-2, 2), 0)
	if moving:
		off.y -= absf(sin(walk * 1.1)) * 4.0
		spr.rotation = sin(walk * 1.1) * 0.09  # 뒤뚱뒤뚱
	else:
		spr.rotation = 0.0
	spr.position = off
	var wid: String = SPRITES[type][1]
	var flipped := aim.x < 0
	Sprites.aim_weapon_sprite(wspr, sprite_kind, wid, flipped)
	hand.rotation = aim.angle()
	hand.z_index = -1 if aim.y < -0.5 else 1
	var sgn := -1.0 if flipped else 1.0
	wspr.rotation = 0.0
	match type:
		"bulldog":
			if windup > 0.0 and not _charge_pending:
				wspr.rotation = -1.6 * (1.0 - windup / windup_total) * sgn
			elif lunge > 0.0:
				wspr.rotation = 1.2 * (lunge / 0.25) * sgn
		"hyena":
			if windup > 0.0:
				wspr.rotation = -1.0 * (1.0 - windup / windup_total) * sgn
			elif lunge > 0.0:
				wspr.rotation = 1.4 * (lunge / 0.18) * sgn

func _draw_art() -> void:
	# 기절 별
	if stun > 0.0:
		for i in 3:
			var a := Time.get_ticks_msec() / 200.0 + TAU * i / 3.0
			art.draw_circle(Vector2(cos(a) * 14.0, head_y + 6 + sin(a) * 4.0), 3.0, DB.C_LEGEND)
	# 정찰 표시 (솔방울 스킬)
	if raid.player and raid.player.scout_t > 0.0:
		art.draw_arc(Vector2(0, -radius), radius + 14, 0, TAU, 32, Color(1, 0.55, 0.3, 0.8), 2.5, true)
	if raid.view3d:
		# 3D 화면: 표시·이름표는 Char3D의 3D 라벨이 맡고, 공격 예고만 바닥에 그린다
		_draw_windup()
		return
	# 경계 표시
	if state == S.CHASE or (icon_t > 0.0 and state != S.PATROL):
		_mark(Vector2(0, head_y), "!", DB.C_DANGER)
	elif state == S.SUSPICIOUS or state == S.SEARCH:
		_mark(Vector2(0, head_y), "?", DB.C_LEGEND)
	elif awareness > 0.05:
		art.draw_arc(Vector2(0, head_y), 8, -PI * 0.5, -PI * 0.5 + TAU * awareness, 16, DB.C_LEGEND, 3, true)
	# 이름표 (위협도 색)
	if show_bar_t > 0.0 or is_aware():
		var font := FX.font()
		var nm: String = data.name
		var w := font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		art.draw_string_outline(font, Vector2(-w * 0.5, 16), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, Color(0, 0, 0, 0.8))
		art.draw_string(font, Vector2(-w * 0.5, 16), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, data.name_color)
	if show_bar_t > 0.0:
		var bw := 40.0
		art.draw_rect(Rect2(-bw * 0.5 - 1, 20, bw + 2, 6), Color(0, 0, 0, 0.7))
		art.draw_rect(Rect2(-bw * 0.5, 21, bw * clampf(hp / max_hp, 0, 1), 4), DB.C_DANGER)
	_draw_windup()

func _draw_windup() -> void:
	# 공격 예고
	if windup > 0.0:
		var k := 1.0 - windup / windup_total
		if type == "bulldog" and not _charge_pending:
			var hp_pos := Vector2(0, -16) + aim * 42.0
			art.draw_arc(hp_pos, 70, 0, TAU, 40, Color(DB.C_DANGER, 0.25 + k * 0.5), 3, true)
			art.draw_circle(hp_pos, 70 * k, Color(DB.C_DANGER, 0.12))
		elif _charge_pending:
			art.draw_line(Vector2(0, -16), Vector2(0, -16) + aim * 260.0, Color(DB.C_DANGER, 0.2 + k * 0.4), 26 * (1.0 - k) + 6, true)

func _mark(p: Vector2, s: String, c: Color) -> void:
	var bounce := sin(icon_t * 20.0) * 3.0 if icon_t > 0.0 else 0.0
	art.draw_circle(p + Vector2(0, bounce), 11, Art.OUTLINE)
	art.draw_circle(p + Vector2(0, bounce), 9, c)
	var font := FX.font()
	art.draw_string(font, p + Vector2(-4 if s == "!" else -5, 6 + bounce), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)

func _draw_hand() -> void:
	# 저격수 조준선 예고
	if type == "cat" and windup > 0.0:
		var k := 1.0 - windup / windup_total
		var md := Sprites.muzzle_dist(sprite_kind, "sniper")
		hand.draw_line(Vector2(md, 0), Vector2(md + 600, 0), Color(DB.C_DANGER, 0.15 + 0.55 * k), 1.0 + k * 2.0, true)
		hand.draw_circle(Vector2(md, 0), 3 + k * 3, Color(DB.C_DANGER, 0.8))
