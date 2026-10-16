class_name LootContainer
extends StaticBody2D
## 파밍 가능한 오브젝트. 처음엔 내용물을 모르고, 뒤지면(E) 희귀도 빛으로 바로 읽힌다.

var raid: Raid
var type := "box"
var items: Array = []
var searched := false
var highlighted := false
var is_drop := false   # 적이 떨어뜨린 꾸러미 (충돌 없음)
var drop_color := Color.WHITE
var tile_size := Vector2(DB.TILE, DB.TILE)
var anim := 0.0
var _seed := 0.0
var supply := false        # 하늘에서 떨어진 보급 상자
var prop_spr: Sprite2D      # 3D 화면용: 세워 그릴 소품 스프라이트
var _prop_shown := ""

func setup(r: Raid, t: String, pos: Vector2) -> void:
	raid = r
	type = t
	position = pos
	_seed = randf()
	if t == "drop":
		is_drop = true
		return
	var c: Dictionary = DB.CONTAINERS[t]
	var n := randi_range(int(c.slots[0]), int(c.slots[1]))
	# 난이도: 전리품 양
	var lm := float(GameState.diff("loot")) * float(Regions.cur().get("loot", 1.0)) * float(DB.WEATHER[Raid.weather_now].loot)
	var extra := float(n) * (lm - 1.0)
	if lm >= 1.0:
		n += int(extra) + (1 if randf() < fposmod(extra, 1.0) else 0)
	elif randf() < -extra:
		n = maxi(0, n - 1)
	for i in n:
		items.append(_roll(c.table))
	if t == "dumpster":
		tile_size = Vector2(DB.TILE * 2, DB.TILE)

static func _roll(table: Array) -> String:
	var total := 0.0
	for pair in table:
		total += float(pair[1])
	var r := randf() * total
	for pair in table:
		r -= float(pair[1])
		if r <= 0.0:
			return pair[0]
	return table[0][0]

func _ready() -> void:
	add_to_group("interactable")
	if is_drop:
		collision_layer = 0
		collision_mask = 0
		z_index = -2
		return
	collision_layer = 1
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = tile_size - Vector2(4, 8)
	shape.shape = rect
	shape.position = Vector2((tile_size.x - DB.TILE) * 0.5, -tile_size.y * 0.5 + 2)
	add_child(shape)
	if raid and raid.USE_3D:
		_refresh_prop()

## 3D 화면: 소품을 2D _draw 대신 스프라이트로 (View3D가 3D로 세운다)
func _refresh_prop() -> void:
	var want: String = ("s:" + SHEET_PROP[type]) if SHEET_PROP.has(type) else ("p:" + prop_name())
	if want == _prop_shown and prop_spr:
		return
	_prop_shown = want
	if prop_spr:
		prop_spr.queue_free()
	if want.begins_with("s:"):
		prop_spr = Sprites.make_sprop_sprite(want.substr(2), 0.95)
	else:
		prop_spr = Sprites.make_prop_sprite(want.substr(2))
	prop_spr.position = Vector2(0, -DB.TILE * 0.5)
	add_child(prop_spr)

var lost_bag := false   # 지난 원정에서 쓰러진 자리에 남은 내 가방

func display_name() -> String:
	if lost_bag:
		return "내 가방 (지난 원정)"
	if is_drop:
		return "유실물 꾸러미"
	return DB.CONTAINERS[type].name

func can_interact(_p: Node) -> bool:
	return not (searched and items.is_empty() and is_drop)

func hold_time() -> float:
	if searched:
		return 0.0
	if is_drop:
		return 0.5
	return float(DB.CONTAINERS[type].search)

func prompt() -> String:
	if searched:
		return "E  %s 열기 (%d)" % [display_name(), items.size()] if not items.is_empty() else "%s (비어 있음)" % display_name()
	return "E  %s 뒤지기" % display_name()

func on_search_start() -> void:
	var noise := 50.0 if is_drop else float(DB.CONTAINERS[type].noise)
	raid.emit_noise(global_position, noise)
	Sfx.play_at("rummage", global_position, -6.0, 0.1)

func on_interact(_p: Node) -> void:
	if not searched:
		searched = true
		anim = 1.0
		if lost_bag:
			Sfx.play("bag_found", -2.0)
			raid.notify("지난번 내 가방을 찾았다!", DB.C_LEGEND)
		Sfx.play_at("open", global_position, -4.0)
		if not items.is_empty():
			var best := best_rarity()
			if best >= 3:
				Sfx.play("rare", -3.0)
				FX.ring(raid.fx_layer, global_position + Vector2(0, -20), 70.0, DB.rarity_color(best), 0.9)
	queue_redraw()
	raid.open_loot(self)

func best_rarity() -> int:
	var b := -1
	for id in items:
		b = maxi(b, int(DB.ITEMS[id].r))
	return b

func take(index: int) -> String:
	var id: String = items[index]
	items.remove_at(index)
	queue_redraw()
	return id

## 시트 그림 소품으로 대체하는 상자 종류
const SHEET_PROP := {"box": "crate", "toolbox": "ammo_locker", "locker": "locker"}

const PROP := {"shelf": ["shelf", "shelf_empty"], "fridge": ["fridge", "fridge_off"], "register": ["register", "register"],
	"box": ["box", "box_open"], "trash": ["trash", "trash_open"], "dumpster": ["dumpster", "dumpster_open"],
	"vending": ["vending", "vending_off"], "plant": ["plant", "plant"], "toolbox": ["toolbox", "toolbox_open"],
	"medcab": ["medcab", "medcab_open"], "locker": ["locker", "locker_open"]}

func prop_name() -> String:
	var pair: Array = PROP.get(type, ["box", "box_open"])
	if not searched:
		return pair[0]
	if type in ["shelf", "fridge", "vending"]:
		return pair[1] if items.is_empty() else pair[0]
	return pair[1]

func _process(delta: float) -> void:
	if prop_spr:
		_refresh_prop()
		var empty3 := searched and items.is_empty()
		prop_spr.modulate = Color(0.8, 0.8, 0.85) if empty3 else (Color(1.25, 1.2, 1.08) if highlighted else Color.WHITE)
	if anim > 0.0:
		anim = maxf(0.0, anim - delta * 3.0)
		queue_redraw()
	else:
		queue_redraw()

# ── 그리기 (원점 = 타일 아래 가운데) ─────────────────
func _draw() -> void:
	var T := float(DB.TILE)
	var base := Vector2(-T * 0.5, -T)
	var r := Rect2(base, Vector2(T, T))
	var empty := searched and items.is_empty()
	var pop := sin(anim * PI) * 4.0
	var hi := highlighted and not empty
	if hi:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
		var fc := Vector2((tile_size.x - T) * 0.5, -T * 0.45)
		draw_colored_polygon(Art.ellipse_pts(fc, tile_size.x * 0.55, T * 0.42, 32), Color(1, 0.9, 0.55, 0.12 + pulse * 0.08))
		draw_arc(fc, tile_size.x * 0.55, 0, TAU, 40, Color(1, 0.9, 0.55, 0.5 + pulse * 0.3), 2.0, true)
	if is_drop:
		Art.shadow(self, Vector2(0, 0), 18, 6)
		var bt := Sprites.fx_tex("bag")
		if bt:
			Sprites.draw_fit(self, bt, Rect2(Vector2(-18, -34 - pop), Vector2(36, 36)))
		else:
			Art.blob(self, Vector2(0, -10 - pop), 15, 11, drop_color.darkened(0.2))
			draw_line(Vector2(-8, -20 - pop), Vector2(8, -20 - pop), Color("#F2C14E"), 3)
	elif prop_spr == null:
		var center := Vector2(0, -T * 0.5 - pop)
		var mod := Color(0.8, 0.8, 0.85) if empty else (Color(1.25, 1.2, 1.08) if hi else Color.WHITE)
		if SHEET_PROP.has(type):
			Sprites.draw_sprop(self, SHEET_PROP[type], center + Vector2(0, T * 0.3), mod, 0.95)
		else:
			Sprites.draw_prop(self, prop_name(), center, mod)
	# 아직 안 뒤진 파밍 오브젝트: 반짝이는 발자국 표식 (시각적 통일)
	if not searched and not is_drop:
		var tw := Time.get_ticks_msec() * 0.003 + _seed * 10.0
		var mp := Vector2(tile_size.x - T * 0.5 - 10, -T - 18)
		var a := 0.45 + 0.35 * sin(tw)
		draw_circle(mp, 7, Color(1, 0.95, 0.7, a * 0.35))
		draw_circle(mp + Vector2(0, 1.5), 2.6, Color(1, 0.95, 0.75, a))
		for k in 3:
			draw_circle(mp + Vector2(-2.6 + k * 2.6, -2.2 - (1 if k == 1 else 0)), 1.1, Color(1, 0.95, 0.75, a))
	# 뒤진 뒤 남은 최고 희귀도를 빛으로 표시
	if searched and not items.is_empty():
		var rc := DB.rarity_color(best_rarity())
		var tt := Time.get_ticks_msec() * 0.004
		var gp := Vector2(tile_size.x * 0.5 - T * 0.5, -T - 30 + sin(tt) * 3) if not is_drop else Vector2(0, -34 + sin(tt) * 3)
		draw_circle(gp, 9, Color(rc, 0.3))
		draw_circle(gp, 5, rc)
		draw_circle(gp + Vector2(-1.5, -1.5), 1.8, Color.WHITE)
