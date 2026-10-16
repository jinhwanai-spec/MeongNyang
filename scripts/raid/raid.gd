class_name Raid
extends Node2D
## 원정 한 판: 진입 → 탐색·전투·파밍 → 탈출(또는 사망) → 결과

signal finished(result: Dictionary)

const T := DB.TILE
const USE_3D := true   # 3D 화면 (false면 예전 2D/2.5D 화면)
var view3d: View3D
# ── 협동 멀티 ──
var players: Array = []           # 고양이가 노릴 수 있는 햄스터들 (나 + 다른 플레이어)
var remotes := {}                 # peer_id -> RemotePlayer
var enemies_by_id := {}           # 적 네트워크 id -> Enemy
var next_eid := 1

var kit: Dictionary
var player: Player
var bag: Backpack
var lost_bag_nodes: Array = []   # 지난 원정에서 쓰러진 자리에 남은 가방들 (LootContainer)
var lost_bag_data: Array = []
var world: Node2D
var fx_layer: Node2D
var hud: HUD
var inv: InventoryUI
var pause_layer: CanvasLayer
var modulate_node: CanvasModulate
var rain: Node2D
var astar: AStarGrid2D
var exits: Array = []
var exit_b: ExitZone
var generator: Generator
var shutter: Shutter

var time_left := DB.RAID_TIME
var elapsed := 0.0
var storm_k := 0.0
var vision_mul := 1.0
var reinforce_t := 170.0
var focus = null
var channel_target = null
var channel_t := 0.0
var channel_total := 1.0
var channel_hp := 0.0
var extract_active := false
var extract_t := 0.0
var extract_zone: ExitZone
var inv_open := false
var paused_menu := false
var ending := false
var kills := 0
var shake_amt := 0.0
var tut_step := 0
var tut_t := 0.0
var power_on_t := -1.0
var warned_storm := false
var seen_enemy := false

static var weather_now := "clear"   # 이번 원정 날씨 (DB.WEATHER)
static var force_weather := ""      # 테스트용

func setup(k: Dictionary) -> void:
	kit = k
	weather_now = "clear" if Net.active else str(k.get("weather", "clear"))
	if force_weather != "":
		weather_now = force_weather
	if not DB.WEATHER.has(weather_now):
		weather_now = "clear"

const DAY_TINT := Color(0.84, 0.83, 0.9)

func _ready() -> void:
	Sprites.LIFT = Vector3(0.97 / DAY_TINT.r, 0.97 / DAY_TINT.g, 0.97 / DAY_TINT.b)
	bag = Backpack.new()
	bag.has_cheek = true
	for i in int(kit.get("meds", 0)):
		bag.try_add("bandage")
	for sid in kit.get("snacks", []):
		bag.try_add(sid)
	for tid in kit.get("throws", []):
		bag.try_add(tid)
	if Net.in_raid:
		Net.raid = self
		seed(Net.raid_seed)   # 모두 같은 맵·같은 상자 내용
	LevelData.set_region(Net.raid_region if Net.in_raid else str(kit.get("region", "mart")))
	_build_world()
	_build_nav()
	_spawn_entities()
	_build_lighting()
	if USE_3D:
		view3d = View3D.new()
		add_child(view3d)
		view3d.build(self)
	hud = HUD.new()
	hud.raid = self
	add_child(hud)
	player.hurt.connect(hud.on_hurt)
	inv = InventoryUI.new()
	inv.raid = self
	add_child(inv)
	_build_pause()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	Sfx.music("raid")
	Sfx.ambient({"dock": "harbor", "town": "park", "mart": "mart"}.get(LevelData.region, ""), {"mart": -16.0, "town": -12.0}.get(LevelData.region, -10.0))
	tree_exiting.connect(func(): Sfx.ambient(""))
	notify("원정 시작 — " + str(Regions.cur().short), DB.C_HERO)
	if not GameState.tutorial_done:
		hud.show_hint("WASD 이동 · 마우스 조준 · 좌클릭 사격 · Shift 달리기", 8.0)
	else:
		hud.show_hint("탈출이 목표다. 살아서 돌아가자!", 4.0)

# ── 월드 구성 ────────────────────────────────────────
func _build_world() -> void:
	var mr := MapRender.new()
	mr.visible = not USE_3D
	add_child(mr)
	# 벽 충돌 (가로로 이어진 칸을 하나로 합침)
	var walls := StaticBody2D.new()
	walls.collision_layer = 1
	add_child(walls)
	var W := LevelData.width()
	var H := LevelData.height()
	for y in H:
		var x := 0
		while x < W:
			if _is_static_solid(LevelData.code(x, y)):
				var x0 := x
				while x < W and _is_static_solid(LevelData.code(x, y)):
					x += 1
				var cs := CollisionShape2D.new()
				var rs := RectangleShape2D.new()
				rs.size = Vector2((x - x0) * T, T)
				cs.shape = rs
				cs.position = Vector2(x0 * T + (x - x0) * T * 0.5, y * T + T * 0.5)
				walls.add_child(cs)
			else:
				x += 1
	world = Node2D.new()
	world.y_sort_enabled = true
	add_child(world)
	if not USE_3D:
		_build_wall_occluders()
	fx_layer = Node2D.new()
	fx_layer.z_index = 2
	add_child(fx_layer)

# ── 2.5D 벽 가림 ─────────────────────────────────────
## 높게 렌더한 벽(walls.png)을 칸별 띠로 잘라 캐릭터와 깊이 정렬한다.
## 벽 뒤(북쪽)에 서면 벽에 가려지고, 플레이어 주변 벽은 반투명해진다.
const WALLS_TEX := "res://assets/sprites/map/walls.png"
var occ_mat: ShaderMaterial

func _build_wall_occluders() -> void:
	if not ResourceLoader.exists(WALLS_TEX):
		return
	var tex: Texture2D = load(WALLS_TEX)
	var W := LevelData.width()
	var H := LevelData.height()
	var px := float(tex.get_width()) / W
	var hoff := 1.26
	var mp := "res://assets/sprites/map/map_meta.json"
	if FileAccess.file_exists(mp):
		var md = JSON.parse_string(FileAccess.get_file_as_string(mp))
		if md is Dictionary:
			hoff = float(md.get("hoff", hoff))
	occ_mat = ShaderMaterial.new()
	occ_mat.shader = load("res://scripts/raid/wall_occ.gdshader")
	# 칸마다 보이는 세로 구간 [s0, s1] (타일 단위): 바로 남쪽 벽이 앞을 덮는 부분은 뺀다
	var spans := {}  # y -> Array of [x, s0, s1]
	for x in W:
		for y in H:
			if LevelData.code(x, y) != "#":
				continue
			var s0 := maxf(0.0, float(y) - hoff)
			var s1 := float(y + 1)
			var ny := y + 1
			while ny < H and ny < y + 1 + hoff + 1:
				if LevelData.code(x, ny) == "#":
					s1 = minf(s1, float(ny) - hoff)
					break
				ny += 1
			if s1 - s0 < 0.02:
				continue
			if not spans.has(y):
				spans[y] = []
			spans[y].append([x, s0, s1])
	for y in spans:
		var arr: Array = spans[y]
		arr.sort_custom(func(a, b): return a[0] < b[0])
		var i := 0
		while i < arr.size():
			var x0: int = arr[i][0]
			var s0: float = arr[i][1]
			var s1: float = arr[i][2]
			var j := i + 1
			while j < arr.size() and int(arr[j][0]) == int(arr[j - 1][0]) + 1 and is_equal_approx(float(arr[j][1]), s0) and is_equal_approx(float(arr[j][2]), s1):
				j += 1
			var n := j - i  # 가로로 이어진 칸 수
			var spr := Sprite2D.new()
			spr.texture = tex
			spr.centered = false
			spr.region_enabled = true
			spr.region_rect = Rect2(x0 * px, s0 * px, n * px, (s1 - s0) * px)
			spr.scale = Vector2(T / px, T / px)
			spr.position = Vector2(x0 * T, (y + 1) * T)
			spr.offset = Vector2(0, (s0 - float(y + 1)) * px)
			spr.material = occ_mat
			world.add_child(spr)
			i = j

func _update_wall_occ() -> void:
	if occ_mat and player:
		occ_mat.set_shader_parameter("ppos", player.global_position)

func _is_static_solid(c: String) -> bool:
	return "#sQCoXf".contains(c)

func _build_nav() -> void:
	astar = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, LevelData.width(), LevelData.height())
	astar.cell_size = Vector2(T, T)
	astar.offset = Vector2(T * 0.5, T * 0.5)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for y in LevelData.height():
		for x in LevelData.width():
			if LevelData.is_solid_code(LevelData.code(x, y)):
				astar.set_point_solid(Vector2i(x, y), true)

func _spawn_entities() -> void:
	var W := LevelData.width()
	var H := LevelData.height()
	var a_cells := []
	var b_cells := []
	for y in H:
		for x in W:
			var c := LevelData.code(x, y)
			var foot := Vector2(x * T + T * 0.5, y * T + T)
			if DB.MAP_CONTAINER_CODES.has(c):
				if c == "D" and LevelData.code(x - 1, y) == "D":
					continue
				var lc := LootContainer.new()
				lc.setup(self, DB.MAP_CONTAINER_CODES[c], foot)
				world.add_child(lc)
			if DECOR.has(c):
				_spawn_decor(c, x, y)
			match c:
				"p":
					player = Player.new()
					player.raid = self
					player.position = foot - Vector2(0, 8)
					if Net.in_raid:
						player.position += Vector2(T * 0.8 * Net.order_of(Net.my_id()), 0)
					players.append(player)
					world.add_child(player)
					player.setup(kit)
					player.died.connect(_on_player_died)
				"h":
					_spawn_enemy("hyena", foot - Vector2(0, 8))
				"b":
					_spawn_enemy("bulldog", foot - Vector2(0, 8))
				"c":
					_spawn_enemy("cat", foot - Vector2(0, 8))
				"Y":
					var bs: Array = Regions.cur().get("boss", ["bulldog", "항구 대장 흑냥이", "lmg"])
					_spawn_enemy(str(bs[0]), foot - Vector2(0, 8), 0, str(bs[1]), str(bs[2]))
				"G":
					generator = Generator.new()
					generator.raid = self
					generator.position = foot
					world.add_child(generator)
				"H":
					if LevelData.code(x, y - 1) != "H":
						shutter = Shutter.new()
						shutter.position = Vector2(x * T, y * T)
						add_child(shutter)
				"1":
					a_cells.append(Vector2i(x, y))
				"2":
					b_cells.append(Vector2i(x, y))
	for d in Regions.cur().decor:
		var sp: Node2D
		if str(d[0]).begins_with("proc:"):
			# 코드로 만든 3D 소품 (2D 그림 없음): 나무·벤치·놀이터 등
			sp = Node2D.new()
			if d.size() > 4:
				sp.set_meta("prop_rot", float(d[4]))
		else:
			sp = Sprites.make_sprop_sprite(d[0], float(d[3]))
		sp.position = Vector2(float(d[1]) * T, float(d[2]) * T)
		sp.set_meta("prop3d", str(SHEET_TO_3D.get(d[0], d[0])))
		sp.set_meta("prop_off", Vector2(0, -0.25))
		sp.set_meta("prop_scale", float(d[3]))
		world.add_child(sp)
	_spawn_lost_bags()
	_spawn_traps(a_cells + b_cells)
	_spawn_barrels(a_cells + b_cells)
	_plan_supply()
	var rx: Dictionary = Regions.cur().exits
	var ea := _make_exit(str(rx.A[0]), a_cells, 6.0)
	ea.kind = str(rx.A[1])
	ea.locked = false
	var eb := _make_exit(str(rx.B[0]), b_cells, 4.0)
	eb.kind = str(rx.B[1])
	eb.locked = true
	eb.lock_text = str(Regions.cur().lock)
	exit_b = eb

# 시트 소품으로 꾸미는 장식 (충돌 없음): [이름, 타일 x, 타일 y(발 위치), 크기]
const SHEET_DECOR := [
	["lamp", 6.5, 19.3, 1.0], ["lamp", 17.5, 19.3, 1.0], ["lamp", 33.5, 19.3, 1.0], ["lamp", 45.5, 19.3, 1.0], ["lamp", 54.5, 19.3, 1.0],
	["bush", 2.2, 6.6, 0.9], ["bush", 3.4, 12.8, 0.8], ["rock", 1.6, 9.4, 0.9], ["stump", 3.6, 15.2, 0.9], ["bush", 49.5, 20.6, 0.8],
	["cone", 11.6, 20.4, 0.7], ["cone", 12.5, 20.7, 0.7], ["barrier_stripe", 44.8, 2.6, 0.8], ["cone", 26.5, 2.5, 0.7],
	["pallet", 40.5, 31.6, 0.9], ["tires", 44.5, 37.8, 0.9], ["barrier_orange", 51.2, 30.6, 0.8], ["crate_small", 18.6, 33.7, 0.8],
	["cardboard", 20.4, 37.6, 0.8], ["trough", 37.5, 29.6, 0.8], ["rock", 56.2, 33.5, 0.8],
]

## 시트 소품 이름 → 3D 모델 이름
const SHEET_TO_3D := {"crate_blue": "crate", "cardboard": "box", "fence2": "fence", "barrier_orange": "barrier_stripe", "trough": "pallet"}

const DECOR := {"s": "shelf_empty", "Q": "fridge_off", "C": "counter", "o": "crates", "X": "car", "f": "fence", "Z": "proc:container"}

func _spawn_decor(c: String, x: int, y: int) -> void:
	var name_: String = DECOR[c]
	if c == "X" or c == "Z":
		if LevelData.code(x - 1, y) == c:
			return
		name_ = "car%d" % ((x * 7 + y * 3) % 3)
	var sheet := ""
	if c == "o":
		sheet = ["crate", "barrel_red", "sandbags", "crate_blue", "barrel_blue", "tires", "cardboard", "barrier_concrete", "crate_small", "ammo_locker"][(x * 5 + y * 11) % 10]
	elif c == "f":
		var vertical := LevelData.code(x, y - 1) == "f" or LevelData.code(x, y + 1) == "f"
		if vertical:
			sheet = "sandbags"
		else:
			sheet = "fence" if (x + y) % 2 == 0 else "fence2"
	var holder := Node2D.new()
	holder.position = Vector2(x * T + T * 0.5, y * T + T)
	# 3D 모델 이름·방향
	var m3: String = name_ if sheet == "" else str(SHEET_TO_3D.get(sheet, sheet))
	holder.set_meta("prop3d", m3)
	if c == "X" or c == "Z":
		holder.set_meta("prop_off", Vector2(0.5, -0.5))
	if c == "Z":
		holder.set_meta("prop3d", "proc:container_%d" % ((x * 3 + y * 7) % 4))
	var vert := LevelData.code(x, y - 1) == c or LevelData.code(x, y + 1) == c
	if vert and c in ["f", "s", "Q"]:
		holder.set_meta("prop_rot", 90.0)
	if not name_.begins_with("proc:"):
		var spr := Sprites.make_sprop_sprite(sheet) if sheet != "" else Sprites.make_prop_sprite(name_)
		spr.position = Vector2(0, -T * 0.5)
		holder.add_child(spr)
	world.add_child(holder)

# ── 보급 상자: 원정 중간에 한 번(60%) 낙하산으로 떨어진다. 냥이들도 소리를 듣고 몰려온다 ──
var supply_at := -1.0          # 남은 시간이 이 값이 되면 투하 시작
var supply_pos = null          # 지도 표시용 (Vector2 또는 null)
var supply_land_t := -1.0

func _plan_supply() -> void:
	if Net.active or randf() > 0.6:
		return
	supply_at = randf_range(360.0, 600.0)

func _update_supply(delta: float) -> void:
	if supply_at > 0.0 and time_left <= supply_at:
		supply_at = -1.0
		var cand := []
		for y in LevelData.height():
			for x in LevelData.width():
				var c := LevelData.code(x, y)
				if (c == "." or c == "," or c == "g") and LevelData.code(x + 1, y) == c and LevelData.code(x, y + 1) == c:
					var p := Vector2(x * T + T, y * T + T)
					var d := p.distance_to(player.global_position)
					if d > T * 8 and d < T * 22:
						cand.append(p)
		if cand.is_empty():
			return
		supply_pos = cand.pick_random()
		supply_land_t = 7.0
		notify("보급 상자가 떨어진다! 지도에 파란 표시 — 냥이들도 노린다", Color("#7FC8FF"))
		Sfx.play("alarm", -10.0)
		if is_instance_valid(FX.fx3d):
			FX.fx3d.supply_fall(supply_pos, 7.0)
	if supply_land_t > 0.0:
		supply_land_t -= delta
		if supply_land_t <= 0.0:
			var lc := LootContainer.new()
			lc.setup(self, "drop", supply_pos)
			lc.supply = true
			var its := []
			for i in randi_range(4, 6):
				its.append(LootContainer._roll(DB.SUPPLY_TABLE))
			lc.items = its
			world.add_child(lc)
			emit_noise(supply_pos, 700.0)
			Sfx.play_at("slam", supply_pos, 0.0)
			shake(4.0)

# ── 연막: 구름 안이나 너머는 냥이가 못 본다 ──
var smokes: Array = []   # [중심, 반지름, 남은 시간]

func add_smoke(pos: Vector2, radius: float, dur: float) -> void:
	smokes.append([pos, radius, dur])
	if is_instance_valid(FX.fx3d):
		FX.fx3d.smoke_cloud(pos, radius, dur)
	emit_noise(pos, 180.0)

func smoke_blocks(a: Vector2, b: Vector2) -> bool:
	for sm in smokes:
		var c: Vector2 = sm[0]
		var r: float = sm[1]
		if a.distance_to(c) < r or b.distance_to(c) < r:
			return true
		var ab := b - a
		var l2 := ab.length_squared()
		if l2 < 1.0:
			continue
		var k := clampf((c - a).dot(ab) / l2, 0.0, 1.0)
		if (a + ab * k).distance_to(c) < r * 0.9:
			return true
	return false

func _update_smokes(delta: float) -> void:
	for sm in smokes:
		sm[2] -= delta
	smokes = smokes.filter(func(sm): return sm[2] > 0.0)

# ── 보스 등장 알림 (처음 마주쳤을 때 한 번) ──
var _boss_seen := {}
func _update_boss_intro() -> void:
	if Engine.get_physics_frames() % 10 != 0:
		return
	for e in get_tree().get_nodes_in_group("enemy"):
		if not e.elite or e.dead or _boss_seen.has(e):
			continue
		if e.is_aware() or e.global_position.distance_to(player.global_position) < T * 7.0:
			_boss_seen[e] = true
			notify("보스 등장! — %s" % str(e.data.name), DB.C_DANGER)
			Sfx.play("alarm", -6.0)
			shake(6.0)

# ── 쥐덫: 실내 바닥 곳곳. 서서 밟으면 '탁!' (피해·발 묶임·큰 소리), 웅크려 다가가면 미끼 치즈만 쏙 ──
var traps: Array = []   # [Node2D, 위치, 튕겼나]
var _trap_hint := false

func _spawn_traps(exit_cells: Array) -> void:
	if Net.active:
		return
	var cand := []
	for y in LevelData.height():
		for x in LevelData.width():
			var c := LevelData.code(x, y)
			if c != "_" and c != "=":
				continue
			# 벽·상자 바로 옆은 피하고, 사방이 바닥인 칸만
			var ok := true
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n := LevelData.code(x + d.x, y + d.y)
				if n != "_" and n != "=":
					ok = false
			if not ok:
				continue
			var far := true
			for ec in exit_cells:
				if Vector2i(ec).distance_to(Vector2i(x, y)) < 4.0:
					far = false
			if far and player and player.global_position.distance_to(Vector2(x * T + T * 0.5, y * T + T * 0.5)) > T * 6:
				cand.append(Vector2i(x, y))
	cand.shuffle()
	var n := mini(cand.size(), {"mart": 6, "dock": 5, "town": 8}.get(LevelData.region, 6))
	var used := []
	for c in cand:
		if traps.size() >= n:
			break
		var near := false
		for u in used:
			if Vector2i(u).distance_to(c) < 5.0:
				near = true
		if near:
			continue
		used.append(c)
		var pos := Vector2(c.x * T + T * 0.5, c.y * T + T * 0.6)
		traps.append([_trap_node(pos, false), pos, false])

## 빨간 기름통: 창고·주차장 바닥에 몇 개 (가끔 두 개씩 붙어 있어 연쇄 폭발)
func _spawn_barrels(exit_cells: Array) -> void:
	if Net.active:
		return
	var cand := []
	for y in LevelData.height():
		for x in LevelData.width():
			var c := LevelData.code(x, y)
			if c != "=" and c != ".":
				continue
			var ok := true
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1)]:
				var n := LevelData.code(x + d.x, y + d.y)
				if n != c:
					ok = false
			for ec in exit_cells:
				if Vector2i(ec).distance_to(Vector2i(x, y)) < 4.0:
					ok = false
			if ok and player.global_position.distance_to(Vector2(x * T + T * 0.5, y * T + T * 0.5)) > T * 7:
				cand.append(Vector2i(x, y))
	cand.shuffle()
	var want: int = {"mart": 4, "dock": 6, "town": 3}.get(LevelData.region, 4)
	var used := []
	for c in cand:
		if used.size() >= want:
			break
		var near := false
		for u in used:
			if Vector2i(u).distance_to(c) < 6.0:
				near = true
		for tr in traps:
			if cell_of(tr[1]) == c:
				near = true
		if near:
			continue
		used.append(c)
		_add_barrel(c)
		# 절반은 옆에 한 통 더
		var c2: Vector2i = c + Vector2i(1, 0)
		if randf() < 0.5 and LevelData.code(c2.x, c2.y) == LevelData.code(c.x, c.y):
			_add_barrel(c2)

func _contract(ev: String) -> void:
	for c in GameState.contract_event(ev, {"region": LevelData.region}):
		notify("의뢰 완료! %s — 은신처에서 보상 받기" % GameState.contract_text(c), DB.C_LEGEND)
		Sfx.play("pickup_rare", -2.0)

func _add_barrel(c: Vector2i) -> void:
	var b := ExplosiveBarrel.new()
	b.setup(self, Vector2(c.x * T + T * 0.5, c.y * T + T * 0.6), c)
	world.add_child(b)

func _trap_node(pos: Vector2, sprung: bool) -> Node2D:
	var nd := Node2D.new()
	nd.position = pos
	nd.set_meta("prop3d", "proc:mousetrap_sprung" if sprung else "proc:mousetrap")
	nd.set_meta("prop_off", Vector2.ZERO)
	nd.set_meta("prop_scale", 1.5)
	nd.set_meta("prop_rot", float((int(pos.x) * 7 + int(pos.y)) % 4) * 90.0)
	world.add_child(nd)
	return nd

func _update_traps(delta: float) -> void:
	if player.trap_t > 0.0:
		player.trap_t -= delta
	for tr in traps:
		if tr[2]:
			continue
		var d: float = player.global_position.distance_to(tr[1])
		if d < T * 2.2 and not _trap_hint:
			_trap_hint = true
			notify("쥐덫이다! 웅크려(Ctrl) 다가가면 미끼만 빼 올 수 있다", DB.C_LEGEND)
		if d > 18.0 or player.dodge_t > 0.0:
			continue
		tr[2] = true
		(tr[0] as Node2D).queue_free()
		tr[0] = _trap_node(tr[1], true)
		if player.crouching:
			Sfx.play("pick", -4.0)
			if bag.try_add("cheese"):
				notify("쥐덫에서 치즈 미끼를 살짝 빼냈다", Color("#6CCB5F"))
			_contract("bait")
		else:
			Sfx.play("trap_snap", -1.0, 0.08)
			shake(7.0)
			player.take_damage(16.0, tr[1] + Vector2(0, -6))
			player.trap_t = 1.2
			emit_noise(tr[1], 320.0)
			notify("탁! 쥐덫에 걸렸다 — 잠시 못 움직인다", DB.C_DANGER)

## 지난 원정에서 쓰러진 자리의 가방 (협동 중에는 없음)
func _spawn_lost_bags() -> void:
	if Net.active:
		return
	for b in GameState.lost_bags:
		if str(b.get("region", "mart")) != LevelData.region:
			continue
		var lb := LootContainer.new()
		lb.setup(self, "drop", Vector2(float(b.pos[0]), float(b.pos[1])))
		lb.items = (b.items as Array).duplicate()
		lb.lost_bag = true
		lb.drop_color = Color("#D9822B")
		world.add_child(lb)
		lost_bag_nodes.append(lb)
		lost_bag_data.append(b)
	if not lost_bag_nodes.is_empty():
		get_tree().create_timer(2.5).timeout.connect(func():
			if is_instance_valid(hud):
				hud.show_hint("지난번에 쓰러진 자리에 가방이 남아 있다! 노란 표시를 따라가 회수하자", 8.0))

## 쓰러질 때 들고 있던 것 전부 → 가방 아이템 목록
func _death_bag_items(lost: Array) -> Array:
	var out := []
	for wid in player.weapons:
		if DB.ITEMS.has("w_" + str(wid)):
			out.append("w_" + str(wid))
	if player.melee_id != "bat" and DB.ITEMS.has("w_" + player.melee_id):
		out.append("w_" + player.melee_id)
	for aid in [player.helmet, player.vest]:
		if aid != "":
			out.append(aid)
	var ammo_left := player.reserve.duplicate()
	for wid in player.mags:
		var at: String = DB.WEAPONS[wid].ammo
		ammo_left[at] = int(ammo_left.get(at, 0)) + int(player.mags[wid])
	for at in ammo_left:
		var iid := "ammo_" + str(at)
		if not DB.ITEMS.has(iid):
			continue
		var per := int(DB.ITEMS[iid].amount)
		var n := int(ammo_left[at])
		while n > 0:
			out.append(iid)
			n -= per
	for id in lost:
		out.append(id)
	return out

## 이번 원정에 놓여 있던 가방의 남은 내용물
func _remaining_lost_bags() -> Array:
	var out := []
	for i in lost_bag_nodes.size():
		var n = lost_bag_nodes[i]
		var d: Dictionary = (lost_bag_data[i] as Dictionary).duplicate()
		d.items = (n.items as Array).duplicate() if is_instance_valid(n) else []
		out.append(d)
	return out

## 마우스가 가리키는 게임 좌표 (3D 화면이면 바닥과 만나는 점)
func mouse_world() -> Vector2:
	if view3d:
		return view3d.mouse_ground()
	return get_global_mouse_position()

func _make_exit(label: String, cells: Array, need: float) -> ExitZone:
	var mn := Vector2i(9999, 9999)
	var mx := Vector2i(-1, -1)
	for c in cells:
		mn = Vector2i(mini(mn.x, c.x), mini(mn.y, c.y))
		mx = Vector2i(maxi(mx.x, c.x), maxi(mx.y, c.y))
	var ez := ExitZone.new()
	ez.label = label
	ez.need = need
	ez.rect = Rect2(Vector2(mn) * T, Vector2(mx - mn + Vector2i.ONE) * T)
	ez.position = ez.rect.position
	add_child(ez)
	exits.append(ez)
	var l := PointLight2D.new()
	l.texture = FX.light_texture()
	l.texture_scale = 3.0
	l.color = Color("#7CFF8A") if label.begins_with("A") else Color("#FF8A7C")
	l.energy = 0.7
	l.position = ez.rect.size * 0.5
	ez.add_child(l)
	return ez

func _spawn_enemy(t: String, pos: Vector2, eid: int = 0, elite_title: String = "", elite_wpn: String = "lmg") -> Enemy:
	var e := Enemy.new()
	e.setup(self, t, pos)
	if elite_title != "":
		e.make_elite(elite_title, elite_wpn)
	elif t == "bulldog" and not Net.active and LevelData.region != "mart" and (Enemy.force_shield or randf() < 0.35):
		e.make_shield()
	e.net_id = eid if eid > 0 else next_eid
	next_eid = maxi(next_eid, e.net_id) + 1
	e.puppet = Net.is_client()
	enemies_by_id[e.net_id] = e
	world.add_child(e)
	return e

func _build_lighting() -> void:
	modulate_node = CanvasModulate.new()
	modulate_node.color = DAY_TINT
	add_child(modulate_node)
	var lights := [
		[Vector2(14, 8), Color("#FFE9C4"), 3.4, 0.3], [Vector2(23, 8), Color("#FFE9C4"), 3.4, 0.3], [Vector2(31, 7), Color("#CFE8FF"), 3.0, 0.35],
		[Vector2(14, 14), Color("#FFE9C4"), 3.0, 0.24], [Vector2(26, 14), Color("#FFE9C4"), 3.0, 0.24], [Vector2(33, 13), Color("#FFD9A0"), 2.4, 0.4],
		[Vector2(44, 7), Color("#9FB6FF"), 3.4, 0.45], [Vector2(22, 16.6), Color("#FF7FB0"), 4.0, 0.7],
		[Vector2(6.5, 18.2), Color("#FFD89A"), 3.4, 0.6], [Vector2(17.5, 18.2), Color("#FFD89A"), 3.4, 0.6], [Vector2(33.5, 18.2), Color("#FFD89A"), 3.4, 0.6],
		[Vector2(45.5, 18.2), Color("#FFD89A"), 3.4, 0.6], [Vector2(54.5, 18.2), Color("#FFD89A"), 3.4, 0.6],
		[Vector2(20, 33), Color("#FFB070"), 2.6, 0.5], [Vector2(42, 33), Color("#B0C8FF"), 3.0, 0.4],
	]
	var baked := ResourceLoader.exists(MapRender.BAKED)
	for L in lights:
		if baked:
			break  # 블렌더 렌더 맵에 조명이 구워져 있음
		var pl := PointLight2D.new()
		pl.texture = FX.light_texture()
		pl.position = L[0] * T
		pl.color = L[1]
		pl.texture_scale = L[2]
		pl.energy = L[3]
		add_child(pl)
	rain = Node2D.new()
	rain.set_script(load("res://scripts/raid/rain.gd"))
	var rl := CanvasLayer.new()
	rl.layer = 5
	rl.add_child(rain)
	add_child(rl)

func _build_pause() -> void:
	pause_layer = CanvasLayer.new()
	pause_layer.layer = 30
	pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_layer.visible = false
	add_child(pause_layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = UITheme.get_theme()
	pause_layer.add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	vb.custom_minimum_size = Vector2(340, 0)
	panel.add_child(vb)
	vb.add_child(UITheme.label("일시정지", 30, DB.C_TEXT, true))
	var b1 := UITheme.button("계속하기", 20, true)
	b1.pressed.connect(func(): _set_pause(false))
	vb.add_child(b1)
	var keys := UITheme.label("WASD 이동 · 좌클릭 사격 · R 재장전 · Space 구르기\nV 근접 · E 상호작용 · Tab 배낭 · Q 회복 · T 연막 · 우클릭 조준 · M 지도 · 1/2 무기", 14, DB.C_MUTED)
	vb.add_child(keys)
	var b2 := UITheme.button("원정 포기 (장비를 잃음)", 17)
	b2.pressed.connect(func():
		_set_pause(false)
		_end(false, "원정 포기"))
	vb.add_child(b2)
	var b3 := UITheme.button("게임 종료", 17)
	b3.pressed.connect(func(): get_tree().quit())
	vb.add_child(b3)

func _set_pause(on: bool) -> void:
	paused_menu = on
	pause_layer.visible = on
	get_tree().paused = on and not Net.active   # 멀티 중에는 세상이 멈추지 않는다
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if on or inv_open else Input.MOUSE_MODE_HIDDEN

# ── 공용 질의 ────────────────────────────────────────
func has_los(a: Vector2, b: Vector2, thick: float = 0.0) -> bool:
	var space := get_world_2d().direct_space_state
	var offs := [Vector2.ZERO]
	if thick > 0.0:
		var n := (b - a).orthogonal().normalized() * thick
		offs = [n, -n]
	for o in offs:
		var q := PhysicsRayQueryParameters2D.create(a + o, b + o, 1)
		if not space.intersect_ray(q).is_empty():
			return false
	return true

func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(clampi(int(p.x / T), 0, LevelData.width() - 1), clampi(int(p.y / T), 0, LevelData.height() - 1))

func _nearest_open(c: Vector2i) -> Vector2i:
	if not astar.is_point_solid(c):
		return c
	for r in range(1, 4):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var n := c + Vector2i(dx, dy)
				if astar.is_in_boundsv(n) and not astar.is_point_solid(n):
					return n
	return c

func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var a := _nearest_open(cell_of(from - Vector2(0, 10)))
	var b := _nearest_open(cell_of(to - Vector2(0, 10)))
	var pts := astar.get_point_path(a, b, true)
	var out := PackedVector2Array()
	for p in pts:
		out.append(p + Vector2(0, 14))
	return out

func random_floor_near(pos: Vector2, r: int) -> Vector2:
	var c := cell_of(pos - Vector2(0, 10))
	for i in 24:
		var n := c + Vector2i(randi_range(-r, r), randi_range(-r, r))
		if astar.is_in_boundsv(n) and not astar.is_point_solid(n):
			return Vector2(n.x * T + T * 0.5, n.y * T + T * 0.75)
	return pos

func tile_at(p: Vector2) -> String:
	var c := cell_of(p - Vector2(0, 4))
	return LevelData.code(c.x, c.y)

func emit_noise(pos: Vector2, radius: float, share: bool = true) -> void:
	if share and Net.is_client():
		Net.noise(pos, radius)
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.dead:
			continue
		if e.global_position.distance_to(pos) <= radius:
			e.hear(pos, radius)
	if radius >= 400.0:
		FX.ring(fx_layer, pos, radius * 0.5, Color(1, 1, 1, 0.12), 0.5)

func alert_group(pos: Vector2, radius: float, src: Node) -> void:
	if not seen_enemy:
		seen_enemy = true
		if not GameState.tutorial_done:
			hud.show_hint("들켰다! Space 구르기(무적) · V 근접 · R 재장전 · 싸울지 도망칠지 정하자", 7.0)
	for e in get_tree().get_nodes_in_group("enemy"):
		if e == src or e.dead:
			continue
		var d: float = e.global_position.distance_to(pos)
		if d <= radius and (d < radius * 0.6 or has_los(pos + Vector2(0, -16), e.global_position + Vector2(0, -16))):
			e.alert_from_ally(player.global_position)

func mouse_over_ui() -> bool:
	return inv_open or paused_menu

func notify(text: String, color: Color = DB.C_TEXT) -> void:
	if hud:
		hud.notify(text, color)

func shake(amount: float) -> void:
	shake_amt = minf(shake_amt + amount * Settings.shake, 14.0)

func perfect_dodge() -> void:
	if Engine.time_scale >= 1.0 and not Net.active:
		FX.text_pop(fx_layer, player.global_position + Vector2(0, -70), "완벽한 회피!", DB.C_RARE, 0.9)
		Sfx.play("perfect", -4.0)
		Engine.time_scale = 0.45
		get_tree().create_timer(0.12, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)

# ── 루프 ─────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if ending:
		return
	if event.is_action_pressed("pause"):
		if inv_open:
			toggle_inventory(false)
		else:
			_set_pause(not paused_menu)
		get_viewport().set_input_as_handled()
	elif paused_menu:
		return
	elif event.is_action_pressed("inventory"):
		toggle_inventory(not inv_open)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("map"):
		hud.big_map = not hud.big_map
	elif event.is_action_released("map"):
		pass

func toggle_inventory(open: bool, c: LootContainer = null) -> void:
	if player.dead:
		return
	inv_open = open
	if open:
		_cancel_channel()
		inv.open(c)
	else:
		inv.close()
	player.input_locked = open
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_HIDDEN

func open_loot(c: LootContainer) -> void:
	toggle_inventory(true, c)
	if tut_step == 1:
		tut_step = 2
		if not GameState.tutorial_done:
			hud.show_hint("가방이 차면 고민해야 한다. 비싼 것(숫자)을 우선 챙기자", 6.0)

func _physics_process(delta: float) -> void:
	_update_wall_occ()
	if Net.in_raid:
		# 떠난 플레이어 정리
		for id in remotes.keys():
			if not Net.players.has(id):
				net_remove_peer(id)
	if ending or player == null:
		return
	elapsed += delta
	time_left -= delta
	_camera_shake(delta)
	_update_storm(delta)
	_update_interaction(delta)
	_update_extraction(delta)
	_update_pickups()
	_update_traps(delta)
	_update_boss_intro()
	_update_smokes(delta)
	_update_supply(delta)
	_update_tutorial(delta)
	if power_on_t >= 0.0:
		power_on_t += delta
		if power_on_t >= 5.0 and exit_b.locked:
			exit_b.locked = false
			# 셔터 칸(H)을 길찾기에서 열어 준다 (지역마다 위치가 다르다)
			for y in LevelData.height():
				for x in LevelData.width():
					if LevelData.code(x, y) == "H":
						astar.set_point_solid(Vector2i(x, y), false)
			notify("셔터 개방! 탈출구 %s 사용 가능" % str(Regions.cur().exits.B[0]), Color("#6CCB5F"))
	if time_left <= 0.0 and not player.dead:
		notify("폭풍에 휩쓸렸다...", DB.C_DANGER)
		player.hp = 1.0
		player.iframes = 0.0
		player.take_damage(999.0, player.global_position)

func _camera_shake(delta: float) -> void:
	var cam := player.camera()
	shake_amt = lerpf(shake_amt, 0.0, 1.0 - exp(-delta * 10.0))
	cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_amt

func _update_storm(delta: float) -> void:
	if time_left < 240.0:
		if not warned_storm:
			warned_storm = true
			notify("폭풍이 다가온다! 서둘러 탈출하자", DB.C_DANGER)
			Sfx.play("thunder", -2.0)
		storm_k = minf(1.0, storm_k + delta / 60.0)
	vision_mul = (1.0 - storm_k * 0.25) * float(DB.WEATHER[weather_now].vision)
	# 3D 화면은 조명으로 어둡게 하므로 화면 색조는 조금만
	var base := DAY_TINT.lerp(Color(0.5, 0.54, 0.68), storm_k * (0.35 if view3d else 1.0))
	modulate_node.color = base
	rain.set("strength", storm_k)
	reinforce_t -= delta * (1.0 + storm_k)
	if reinforce_t <= 0.0 and not Net.is_client():
		reinforce_t = 95.0
		_reinforce()

func _reinforce() -> void:
	var spots: Array = Regions.cur().reinforce
	var s: Vector2 = spots[randi() % spots.size()]
	var count := 2 if storm_k < 0.5 else 3
	for i in count:
		var cell := _nearest_open(Vector2i(int(s.x) + randi_range(-1, 1), int(s.y) + randi_range(-1, 1)))
		var t := "hyena" if randf() < 0.7 else "cat"
		var e := _spawn_enemy(t, Vector2(cell.x * T + T * 0.5, cell.y * T + T * 0.7))
		e.call_deferred("_go_search", random_floor_near(player.global_position, 4), false)
		if Net.is_host():
			Net.enemy_spawned(e.net_id, t, e.position)
	notify("야생 무리가 이동 중이다...", DB.C_LEGEND)

func _update_interaction(delta: float) -> void:
	if channel_target:
		var moving := Input.get_vector("move_left", "move_right", "move_up", "move_down") != Vector2.ZERO
		if moving or player.hp < channel_hp or player.dead or inv_open:
			_cancel_channel()
			return
		channel_t -= delta
		if channel_t <= 0.0:
			var tgt = channel_target
			channel_target = null
			tgt.on_interact(player)
		return
	# 가장 가까운 상호작용 대상
	var best = null
	var best_d := 78.0
	var pp := player.global_position
	for n in get_tree().get_nodes_in_group("interactable"):
		if not n.can_interact(player):
			n.highlighted = false
			continue
		var np: Vector2 = n.global_position + Vector2(0, -20)
		if n is LootContainer and n.tile_size.x > T:
			np.x += T * 0.5
		var d := pp.distance_to(np)
		n.highlighted = false
		if d < best_d:
			best_d = d
			best = n
	if best:
		best.highlighted = true
		if best is LootContainer or best is Generator:
			best.queue_redraw()
	if focus != best:
		if focus and is_instance_valid(focus):
			focus.queue_redraw()
	focus = best
	if focus and not inv_open and not player.input_locked and Input.is_action_just_pressed("interact"):
		var ht: float = focus.hold_time()
		if ht > 0.0:
			channel_target = focus
			channel_total = ht
			channel_t = ht
			channel_hp = player.hp
			player.cancel_heal()
			focus.on_search_start()
		else:
			focus.on_interact(player)

func _cancel_channel() -> void:
	channel_target = null
	channel_t = 0.0

func _update_extraction(delta: float) -> void:
	var inside: ExitZone = null
	for ex in exits:
		if not ex.locked and ex.contains(player.global_position):
			inside = ex
	if inside == null:
		if extract_active:
			notify("탈출 취소", DB.C_MUTED)
		extract_active = false
		extract_zone = null
		return
	if not extract_active or extract_zone != inside:
		extract_active = true
		extract_zone = inside
		extract_t = inside.need
		Sfx.play("extract_start", -4.0)
	var prev := ceili(extract_t)
	extract_t -= delta
	if ceili(extract_t) != prev and extract_t > 0.0:
		Sfx.play("tick", -8.0)
	if fmod(elapsed, 0.25) < delta:
		var fp := FX.footprint(fx_layer, player.global_position + Vector2(randf_range(-14, 14), randf_range(-6, 4)), randf() * TAU, false)
		fp.col = Color(1, 0.85, 0.4, 0.9)
		fp.life = 2.5
	if extract_t <= 0.0:
		_end(true, inside.label)

func _update_pickups() -> void:
	for b in get_tree().get_nodes_in_group("bolt_pickup"):
		if b.global_position.distance_to(player.global_position + Vector2(0, -10)) < 40.0:
			player.add_ammo("bolt", 1)
			FX.text_pop(fx_layer, b.global_position, "+1 화살", DB.C_LEGEND, 0.8)
			Sfx.play("ammo", -10.0)
			b.queue_free()

func _update_tutorial(delta: float) -> void:
	if GameState.tutorial_done:
		return
	tut_t += delta
	match tut_step:
		0:
			if player.velocity.length() > 50.0 and tut_t > 3.0:
				tut_step = 1
				tut_t = 0.0
				hud.show_hint("상자·쓰레기통·자판기에 다가가 E로 뒤지자", 8.0)
		2:
			if bag.total_value() >= 250 or tut_t > 140.0:
				tut_step = 3
				hud.show_hint("M으로 지도 확인 → 초록 탈출구 A. 더 파밍할까, 지금 나갈까?", 9.0)

# ── 이벤트 ───────────────────────────────────────────
func on_loot_taken(id: String) -> void:
	var it: Dictionary = DB.ITEMS[id]
	FX.loot_rise(fx_layer, player.global_position + Vector2(0, -60), id)
	var r := int(it.r)
	Sfx.play("pickup" if r < 3 else "pickup_rare", -6.0)
	if r >= 3:
		notify("%s 획득!" % it.name, DB.rarity_color(r))
	if tut_step == 1:
		tut_step = 2

func on_enemy_killed(e: Enemy) -> void:
	enemies_by_id.erase(e.net_id)
	if not Net.active or e.last_hitter == Net.my_id():
		kills += 1
		for c in GameState.contract_event("kill", {"type": e.type, "elite": e.elite, "region": LevelData.region}):
			notify("의뢰 완료! %s — 은신처에서 보상 받기" % GameState.contract_text(c), DB.C_LEGEND)
			Sfx.play("pickup_rare", -2.0)
	var items := e.roll_loot()
	# 고양이가 들고 있던 무기는 꼭 떨어진다 + 총이면 맞는 탄약도
	if e.weapon != "" and DB.ITEMS.has("w_" + e.weapon):
		items.append("w_" + e.weapon)
		if DB.WEAPONS.has(e.weapon):
			var am := "ammo_" + str(DB.WEAPONS[e.weapon].ammo)
			if DB.ITEMS.has(am):
				items.append(am)
				if randf() < 0.5:
					items.append(am)
	# 입고 있던 갑옷도 떨어질 수 있다 (헬멧 50%, 조끼 60%) — 대장은 전부 + 귀한 전리품
	if e.helmet != "" and (e.elite or randf() < 0.5):
		items.append(e.helmet)
	if e.vest != "" and (e.elite or randf() < 0.6):
		items.append(e.vest)
	if e.elite and (not Net.active or e.last_hitter == Net.my_id()):
		GameState.stats["boss_kills"] = int(GameState.stats.get("boss_kills", 0)) + 1
	if e.elite:
		items.append_array(["gold_collar", ["att_drum_mag", "att_holo", "att_scope_4x"].pick_random(), "lens", "metal_sheet", "metal_sheet", "gunpowder", "potion_big", "ammo_rifle", "ammo_rifle"])
		notify("%s를 쓰러뜨렸다! 귀한 전리품이 떨어졌다" % str(e.data.name), DB.C_LEGEND)
		Sfx.play("rare", -2.0)
	if not items.is_empty():
		var drop := LootContainer.new()
		drop.setup(self, "drop", e.global_position)
		drop.items = items
		drop.drop_color = e.data.body
		world.call_deferred("add_child", drop)

func spawn_bolt_pickup(pos: Vector2) -> void:
	var c := cell_of(pos)
	if LevelData.is_solid_code(LevelData.code(c.x, c.y)):
		return
	var b := BoltPickup.new()
	b.position = pos
	world.call_deferred("add_child", b)

func drop_item_on_ground(id: String) -> void:
	for n in get_tree().get_nodes_in_group("interactable"):
		if n is LootContainer and n.is_drop and n.global_position.distance_to(player.global_position) < 60.0:
			n.items.append(id)
			n.searched = true
			n.queue_redraw()
			return
	var d := LootContainer.new()
	d.setup(self, "drop", player.global_position + Vector2(0, 6))
	d.items = [id]
	d.searched = true
	d.drop_color = Color("#8A7A5A")
	world.add_child(d)

func net_power_on() -> void:
	if generator and not generator.powered:
		generator.powered = true
		power_on(false)

func power_on(share: bool = true) -> void:
	if share and Net.active:
		Net.power_on()
	notify("발전기 가동! 셔터가 열린다 — 소음이 퍼졌다!", DB.C_LEGEND)
	Sfx.play("alarm", -2.0)
	emit_noise(generator.global_position, 950.0)
	shutter.open()
	power_on_t = 0.0
	shake(6.0)

func _on_player_died() -> void:
	Sfx.play("death", 0.0)
	_end(false, "사망")

func _end(survived: bool, reason: String) -> void:
	if ending:
		return
	ending = true
	if Net.in_raid:
		Net.left_raid()
		if Net.is_host():
			Net.raid_ended()
		Net.in_raid = false
	_cancel_channel()
	if inv_open:
		toggle_inventory(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var bag_ids := bag.ids()
	var kept := [] if survived else bag.cheek_ids()
	var lost := []
	if not survived:
		lost = bag_ids.duplicate()
		for kid in kept:
			lost.erase(kid)
	var result := {
		"survived": survived, "reason": reason, "time": elapsed, "kills": kills,
		"items": bag_ids if survived else kept, "lost_items": lost, "kept_items": kept,
		"value": bag.total_value(), "weapons": player.weapons.duplicate(), "ammo_left": player.reserve.duplicate(),
	}
	# 탄창에 남은 탄도 회수
	for wid in player.mags:
		var at: String = DB.WEAPONS[wid].ammo
		result.ammo_left[at] = int(result.ammo_left.get(at, 0)) + int(player.mags[wid])
	GameState.stats.kills = int(GameState.stats.kills) + kills
	if not Net.active:
		var new_bag := {}
		if not survived:
			var bp := player.global_position
			var c := cell_of(bp)
			if LevelData.is_solid_code(LevelData.code(c.x, c.y)):
				var o := _nearest_open(c)
				bp = Vector2(o.x * T + T * 0.5, o.y * T + T * 0.8)
			new_bag = {"pos": [bp.x, bp.y], "items": _death_bag_items(lost), "raids": 0, "region": LevelData.region}
		GameState.settle_lost_bags(_remaining_lost_bags(), not survived, new_bag)
		result["bag_rule"] = str(GameState.diff("bag_rule"))
		result["bag_left"] = not survived and str(GameState.diff("bag_rule")) != "instant"
		if not survived and view3d:
			view3d.play_death_bag(Vector2(new_bag.pos[0], new_bag.pos[1]), bool(result.bag_left))
	if survived:
		GameState.contract_event("extract", {"region": LevelData.region, "value": bag.total_value()})
	if survived and view3d and extract_zone:
		view3d.play_extract(extract_zone)
	if survived:
		var worn := {"helmet": [player.helmet, player.helmet_dur], "vest": [player.vest, player.vest_dur]}
		GameState.finish_raid_extract(player.weapons, result.ammo_left, bag_ids, player.melee_id, worn)
		GameState.stats.best_haul = maxi(int(GameState.stats.best_haul), bag.total_value())
		Sfx.play("extract", 0.0)
		player.set_mood("happy", 10.0)
		player.input_locked = true
		FX.ring(fx_layer, player.global_position + Vector2(0, -20), 160.0, DB.C_LEGEND, 1.2)
	else:
		# 뺨주머니에 넣은 것은 살아남는다
		for kid in kept:
			var kit_it: Dictionary = DB.ITEMS[kid]
			if kit_it.cat == "ammo":
				GameState.ammo[kit_it.ammo] = int(GameState.ammo.get(kit_it.ammo, 0)) + int(kit_it.amount)
			else:
				GameState.add_item(kid)
		GameState.finish_raid_death()
	# 용병 경험치: 처치 + 생존 + 전리품 가치
	var xp_gain := kills * 12 + (60 if survived else 15) + (int(bag.total_value() / 20) if survived else 0)
	result["xp"] = xp_gain
	result["hamster"] = player.hid
	result["lvup"] = GameState.add_ham_xp(player.hid, xp_gain)
	result["level"] = GameState.ham_level(player.hid)
	GameState.tutorial_done = true
	GameState.save_game()
	var ov := Control.new()
	ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var cl := CanvasLayer.new()
	cl.layer = 40
	cl.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(cl)
	cl.add_child(ov)
	var fade := ColorRect.new()
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0.05, 0.06, 0.09, 0.0)
	ov.add_child(fade)
	var lbl := UITheme.label("탈출 성공!" if survived else ("MIA — 실종" if reason != "원정 포기" else "원정 포기"), 64, DB.C_LEGEND if survived else DB.C_DANGER, true)
	lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_constant_override("outline_size", 12)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
	lbl.grow_vertical = Control.GROW_DIRECTION_BOTH
	lbl.modulate.a = 0.0
	ov.add_child(lbl)
	if not survived and result.has("bag_left"):
		var sub_t := "가방을 떨어뜨렸다 — 다음 원정에서 이 자리에서 되찾을 수 있다" if result.bag_left else "가방을 떨어뜨렸다 — 난이도 규칙에 따라 가방은 사라진다"
		var sub := UITheme.label(sub_t, 24, DB.C_LEGEND if result.bag_left else Color(0.8, 0.8, 0.85), true)
		sub.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.add_theme_constant_override("outline_size", 8)
		sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		sub.grow_horizontal = Control.GROW_DIRECTION_BOTH
		lbl.offset_top -= 190
		lbl.offset_bottom -= 190
		sub.offset_top -= 120
		sub.offset_bottom -= 120
		sub.modulate.a = 0.0
		ov.add_child(sub)
		var tws := create_tween()
		tws.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
		tws.tween_interval(0.5)
		tws.tween_property(sub, "modulate:a", 1.0, 0.4)
	var tw := create_tween()
	tw.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	tw.tween_property(lbl, "modulate:a", 1.0, 0.5)
	tw.tween_interval(1.4)
	tw.tween_property(fade, "color:a", 1.0, 0.8)
	tw.tween_callback(func():
		Engine.time_scale = 1.0
		finished.emit(result))
	if not survived:
		Engine.time_scale = 0.5


# ── 협동 멀티: 네트워크 상태 주고받기 ─────────────────
func net_my_state() -> Array:
	var p := player
	var f := (1 if p.crouching else 0) | (2 if p.cloak_t > 0.0 else 0) | (4 if p.burrow_t > 0.0 else 0) | (8 if p.dead or ending else 0)
	return [p.global_position, p.aim_dir, p.hp, p.max_hp, f, p.current_weapon(), p.hid, p.visibility(), p.dodge_t, p.melee_anim, p.recoil, p.heal_t]

func net_apply_player(id: int, st: Array) -> void:
	if ending:
		return
	var rp: RemotePlayer = remotes.get(id)
	if rp == null or not is_instance_valid(rp):
		rp = RemotePlayer.new()
		rp.peer = id
		rp.nickname = str(Net.players.get(id, {}).get("name", "햄찌"))
		rp.apply(st)
		world.add_child(rp)
		remotes[id] = rp
		players.append(rp)
		notify("%s 합류!" % rp.nickname, Color("#9CFFB4"))
	else:
		rp.apply(st)

func net_remove_peer(id: int) -> void:
	var rp: RemotePlayer = remotes.get(id)
	if rp and is_instance_valid(rp):
		players.erase(rp)
		if not rp.dead:
			notify("%s 원정을 마쳤다" % rp.nickname, DB.C_MUTED)
		rp.queue_free()
	remotes.erase(id)

func net_enemy_states() -> Array:
	var out := []
	for id in enemies_by_id:
		var e: Enemy = enemies_by_id[id]
		if not is_instance_valid(e) or e.dead:
			continue
		out.append([id, e.global_position, e.aim, int(e.state), e.hp, e.windup, e.windup_total, e.lunge, e.stun, e.facing, e.flash, e.show_bar_t, e.icon_t, e.max_hp, e.awareness])
	return out

func net_apply_enemies(list: Array, tleft: float) -> void:
	time_left = tleft
	for st in list:
		var e: Enemy = enemies_by_id.get(int(st[0]))
		if e and is_instance_valid(e) and not e.dead:
			e.net_apply(st)

func net_hit_enemy(eid: int, dmg: float, from: Vector2, kick: float, sender: int) -> void:
	var e: Enemy = enemies_by_id.get(eid)
	if e and is_instance_valid(e) and not e.dead:
		e.last_hitter = sender
		e._net_hit = true
		e.take_damage(dmg, from, kick)
		e._net_hit = false

func net_enemy_died(eid: int, killer: int) -> void:
	var e: Enemy = enemies_by_id.get(eid)
	if e and is_instance_valid(e) and not e.dead:
		e.last_hitter = killer
		e._die()

func net_spawn_enemy(eid: int, t: String, pos: Vector2) -> void:
	if enemies_by_id.has(eid):
		return
	_spawn_enemy(t, pos, eid)

func net_remote_fire(origin: Vector2, dir: Vector2, speed: float, dist: float, wid: String, enemy: bool) -> void:
	var p := Projectile.new()
	p.setup(self, origin, dir, speed, 0.0 if not enemy else 1.0, dist, not enemy, wid)
	if enemy:
		# 호스트 고양이의 저격탄: 내 햄스터에게만 실제 피해
		for e in get_tree().get_nodes_in_group("enemy"):
			if e.net_id > 0 and e.global_position.distance_to(origin) < 120.0:
				p.dmg = float(e.data.dmg)
				break
	else:
		p.visual = true
	fx_layer.add_child(p)
	FX.muzzle(fx_layer, origin, dir, wid == "shotgun")
	Sfx.play_at("shot_" + (wid if wid in ["pistol", "shotgun"] else "pistol"), origin, -8.0, 0.1)

## 호스트가 원정을 끝냄 → 우리도 무사 귀환
func net_host_left() -> void:
	if not ending and player and not player.dead:
		notify("호스트가 원정을 끝냈다 — 함께 귀환!", DB.C_LEGEND)
		_end(true, "호스트와 함께 귀환")
