class_name Player
extends CharacterBody2D
## 플레이어: 이동·조준·사격·재장전·구르기·근접·상호작용·회복

signal died
signal weapon_changed
signal hurt(from_pos: Vector2)

const WALK_SPEED := 215.0
const SPRINT_SPEED := 305.0
const DODGE_SPEED := 600.0
const DODGE_TIME := 0.3
const DODGE_IFRAMES := 0.24
const DODGE_COST := 26.0
const SPRINT_DRAIN := 22.0
const STAMINA_REGEN := 30.0

var raid: Raid
var max_hp := 100.0
var hp := 100.0
var stamina := 100.0

var weapons: Array = []           # 휴대 무기 id (사망 시 잃음)
var mags := {}                    # 무기 id -> 탄창에 든 탄
var reserve := {"pistol": 0, "shell": 0, "bolt": 0}
var cur := 0
var fire_cd := 0.0
var reload_t := 0.0
var reload_total := 0.0
var melee_cd := 0.0
var melee_anim := 0.0
var dodge_t := 0.0
var dodge_dir := Vector2.ZERO
var iframes := 0.0
var exhausted := false
var flash := 0.0
var recoil := 0.0
var walk_phase := 0.0
var facing := 1.0
var aim_dir := Vector2.RIGHT
var mood := ""
var mood_t := 0.0
var muzzle_t := 0.0
var heal_t := 0.0
var heal_total := 0.0
var heal_item := ""
var muddy := 0.0
var step_acc := 0.0
var input_locked := false
var dead := false
var kills := 0

var SPRITE := "hamster"
var hid := "baragi"          # 선택한 햄스터 (DB.HAMSTERS)
var hdata: Dictionary = {}
var crouching := false
var skill_cd := 0.0
var buffs := {}              # 버프 이름 -> 남은 시간 (rally, carrot, nut, seed)
var cloak_t := 0.0
var scout_t := 0.0
var dash_t := 0.0
var dash_dir := Vector2.ZERO
var dash_hit := []
var burrow_t := 0.0
var burrow_from := Vector2.ZERO
var burrow_to := Vector2.ZERO
var mines: Array = []
var gun: Node2D
var gun_spr: Sprite2D
var gun_shown := ""
var body_art: Node2D
var shadow_node: Node2D
var rig: Node2D
var spr: Sprite2D
var light: PointLight2D

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 4
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 14
	shape.shape = circle
	shape.position = Vector2(0, -8)
	add_child(shape)
	shadow_node = Node2D.new()
	shadow_node.draw.connect(func(): Art.shadow(shadow_node, Vector2.ZERO, 17, 6))
	add_child(shadow_node)
	rig = Node2D.new()
	rig.position = Vector2(0, -40)
	add_child(rig)
	spr = Sprite2D.new()
	Sprites.setup_char_sprite(spr, SPRITE)
	spr.position = Vector2(0, 40)
	spr.material = Sprites.flash_material()
	rig.add_child(spr)
	body_art = Node2D.new()
	body_art.draw.connect(_draw_body)
	add_child(body_art)
	gun = Node2D.new()
	gun.position = Vector2(0, -22)
	gun.draw.connect(_draw_gun)
	add_child(gun)
	gun_spr = Sprite2D.new()
	gun_spr.material = spr.material
	gun.add_child(gun_spr)
	light = PointLight2D.new()
	light.texture = FX.light_texture()
	light.texture_scale = 5.0
	light.energy = 0.12
	light.color = Color("#FFE8C8")
	light.position = Vector2(0, -20)
	add_child(light)
	var cam := Camera2D.new()
	cam.name = "Camera"
	cam.zoom = Vector2(1.2, 1.2)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 9.0
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = LevelData.width() * DB.TILE
	cam.limit_bottom = LevelData.height() * DB.TILE
	add_child(cam)

func setup(kit: Dictionary) -> void:
	hid = str(kit.get("hamster", "baragi"))
	if not DB.HAMSTERS.has(hid):
		hid = "baragi"
	hdata = DB.HAMSTERS[hid]
	max_hp = float(hdata.hp)
	hp = max_hp
	SPRITE = "hamster_" + hid
	if Sprites.char_info(SPRITE).is_empty():
		SPRITE = "hamster"
	Sprites.setup_char_sprite(spr, SPRITE)
	weapons = kit.weapons.duplicate()
	reserve = kit.ammo.duplicate()
	for wid in weapons:
		var w: Dictionary = DB.WEAPONS[wid]
		var n := mini(int(w.mag), int(reserve[w.ammo]))
		mags[wid] = n
		reserve[w.ammo] = int(reserve[w.ammo]) - n
	cur = 0
	weapon_changed.emit()

func current_weapon() -> String:
	if weapons.is_empty():
		return ""
	return weapons[cur]

func camera() -> Camera2D:
	return get_node("Camera") as Camera2D

# ── 메인 루프 ────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if dead:
		return
	_timers(delta)
	var mouse := raid.mouse_world()
	var raw_aim := (mouse - (global_position + Vector2(0, -24)))
	if raw_aim.length() > 4.0:
		aim_dir = _aim_assist(raw_aim.normalized())
	if absf(aim_dir.x) > 0.15:
		facing = signf(aim_dir.x)

	var move := Vector2.ZERO
	if not input_locked:
		move = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	# 웅크리기 토글
	if not input_locked and Input.is_action_just_pressed("crouch"):
		crouching = not crouching
		Sfx.play("pick", -10.0)
	# 스킬 이동 (돌진 · 굴)
	if dash_t > 0.0:
		dash_t -= delta
		velocity = dash_dir * 760.0
		iframes = maxf(iframes, 0.05)
		_dash_hits()
		move_and_slide()
		_update_visuals()
		return
	if burrow_t > 0.0:
		burrow_t -= delta
		var bk := 1.0 - maxf(0.0, burrow_t) / 0.55
		global_position = burrow_from.lerp(burrow_to, bk)
		iframes = maxf(iframes, 0.05)
		if fmod(burrow_t, 0.08) < delta:
			FX.dust(raid.fx_layer, global_position, 3)
		rig.visible = burrow_t <= 0.0
		shadow_node.visible = burrow_t <= 0.0
		if burrow_t <= 0.0:
			FX.dust(raid.fx_layer, global_position, 10)
			Sfx.play("rummage", -4.0)
		return
	# 구르기
	if dodge_t > 0.0:
		dodge_t -= delta
		velocity = dodge_dir * DODGE_SPEED * (0.55 + dodge_t / DODGE_TIME * 0.6)
	else:
		var sprinting := Input.is_action_pressed("sprint") and move != Vector2.ZERO and not exhausted and heal_t <= 0.0 and not input_locked
		if sprinting:
			crouching = false
		var spd := (SPRINT_SPEED if sprinting else WALK_SPEED) * speed_mul()
		if heal_t > 0.0:
			spd *= 0.45
		if reload_t > 0.0:
			spd *= 0.85
		velocity = velocity.lerp(move * spd, 1.0 - exp(-delta * 18.0))
		if sprinting and not buffs.has("seed"):
			stamina -= SPRINT_DRAIN * delta
			if stamina <= 0.0:
				stamina = 0.0
				exhausted = true
		elif stamina < 100.0:
			stamina = minf(100.0, stamina + STAMINA_REGEN * delta * (0.6 if move != Vector2.ZERO else 1.0) * (1.6 if buffs.has("rally") else 1.0))
		if exhausted and stamina > 35.0:
			exhausted = false
		if not input_locked and Input.is_action_just_pressed("dodge") and stamina >= _dodge_cost() * 0.5:
			_start_dodge(move if move != Vector2.ZERO else aim_dir)
		_footsteps(delta, move, sprinting)
	move_and_slide()

	if not input_locked:
		_handle_combat_input()
	walk_phase += delta * (9.0 if velocity.length() > 30 else 2.0)
	body_art.queue_redraw()
	gun.queue_redraw()
	_update_visuals()

func _timers(delta: float) -> void:
	fire_cd = maxf(0.0, fire_cd - delta)
	melee_cd = maxf(0.0, melee_cd - delta)
	melee_anim = maxf(0.0, melee_anim - delta)
	iframes = maxf(0.0, iframes - delta)
	flash = maxf(0.0, flash - delta * 5.0)
	recoil = lerpf(recoil, 0.0, 1.0 - exp(-delta * 14.0))
	muzzle_t = maxf(0.0, muzzle_t - delta)
	muddy = maxf(0.0, muddy - delta)
	skill_cd = maxf(0.0, skill_cd - delta)
	cloak_t = maxf(0.0, cloak_t - delta)
	scout_t = maxf(0.0, scout_t - delta)
	for b in buffs.keys():
		buffs[b] = float(buffs[b]) - delta
		if float(buffs[b]) <= 0.0:
			buffs.erase(b)
	if mood_t > 0.0:
		mood_t -= delta
		if mood_t <= 0.0:
			mood = ""
	if reload_t > 0.0:
		reload_t -= delta * (1.6 if buffs.has("rally") else 1.0)
		if reload_t <= 0.0:
			_finish_reload()
	if heal_t > 0.0:
		heal_t -= delta
		if heal_t <= 0.0:
			_finish_heal()

func _aim_assist(dir: Vector2) -> Vector2:
	# 조준선이 적을 가리키면 살짝 스냅
	var best: Node2D = null
	var best_dot := cos(deg_to_rad(9.0))
	var origin := global_position + Vector2(0, -24)
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.dead:
			continue
		var to: Vector2 = (e.global_position + Vector2(0, -20)) - origin
		var dist := to.length()
		if dist > 700.0 or dist < 10.0:
			continue
		var d := dir.dot(to / dist)
		if d > best_dot and raid.has_los(origin, e.global_position + Vector2(0, -20)):
			best_dot = d
			best = e
	if best:
		var to2: Vector2 = ((best.global_position + Vector2(0, -20)) - origin).normalized()
		return dir.lerp(to2, 0.55).normalized()
	return dir

func _start_dodge(dir: Vector2) -> void:
	dodge_dir = dir.normalized()
	dodge_t = DODGE_TIME
	iframes = DODGE_IFRAMES
	stamina = maxf(0.0, stamina - _dodge_cost())
	crouching = false
	cancel_heal()
	Sfx.play("dodge", -4.0)
	raid.emit_noise(global_position, 140.0)
	FX.dust(raid.fx_layer, global_position, 6)

func _footsteps(delta: float, move: Vector2, sprinting: bool) -> void:
	if move == Vector2.ZERO:
		return
	step_acc += delta * (3.6 if sprinting else (1.6 if crouching else 2.6))
	if step_acc >= 1.0:
		step_acc = 0.0
		var tile := raid.tile_at(global_position)
		var nm := float(hdata.get("noise", 1.0))
		# 풀숲을 서서 지나가면 풀이 흔들려 위치가 드러난다
		if tile == "g" and not crouching:
			FX.rustle(raid.fx_layer, global_position)
			raid.emit_noise(global_position, 150.0 * nm)
		# 짐이 무거우면 발소리가 커진다
		if raid.bag.load_ratio() > 0.75 and not crouching:
			raid.emit_noise(global_position, 170.0 * nm)
			Sfx.play("step", -16.0, 0.2)
		if tile == "m" or tile == "w":
			muddy = 6.0
		if muddy > 0.0 or tile == "g":
			FX.footprint(raid.fx_layer, global_position + Vector2(0, -2), velocity.angle(), tile == "w")
		if sprinting:
			raid.emit_noise(global_position, 260.0 * nm)
			Sfx.play("step", -14.0, 0.15)
		elif tile == "w" and not crouching:
			raid.emit_noise(global_position, 150.0 * nm)
			Sfx.play("splash", -12.0, 0.15)

# ── 전투 ─────────────────────────────────────────────
func _handle_combat_input() -> void:
	if Input.is_action_just_pressed("weapon_1") and weapons.size() >= 1:
		_switch(0)
	if Input.is_action_just_pressed("weapon_2") and weapons.size() >= 2:
		_switch(1)
	if Input.is_action_just_pressed("reload"):
		start_reload()
	if Input.is_action_just_pressed("melee"):
		_melee()
	if Input.is_action_just_pressed("heal"):
		try_heal()
	if Input.is_action_just_pressed("eat"):
		try_eat()
	if Input.is_action_just_pressed("skill"):
		use_skill()
	if Input.is_action_pressed("fire") and not raid.mouse_over_ui():
		_fire()

func _switch(i: int) -> void:
	if i == cur:
		return
	cur = i
	reload_t = 0.0
	fire_cd = 0.25
	Sfx.play("switch", -8.0)
	weapon_changed.emit()

func _fire() -> void:
	var wid := current_weapon()
	if wid == "" or fire_cd > 0.0 or reload_t > 0.0 or dodge_t > 0.0 or heal_t > 0.0:
		return
	cloak_t = 0.0  # 쏘면 은신이 풀린다
	var w: Dictionary = DB.WEAPONS[wid]
	if hid == "baragi":
		w = w.duplicate()
		w.recoil = float(w.recoil) * 0.9
	if int(mags[wid]) <= 0:
		fire_cd = 0.3
		Sfx.play("empty", -6.0)
		start_reload()
		return
	mags[wid] = int(mags[wid]) - 1
	fire_cd = w.rate
	var origin := gun.global_position + aim_dir * Sprites.muzzle_dist(SPRITE, wid)
	for i in int(w.pellets):
		var spread := deg_to_rad(float(w.spread)) * (randf() - 0.5)
		var dir := aim_dir.rotated(spread + deg_to_rad(recoil) * (randf() - 0.5))
		var p := Projectile.new()
		p.setup(raid, origin, dir, float(w.speed) * randf_range(0.92, 1.05), float(w.dmg), float(w.range), true, wid)
		p.kick = float(w.kick) / float(w.pellets)
		if w.has("pierce"):
			p.pierce = int(w.pierce)
		if w.get("recover", false):
			p.recoverable = true
		raid.fx_layer.add_child(p)
	recoil = minf(recoil + float(w.recoil), 20.0)
	muzzle_t = 0.06
	raid.shake(float(w.recoil) * 0.55)
	raid.emit_noise(global_position, float(w.noise))
	Sfx.play("shot_" + wid, -2.0, 0.08)
	FX.muzzle(raid.fx_layer, origin, aim_dir, wid == "shotgun")
	if wid != "crossbow":
		FX.shell(raid.fx_layer, global_position + Vector2(0, -22), -facing)
	velocity -= aim_dir * float(w.recoil) * 6.0
	weapon_changed.emit()

func start_reload() -> void:
	var wid := current_weapon()
	if wid == "" or reload_t > 0.0:
		return
	var w: Dictionary = DB.WEAPONS[wid]
	if int(mags[wid]) >= int(w.mag):
		return
	if int(reserve[w.ammo]) <= 0:
		raid.notify("%s 탄약이 없다!" % DB.ITEMS["ammo_" + str(w.ammo)].name, DB.C_DANGER)
		return
	reload_total = float(w.reload)
	reload_t = reload_total
	cancel_heal()
	Sfx.play("reload", -5.0)
	weapon_changed.emit()

func _finish_reload() -> void:
	var wid := current_weapon()
	if wid == "":
		return
	var w: Dictionary = DB.WEAPONS[wid]
	var need: int = int(w.mag) - int(mags[wid])
	var take := mini(need, int(reserve[w.ammo]))
	mags[wid] = int(mags[wid]) + take
	reserve[w.ammo] = int(reserve[w.ammo]) - take
	Sfx.play("reload_done", -6.0)
	weapon_changed.emit()

func _melee() -> void:
	if melee_cd > 0.0 or dodge_t > 0.0:
		return
	var m: Dictionary = DB.MELEE
	melee_cd = float(m.cooldown) * (0.5 if hid == "meokmul" else 1.0)
	cloak_t = 0.0
	melee_anim = 0.22
	cancel_heal()
	Sfx.play("swing", -4.0, 0.1)
	raid.emit_noise(global_position, float(m.noise))
	var origin := global_position + Vector2(0, -18)
	var hit_any := false
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.dead:
			continue
		var to: Vector2 = (e.global_position + Vector2(0, -16)) - origin
		if to.length() > float(m.range) + float(e.radius):
			continue
		if rad_to_deg(absf(aim_dir.angle_to(to))) > float(m.arc) * 0.5:
			continue
		# 몰래 뒤에서 치면 암습 2.5배
		var dmg := float(m.dmg)
		if not e.is_aware():
			dmg *= 2.5
			raid.notify("암습!", DB.C_LEGEND)
		e.take_damage(dmg, origin, float(m.kick))
		hit_any = true
	if hit_any:
		raid.shake(5.0)
		Sfx.play("melee_hit", -2.0, 0.1)
	FX.swoosh(raid.fx_layer, origin, aim_dir)

# ── 회복 ─────────────────────────────────────────────
func try_heal() -> void:
	if heal_t > 0.0 or hp >= max_hp:
		return
	var bag: Backpack = raid.bag
	var pick := ""
	if max_hp - hp >= 60.0 and bag.find_first("medkit") >= 0:
		pick = "medkit"
	elif bag.find_first("bandage") >= 0:
		pick = "bandage"
	elif bag.find_first("medkit") >= 0:
		pick = "medkit"
	if pick == "":
		raid.notify("회복 아이템이 없다", DB.C_MUTED)
		return
	use_item(pick)

func use_item(id: String) -> bool:
	var it: Dictionary = DB.ITEMS[id]
	if not it.has("use") or heal_t > 0.0:
		return false
	var idx: int = raid.bag.find_first(id)
	if idx < 0:
		return false
	heal_item = id
	heal_total = 2.0 if id == "medkit" else (1.3 if it.cat == "med" else float(it.get("eat", 0.8)))
	if hid == "marshmallow":
		heal_total *= 0.5
	heal_t = heal_total
	reload_t = 0.0
	Sfx.play("heal_start", -6.0)
	return true

func _finish_heal() -> void:
	var idx: int = raid.bag.find_first(heal_item)
	if idx < 0:
		return
	raid.bag.remove_at(idx)
	var u: Dictionary = DB.ITEMS[heal_item].use
	if u.has("heal"):
		hp = minf(max_hp, hp + float(u.heal))
	if u.has("stamina"):
		stamina = minf(100.0, stamina + float(u.stamina))
		exhausted = false
	match str(u.get("buff", "")):
		"seed": buffs["seed"] = 3.0
		"carrot": buffs["carrot"] = 8.0
		"nut": buffs["nut"] = 10.0
	if heal_item == "cheese":
		raid.emit_noise(global_position, 200.0)  # 치즈 냄새
	FX.heal_burst(raid.fx_layer, global_position + Vector2(0, -30))
	Sfx.play("heal", -4.0)
	set_mood("happy", 1.0)
	heal_item = ""

func cancel_heal() -> void:
	if heal_t > 0.0:
		heal_t = 0.0
		heal_item = ""

func add_ammo(kind: String, n: int) -> void:
	reserve[kind] = int(reserve.get(kind, 0)) + n
	weapon_changed.emit()

func set_mood(m: String, t: float) -> void:
	mood = m
	mood_t = t

# ── 피격 ─────────────────────────────────────────────
func take_damage(amount: float, from_pos: Vector2) -> void:
	if dead or iframes > 0.0:
		if iframes > 0.0 and dodge_t > 0.0:
			raid.perfect_dodge()
		return
	if buffs.has("nut"):
		amount *= 0.8
	cloak_t = 0.0
	hp -= amount
	flash = 1.0
	iframes = 0.18
	set_mood("hurt", 0.7)
	cancel_heal()
	var dir := (global_position - from_pos).normalized()
	velocity += dir * 260.0
	raid.shake(7.0)
	Sfx.play("hurt", -2.0, 0.1)
	hurt.emit(from_pos)
	if hp <= 0.0:
		hp = 0.0
		dead = true
		FX.fur_puff(raid.fx_layer, global_position + Vector2(0, -20), DB.C_HERO, 26)
		body_art.visible = false
		gun.visible = false
		rig.visible = false
		shadow_node.visible = false
		died.emit()

# ── 햄스터다움: 속도·은신·간식 ───────────────────────
func speed_mul() -> float:
	var m := float(hdata.get("speed", 1.0))
	var lr: float = raid.bag.load_ratio()
	if lr > 0.5:
		m *= 1.0 - (lr - 0.5) * 0.5   # 최대 -25%
	if crouching:
		m *= 0.5
	if buffs.has("carrot"):
		m *= 1.25
	if buffs.has("rally"):
		m *= 1.1
	return m

func _dodge_cost() -> float:
	return DODGE_COST * (0.6 if hid == "toto" else 1.0)

## 고양이 시야 배율: 웅크리면 작아서 잘 안 보이고, 풀숲에 웅크리면 거의 안 보인다
func visibility() -> float:
	var v := 1.0
	var tile := raid.tile_at(global_position)
	if crouching:
		v = 0.3 if tile == "g" else 0.6
	elif tile == "g":
		v = 0.8
	if hid == "moka" and raid.vision_mul < 0.95:
		v *= 0.8
	return v

func try_eat() -> void:
	if heal_t > 0.0:
		return
	var order := ["sunflower_seed", "nut_mix", "cheese", "carrot_juice", "canned_food", "churu", "energy_drink"]
	if hp < max_hp * 0.5:
		order = ["cheese", "canned_food", "churu", "nut_mix", "sunflower_seed", "carrot_juice", "energy_drink"]
	for id in order:
		if raid.bag.find_first(id) >= 0:
			use_item(id)
			return
	raid.notify("먹을 간식이 없다", DB.C_MUTED)

# ── 전술 스킬 (F) ─────────────────────────────────────
func use_skill() -> void:
	if hdata.is_empty() or dodge_t > 0.0:
		return
	if skill_cd > 0.0:
		Sfx.play("deny", -8.0)
		return
	var ok := true
	match str(hdata.skill):
		"rally":
			buffs["rally"] = 8.0
			raid.emit_noise(global_position, 280.0)
			FX.ring(raid.fx_layer, global_position + Vector2(0, -10), 90.0, DB.C_HERO, 0.6)
			Sfx.play("perfect", -4.0)
		"scout":
			scout_t = 12.0
			FX.ring(raid.fx_layer, global_position, 400.0, Color(1, 0.6, 0.3, 0.6), 0.9)
			Sfx.play("switch", -2.0)
		"cloak":
			cloak_t = 5.0
			FX.dust(raid.fx_layer, global_position, 8)
			Sfx.play("pick", -2.0)
		"bomb":
			var target := global_position + (raid.mouse_world() - global_position).limit_length(6.0 * DB.TILE)
			SkillObj.spawn(raid, "bomb", global_position + Vector2(0, -20), target)
			Sfx.play("swing", -2.0)
		"mine":
			mines = mines.filter(func(mn): return is_instance_valid(mn))
			if mines.size() >= 3:
				mines[0].queue_free()
				mines.remove_at(0)
			mines.append(SkillObj.spawn(raid, "mine", global_position))
			Sfx.play("place", -2.0)
		"snack":
			SkillObj.spawn(raid, "snack", global_position)
			Sfx.play("heal_start", -2.0)
		"dash":
			if stamina < 25.0:
				ok = false
			else:
				stamina -= 25.0
				dash_dir = aim_dir
				dash_t = 4.0 * DB.TILE / 760.0
				dash_hit = []
				Sfx.play("charge", -2.0)
				raid.shake(4.0)
		"burrow":
			var dest := _burrow_target()
			if dest == Vector2.INF:
				ok = false
			else:
				burrow_from = global_position
				burrow_to = dest
				burrow_t = 0.55
				FX.dust(raid.fx_layer, global_position, 12)
				Sfx.play("rummage", -2.0)
	if not ok:
		Sfx.play("deny", -6.0)
		raid.notify("지금은 쓸 수 없다", DB.C_MUTED)
		return
	skill_cd = float(hdata.cd)
	cancel_heal()

func _dash_hits() -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.dead or dash_hit.has(e):
			continue
		if e.global_position.distance_to(global_position) < 40.0 + float(e.radius):
			dash_hit.append(e)
			e.take_damage(25.0, global_position, 520.0)
			if not e.dead:
				e.stun_for(1.2)
			raid.shake(6.0)
			Sfx.play("melee_hit", -2.0, 0.1)

## 조준 방향으로 최대 6칸, 막히지 않은 가장 먼 칸
func _burrow_target() -> Vector2:
	for i in range(12, 1, -1):
		var p := global_position + aim_dir * (DB.TILE * 0.5 * i)
		var c: Vector2i = raid.cell_of(p)
		if c.x < 0 or c.y < 0 or c.x >= LevelData.width() or c.y >= LevelData.height():
			continue
		if LevelData.is_solid_code(LevelData.code(c.x, c.y)):
			continue
		return Vector2(c.x * DB.TILE + DB.TILE * 0.5, c.y * DB.TILE + DB.TILE * 0.8)
	return Vector2.INF

# ── 그리기 ───────────────────────────────────────────
func _update_visuals() -> void:
	# 몸 스프라이트 — 조준 방향에 따라 옆/정면/뒷모습 (시트 스프라이트)
	var moving := velocity.length() > 30.0
	var view := ""
	if aim_dir.y > 0.62:
		view = "_front"
	elif aim_dir.y < -0.62:
		view = "_back"
	var anim := ("walk" if moving else "idle") + view
	var t := walk_phase * (0.62 if moving else 0.35)
	if dodge_t > 0.0:
		anim = "dodge"
	elif mood == "hurt" or flash > 0.4:
		anim = "hurt"
	elif heal_t > 0.0:
		anim = "heal"
	elif mood == "happy":
		anim = "happy"
	elif view == "" and not moving and muzzle_t > 0.0:
		anim = "aim"
	spr.frame = Sprites.char_frame(SPRITE, anim, t)
	var face := facing
	if view != "":
		face = 1.0 if aim_dir.x >= 0.0 else -1.0
	Sprites.face_char_sprite(spr, SPRITE, face)
	(spr.material as ShaderMaterial).set_shader_parameter("flash", flash)
	# 걷기 통통 + 숨쉬기
	var bob := 0.0
	var sq := 1.0
	if moving and dodge_t <= 0.0:
		bob = -absf(sin(walk_phase * PI * 0.62)) * 3.0
		sq = 1.0 + sin(walk_phase * TAU * 0.62) * 0.025
	else:
		sq = 1.0 + sin(Time.get_ticks_msec() / 380.0) * 0.018
	spr.position = Vector2(0, 40 + bob)
	rig.rotation = 0.0
	rig.scale = Vector2(1.0 / sq, sq)
	if crouching:
		rig.scale *= Vector2(1.08, 0.86)
	rig.modulate.a = 0.35 if cloak_t > 0.0 else 1.0
	if dash_t > 0.0:
		rig.rotation = 0.25 * signf(dash_dir.x if dash_dir.x != 0.0 else 1.0)
	# 총은 시트 스프라이트에 그려져 있고, 근접 베기는 FX.swoosh가 담당
	gun_spr.visible = false
	gun.z_index = 1

func _draw_body() -> void:
	# 회복 진행 원
	if heal_t > 0.0:
		var p := 1.0 - heal_t / heal_total
		body_art.draw_arc(Vector2(0, -74), 11, -PI * 0.5, -PI * 0.5 + TAU * p, 24, Color("#6CCB5F"), 4, true)
		body_art.draw_circle(Vector2(0, -74), 7, Color(0, 0, 0, 0.5))
		body_art.draw_rect(Rect2(-1.5, -79, 3, 10), Color.WHITE)
		body_art.draw_rect(Rect2(-5, -85.5, 10, 3), Color.WHITE)
	if exhausted:
		for i in 3:
			body_art.draw_circle(Vector2(facing * (18 + i * 5), -60 - i * 4 - fmod(walk_phase * 4.0, 6.0)), 2.0 + i * 0.6, Color(1, 1, 1, 0.5))

func _draw_gun() -> void:
	pass
