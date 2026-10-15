extends Node
## 은신처 진행 상황(보관함·코인·무기·통계)과 원정 간 데이터를 관리하고 저장한다.

const SAVE_PATH := "user://save.json"

var coins := 150
var stash := {}        # 아이템 id -> 개수
var weapons := {}      # 무기 id -> 개수
var ammo := {}         # 탄 종류 -> 발수
var crafted := {}      # 레시피 id -> 제작 횟수
var stats := {"raids": 0, "extracts": 0, "deaths": 0, "kills": 0, "best_haul": 0}
var tutorial_done := false

# 원정 출발 시 고른 장비
var loadout := {"primary": "shotgun", "sidearm": "pistol", "meds": 2, "snacks": 2}
var hamster := "baragi"   # 선택한 햄스터 용병 (DB.HAMSTERS)
# 직전 원정 결과 (결과 화면용)
var last_result := {}

func _ready() -> void:
	_setup_input()
	if not load_game():
		new_game()

func new_game() -> void:
	coins = 150
	stash = {"bandage": 2, "canned_food": 1, "rope": 1, "sunflower_seed": 3, "cheese": 1}
	weapons = {"pistol": 1, "shotgun": 1}
	ammo = {"pistol": 40, "shell": 15, "bolt": 0}
	crafted = {}
	stats = {"raids": 0, "extracts": 0, "deaths": 0, "kills": 0, "best_haul": 0}
	loadout = {"primary": "shotgun", "sidearm": "pistol", "meds": 2, "snacks": 2}
	hamster = "baragi"
	tutorial_done = false
	save_game()

# ── 저장 ─────────────────────────────────────────────
func save_game() -> void:
	var data := {"coins": coins, "stash": stash, "weapons": weapons, "ammo": ammo, "crafted": crafted,
		"stats": stats, "loadout": loadout, "tutorial_done": tutorial_done, "hamster": hamster}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		return false
	coins = int(d.get("coins", 150))
	stash = _int_dict(d.get("stash", {}))
	weapons = _int_dict(d.get("weapons", {}))
	ammo = _int_dict(d.get("ammo", {}))
	crafted = _int_dict(d.get("crafted", {}))
	stats = _int_dict(d.get("stats", stats))
	var lo: Dictionary = d.get("loadout", loadout)
	loadout = {"primary": str(lo.get("primary", "")), "sidearm": str(lo.get("sidearm", "pistol")), "meds": int(lo.get("meds", 2)), "snacks": int(lo.get("snacks", 2))}
	hamster = str(d.get("hamster", "baragi"))
	if not DB.HAMSTERS.has(hamster):
		hamster = "baragi"
	tutorial_done = bool(d.get("tutorial_done", false))
	for k in ["pistol", "shell", "bolt"]:
		if not ammo.has(k):
			ammo[k] = 0
	return true

func _int_dict(src) -> Dictionary:
	var out := {}
	if typeof(src) == TYPE_DICTIONARY:
		for k in src:
			out[str(k)] = int(src[k])
	return out

# ── 보관함 도우미 ────────────────────────────────────
func add_item(id: String, n: int = 1) -> void:
	stash[id] = int(stash.get(id, 0)) + n

func remove_item(id: String, n: int = 1) -> bool:
	if int(stash.get(id, 0)) < n:
		return false
	stash[id] = int(stash[id]) - n
	if stash[id] <= 0:
		stash.erase(id)
	return true

func has_items(cost: Dictionary) -> bool:
	for id in cost:
		if int(stash.get(id, 0)) < int(cost[id]):
			return false
	return true

func stash_value() -> int:
	var v := 0
	for id in stash:
		v += int(DB.ITEMS[id].v) * int(stash[id])
	return v

func weapon_count(id: String) -> int:
	return int(weapons.get(id, 0))

func validate_loadout() -> void:
	if loadout.primary != "" and weapon_count(loadout.primary) <= 0:
		loadout.primary = ""
	if loadout.sidearm != "" and weapon_count(loadout.sidearm) <= 0:
		loadout.sidearm = ""
	loadout.meds = clampi(int(loadout.meds), 0, int(stash.get("bandage", 0)))

## 완전 파산 방지: 기본 권총·탄약·식량은 항상 지급
func ensure_starter_kit() -> Array:
	var given := []
	if weapon_count("pistol") <= 0:
		weapons["pistol"] = 1
		given.append("기본 권총")
	if int(ammo.get("pistol", 0)) < 20:
		ammo["pistol"] = 20
		given.append("권총탄 20발")
	if int(stash.get("canned_food", 0)) <= 0:
		add_item("canned_food")
		given.append("기본 식량")
	if loadout.sidearm == "":
		loadout.sidearm = "pistol"
	return given

# ── 원정 시작/종료 ───────────────────────────────────
## 은신처에서 장비를 꺼내 원정 꾸러미를 만든다 (사망 시 이것을 잃는다)
const SNACK_ORDER := ["sunflower_seed", "nut_mix", "cheese", "carrot_juice", "canned_food"]

func snack_count() -> int:
	var n := 0
	for sid in SNACK_ORDER:
		n += int(stash.get(sid, 0))
	return n

func begin_raid() -> Dictionary:
	validate_loadout()
	var kit := {"weapons": [], "ammo": {"pistol": 0, "shell": 0, "bolt": 0}, "meds": 0}
	for slot in ["primary", "sidearm"]:
		var wid: String = loadout[slot]
		if wid != "" and weapon_count(wid) > 0:
			weapons[wid] = weapon_count(wid) - 1
			kit.weapons.append(wid)
			var at: String = DB.WEAPONS[wid].ammo
			if kit.ammo[at] == 0:
				kit.ammo[at] = int(ammo.get(at, 0))
				ammo[at] = 0
	var meds := mini(int(loadout.meds), int(stash.get("bandage", 0)))
	if meds > 0:
		remove_item("bandage", meds)
	kit.meds = meds
	# 간식: 보관함의 음식 중 좋은 것부터 챙긴다
	kit.snacks = []
	var want := int(loadout.get("snacks", 0))
	for sid in SNACK_ORDER:
		while want > 0 and int(stash.get(sid, 0)) > 0:
			remove_item(sid, 1)
			kit.snacks.append(sid)
			want -= 1
	kit.hamster = hamster
	stats.raids = int(stats.raids) + 1
	save_game()
	return kit

## 탈출 성공: 장비·남은 탄약·배낭을 보관함으로
func finish_raid_extract(kit_weapons: Array, kit_ammo: Dictionary, bag_ids: Array) -> void:
	for wid in kit_weapons:
		weapons[wid] = weapon_count(wid) + 1
	for at in kit_ammo:
		ammo[at] = int(ammo.get(at, 0)) + int(kit_ammo[at])
	for id in bag_ids:
		var it: Dictionary = DB.ITEMS[id]
		if it.cat == "ammo":
			ammo[it.ammo] = int(ammo.get(it.ammo, 0)) + int(it.amount)
		else:
			add_item(id)
	stats.extracts = int(stats.extracts) + 1
	save_game()

func finish_raid_death() -> void:
	stats.deaths = int(stats.deaths) + 1
	save_game()

# ── 입력 ─────────────────────────────────────────────
func _setup_input() -> void:
	var keys := {
		"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN], "move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"reload": [KEY_R], "dodge": [KEY_SPACE], "melee": [KEY_V], "interact": [KEY_E], "inventory": [KEY_TAB, KEY_I],
		"map": [KEY_M], "heal": [KEY_Q], "skill": [KEY_F], "crouch": [KEY_C, KEY_CTRL], "eat": [KEY_G], "sprint": [KEY_SHIFT], "weapon_1": [KEY_1], "weapon_2": [KEY_2], "pause": [KEY_ESCAPE],
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	var mouse := {"fire": MOUSE_BUTTON_LEFT, "aim_alt": MOUSE_BUTTON_RIGHT}
	for action in mouse:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var mb := InputEventMouseButton.new()
		mb.button_index = mouse[action]
		InputMap.action_add_event(action, mb)
	# 컨트롤러 기본 지원
	var pads := {"fire": JOY_BUTTON_RIGHT_SHOULDER, "dodge": JOY_BUTTON_A, "reload": JOY_BUTTON_X, "interact": JOY_BUTTON_Y, "melee": JOY_BUTTON_B, "inventory": JOY_BUTTON_BACK, "heal": JOY_BUTTON_LEFT_SHOULDER}
	for action in pads:
		var jb := InputEventJoypadButton.new()
		jb.button_index = pads[action]
		InputMap.action_add_event(action, jb)
	var axes := {"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0], "move_up": [JOY_AXIS_LEFT_Y, -1.0], "move_down": [JOY_AXIS_LEFT_Y, 1.0]}
	for action in axes:
		var jm := InputEventJoypadMotion.new()
		jm.axis = axes[action][0]
		jm.axis_value = axes[action][1]
		InputMap.action_add_event(action, jm)
		InputMap.action_set_deadzone(action, 0.25)
