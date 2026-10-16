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
# 난이도 (프리셋 또는 직접 설정) — DB.DIFFICULTY 참고
var difficulty := {"preset": "normal", "bag_rule": "two", "enemy_dmg": 1.0, "enemy_hp": 1.0, "loot": 1.0}
# 쓰러진 자리에 남은 가방들 [{pos: [x, y], items: [...], raids: 0}]
var lost_bags: Array = []
# 총 부품: 무기 id -> {슬롯: 부품 id}
var mods := {}
# 갑옷 보유 수 / 내구도
var armor := {}
var armor_dur := {}    # 갑옷 id -> 남은 내구도 (가장 최근에 입은 것)

# 원정 출발 시 고른 장비
var loadout := {"primary": "shotgun", "sidearm": "pistol", "melee": "bat", "meds": 2, "snacks": 2, "helmet": "", "vest": ""}
var hamster := "baragi"   # 선택한 햄스터 용병 (DB.HAMSTERS)
var region := "mart"      # 원정 지역 (Regions)
var seen := {}            # 한 번 보여 준 안내 (새 기능 소개 등)
var deals: Array = []      # 오늘의 특가 [{id, sold}]
var ham_xp := {}   # 용병별 경험치 {hamster_id: xp}
var facility := {"weapon": 1, "potion": 1, "armor": 1}  # 시설 강화 단계 (1~3)
var contracts: Array = [] # 의뢰 게시판 [{kind, target, need, have, region, coins, item, done}]
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
	ammo = {"pistol": 40, "shell": 15, "bolt": 0, "rifle": 0}
	crafted = {}
	stats = {"raids": 0, "extracts": 0, "deaths": 0, "kills": 0, "best_haul": 0}
	loadout = {"primary": "shotgun", "sidearm": "pistol", "melee": "bat", "meds": 2, "snacks": 2, "helmet": "", "vest": ""}
	hamster = "baragi"
	tutorial_done = false
	difficulty = DB.DIFFICULTY.normal.duplicate()
	difficulty.preset = "normal"
	lost_bags = []
	mods = {}
	armor = {"vest_1": 1}
	armor_dur = {}
	contracts = []
	facility = {"weapon": 1, "potion": 1, "armor": 1}
	ham_xp = {}
	refresh_deals()
	fill_contracts()
	save_game()

# ── 저장 ─────────────────────────────────────────────
func save_game() -> void:
	var data := {"coins": coins, "stash": stash, "weapons": weapons, "ammo": ammo, "crafted": crafted,
		"stats": stats, "loadout": loadout, "tutorial_done": tutorial_done, "hamster": hamster,
		"difficulty": difficulty, "lost_bags": lost_bags, "region": region, "seen": seen, "contracts": contracts, "facility": facility, "ham_xp": ham_xp, "deals": deals, "mods": mods, "armor": armor, "armor_dur": armor_dur}
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
	loadout = {"primary": str(lo.get("primary", "")), "sidearm": str(lo.get("sidearm", "pistol")), "melee": str(lo.get("melee", "bat")), "meds": int(lo.get("meds", 2)), "snacks": int(lo.get("snacks", 2)),
		"helmet": str(lo.get("helmet", "")), "vest": str(lo.get("vest", ""))}
	var df = d.get("difficulty", {})
	difficulty = DB.DIFFICULTY.normal.duplicate()
	difficulty.preset = "normal"
	if typeof(df) == TYPE_DICTIONARY:
		for k in df:
			difficulty[str(k)] = df[k]
	lost_bags = []
	var lb = d.get("lost_bags", [])
	if typeof(lb) == TYPE_ARRAY:
		for b in lb:
			if typeof(b) == TYPE_DICTIONARY and b.has("pos") and b.has("items"):
				var its := []
				for it in b.items:
					if DB.ITEMS.has(str(it)):
						its.append(str(it))
				lost_bags.append({"pos": [float(b.pos[0]), float(b.pos[1])], "items": its, "raids": int(b.get("raids", 0)), "region": str(b.get("region", "mart"))})
	mods = {}
	var md = d.get("mods", {})
	if typeof(md) == TYPE_DICTIONARY:
		for wid in md:
			if typeof(md[wid]) == TYPE_DICTIONARY:
				var one := {}
				for slot in md[wid]:
					if DB.ATTACHMENTS.has(str(md[wid][slot])):
						one[str(slot)] = str(md[wid][slot])
				mods[str(wid)] = one
	armor = _int_dict(d.get("armor", {}))
	armor_dur = {}
	var ad = d.get("armor_dur", {})
	if typeof(ad) == TYPE_DICTIONARY:
		for k in ad:
			armor_dur[str(k)] = float(ad[k])
	hamster = str(d.get("hamster", "baragi"))
	facility = {"weapon": 1, "potion": 1, "armor": 1}
	var fc = d.get("facility", {})
	if typeof(fc) == TYPE_DICTIONARY:
		for k in facility:
			facility[k] = clampi(int(fc.get(k, 1)), 1, 3)
	deals = []
	var dl = d.get("deals", [])
	if typeof(dl) == TYPE_ARRAY:
		for x in dl:
			if typeof(x) == TYPE_DICTIONARY and DB.ITEMS.has(str(x.get("id", ""))):
				deals.append({"id": str(x.id), "sold": bool(x.get("sold", false))})
	if deals.is_empty():
		refresh_deals()
	ham_xp = {}
	var hx = d.get("ham_xp", {})
	if typeof(hx) == TYPE_DICTIONARY:
		for k in hx:
			ham_xp[str(k)] = int(hx[k])
	region = str(d.get("region", "mart"))
	seen = d.get("seen", {}) if typeof(d.get("seen", {})) == TYPE_DICTIONARY else {}
	contracts = []
	var ct = d.get("contracts", [])
	if typeof(ct) == TYPE_ARRAY:
		for c in ct:
			if typeof(c) == TYPE_DICTIONARY and c.has("kind"):
				contracts.append(c)
	fill_contracts()
	if not Regions.ORDER.has(region):
		region = "mart"
	if not DB.HAMSTERS.has(hamster):
		hamster = "baragi"
	tutorial_done = bool(d.get("tutorial_done", false))
	for k in ["pistol", "shell", "bolt", "rifle"]:
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

# ── 난이도 ───────────────────────────────────────────
func diff(key: String) -> Variant:
	return difficulty.get(key, DB.DIFFICULTY.normal.get(key))

func set_difficulty_preset(p: String) -> void:
	if p == "custom":
		difficulty.preset = "custom"
	elif DB.DIFFICULTY.has(p):
		difficulty = DB.DIFFICULTY[p].duplicate()
		difficulty.preset = p
	save_game()

func set_difficulty_value(key: String, v: Variant) -> void:
	difficulty[key] = v
	difficulty.preset = "custom"
	save_game()

# ── 총 부품 ──────────────────────────────────────────
func mod_of(wid: String, slot: String) -> String:
	return str(mods.get(wid, {}).get(slot, ""))

## 부품을 끼운다 (보관함에서 1개 사용, 원래 끼워져 있던 부품은 보관함으로)
func install_mod(wid: String, att: String) -> bool:
	if not DB.ATTACHMENTS.has(att) or not DB.att_fits(att, wid):
		return false
	var item := "att_" + att
	if not remove_item(item, 1):
		return false
	var slot: String = DB.ATTACHMENTS[att].slot
	var old := mod_of(wid, slot)
	if old != "":
		add_item("att_" + old)
	if not mods.has(wid):
		mods[wid] = {}
	mods[wid][slot] = att
	save_game()
	return true

func remove_mod(wid: String, slot: String) -> void:
	var old := mod_of(wid, slot)
	if old == "":
		return
	add_item("att_" + old)
	mods[wid].erase(slot)
	save_game()

## 부품을 반영한 총 성능
func weapon_stats(wid: String) -> Dictionary:
	return DB.apply_mods(wid, mods.get(wid, {}))

# ── 갑옷 ─────────────────────────────────────────────
func armor_max(aid: String) -> float:
	return float(DB.ITEMS.get(aid, {}).get("dur", 100)) * float(DB.FACILITY.armor.mul[fac("armor") - 1])

# ── 용병 레벨 (원정마다 경험치, 레벨마다 체력 +8) ─────
const XP_LV := [0, 100, 250, 450, 700]
const HP_PER_LV := 8.0

func ham_level(id: String) -> int:
	var xp := int(ham_xp.get(id, 0))
	var lv := 1
	for i in XP_LV.size():
		if xp >= int(XP_LV[i]):
			lv = i + 1
	return lv

## [지금 레벨 안에서 모은 양, 다음 레벨까지 필요한 양] (최고 레벨이면 [0, 0])
func ham_xp_progress(id: String) -> Array:
	var lv := ham_level(id)
	if lv >= XP_LV.size():
		return [0, 0]
	var xp := int(ham_xp.get(id, 0))
	return [xp - int(XP_LV[lv - 1]), int(XP_LV[lv]) - int(XP_LV[lv - 1])]

func ham_bonus_hp(id: String) -> float:
	return HP_PER_LV * float(ham_level(id) - 1)

## 경험치를 더하고 오른 레벨 수를 돌려준다
func add_ham_xp(id: String, amount: int) -> int:
	var before := ham_level(id)
	ham_xp[id] = int(ham_xp.get(id, 0)) + maxi(0, amount)
	return ham_level(id) - before

func refresh_deals() -> void:
	var pool: Array = DB.DEAL_POOL.duplicate()
	pool.shuffle()
	deals = []
	for i in 3:
		deals.append({"id": str(pool[i]), "sold": false})

func roll_weather() -> String:
	var r := randf()
	for w in DB.WEATHER:
		r -= float(DB.WEATHER[w].chance)
		if r <= 0.0:
			return w
	return "clear"

# ── 시설 강화 ────────────────────────────────────────
func fac(st: String) -> int:
	return int(facility.get(st, 1))

func can_upgrade(st: String) -> bool:
	var lv := fac(st)
	if lv >= 3:
		return false
	var nx: Dictionary = DB.FACILITY[st].levels[lv]
	return has_items(nx.cost) and coins >= int(nx.coins)

func upgrade_facility(st: String) -> bool:
	if not can_upgrade(st):
		return false
	var nx: Dictionary = DB.FACILITY[st].levels[fac(st)]
	for id in nx.cost:
		remove_item(id, int(nx.cost[id]))
	coins -= int(nx.coins)
	facility[st] = fac(st) + 1
	save_game()
	return true

func armor_left(aid: String) -> float:
	return float(armor_dur.get(aid, armor_max(aid)))

func validate_loadout() -> void:
	if loadout.primary != "" and weapon_count(loadout.primary) <= 0:
		loadout.primary = ""
	if loadout.sidearm != "" and weapon_count(loadout.sidearm) <= 0:
		loadout.sidearm = ""
	if str(loadout.get("melee", "bat")) != "bat" and weapon_count(str(loadout.melee)) <= 0:
		loadout.melee = "bat"
	loadout.meds = clampi(int(loadout.meds), 0, int(stash.get("bandage", 0)))
	for slot in ["helmet", "vest"]:
		var aid := str(loadout.get(slot, ""))
		if aid != "" and int(armor.get(aid, 0)) <= 0:
			loadout[slot] = ""

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
	var kit := {"weapons": [], "ammo": {"pistol": 0, "shell": 0, "bolt": 0, "rifle": 0}, "meds": 0, "melee": "bat"}
	var mel := str(loadout.get("melee", "bat"))
	if mel != "bat" and DB.MELEES.has(mel) and weapon_count(mel) > 0:
		weapons[mel] = weapon_count(mel) - 1
		kit.melee = mel
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
	# 연막 깡통은 보관함에서 최대 2개 자동으로 챙긴다
	kit.throws = []
	while kit.throws.size() < 2 and int(stash.get("smoke_can", 0)) > 0:
		remove_item("smoke_can", 1)
		kit.throws.append("smoke_can")
	kit.hamster = hamster
	kit.region = region
	kit.weather = roll_weather()
	# 갑옷: 입고 나간 것은 원정 꾸러미로 (사망 시 가방에 남는다)
	for slot in ["helmet", "vest"]:
		var aid := str(loadout.get(slot, ""))
		kit[slot] = ""
		if aid != "" and int(armor.get(aid, 0)) > 0:
			armor[aid] = int(armor[aid]) - 1
			kit[slot] = aid
			kit[slot + "_dur"] = armor_left(aid)
	kit.mods = mods.duplicate(true)
	stats.raids = int(stats.raids) + 1
	save_game()
	return kit

## 탈출 성공: 장비·남은 탄약·배낭을 보관함으로
func finish_raid_extract(kit_weapons: Array, kit_ammo: Dictionary, bag_ids: Array, melee: String = "bat", worn: Dictionary = {}) -> void:
	for slot in worn:
		var aid := str(worn[slot][0])
		if aid != "":
			armor[aid] = int(armor.get(aid, 0)) + 1
			armor_dur[aid] = float(worn[slot][1])
	for wid in kit_weapons:
		weapons[wid] = weapon_count(wid) + 1
	if melee != "bat" and melee != "":
		weapons[melee] = weapon_count(melee) + 1
	for at in kit_ammo:
		ammo[at] = int(ammo.get(at, 0)) + int(kit_ammo[at])
	for id in bag_ids:
		var it: Dictionary = DB.ITEMS[id]
		if it.cat == "ammo":
			ammo[it.ammo] = int(ammo.get(it.ammo, 0)) + int(it.amount)
		elif it.cat == "weapon":
			weapons[it.weapon] = weapon_count(it.weapon) + 1   # 주워 온 무기는 무기고로
		elif it.cat == "armor":
			armor[id] = int(armor.get(id, 0)) + 1
		else:
			add_item(id)
	stats.extracts = int(stats.extracts) + 1
	refresh_deals()
	save_game()

func finish_raid_death() -> void:
	stats.deaths = int(stats.deaths) + 1
	refresh_deals()
	save_game()

# ── 의뢰 ─────────────────────────────────────────────
func fill_contracts() -> void:
	var kinds := []
	for c in contracts:
		kinds.append(str(c.kind))
	while contracts.size() < 3:
		var pick := "fetch"
		var r := randf()
		if not kinds.has("kill") and r < 0.6:
			pick = "kill"
		elif not kinds.has("extract") and r < 0.85:
			pick = "extract"
		elif not kinds.has("boss") and r < 0.92 and int(stats.extracts) >= 2:
			pick = "boss"
		elif not kinds.has("barrel") and r < 0.96:
			pick = "barrel"
		elif not kinds.has("bait") and r < 1.0:
			pick = "bait"
		kinds.append(pick)
		contracts.append(_new_contract(pick))

func _new_contract(kind: String) -> Dictionary:
	var c := {"kind": kind, "have": 0, "done": false, "item": DB.CONTRACT_BONUS.pick_random(), "region": ""}
	match kind:
		"fetch":
			var f: Array = DB.CONTRACT_FETCH.pick_random()
			c.target = f[0]
			c.need = int(f[1])
			c.coins = int(round(float(DB.ITEMS[f[0]].v) * int(f[1]) * 1.7 / 10.0)) * 10 + 40
		"kill":
			var k: Array = DB.CONTRACT_KILL.pick_random()
			c.target = k[0]
			c.need = int(k[1])
			c.coins = {"hyena": 180, "bulldog": 260, "cat": 240, "any": 300}[k[0]]
			c.region = ["", "mart", "dock", "town", "subway"].pick_random()
		"extract":
			c.region = ["mart", "dock", "town", "subway"].pick_random()
			c.target = "value"
			c.need = [300, 500, 800].pick_random()
			c.coins = int(c.need * 0.5) + 100
		"barrel":
			c.region = ["", "dock", "mart"].pick_random()
			c.target = "barrel"
			c.need = [2, 3, 4].pick_random()
			c.coins = 120 + int(c.need) * 40
		"bait":
			c.region = ["", "town"].pick_random()
			c.target = "bait"
			c.need = [1, 2, 3].pick_random()
			c.coins = 100 + int(c.need) * 50
		"boss":
			c.region = ["mart", "dock", "town", "subway"].pick_random()
			c.target = "elite"
			c.need = 1
			c.coins = 600
			c.item = ["att_holo", "att_drum_mag", "vest_3", "helmet_3"].pick_random()
	return c

func contract_text(c: Dictionary) -> String:
	var where := "" if str(c.get("region", "")) == "" else "[%s] " % str(Regions.get_info(str(c.region)).short).get_slice(" ·", 0)
	match str(c.kind):
		"fetch":
			return "%s %d개 납품" % [DB.ITEMS[c.target].name, int(c.need)]
		"kill":
			return "%s%s %d마리 처치" % [where, DB.CAT_NAMES.get(c.target, "고양이"), int(c.need)]
		"extract":
			return "%s전리품 %d냥 이상 들고 탈출" % [where, int(c.need)]
		"boss":
			var bname := "보스"
			var bd: Dictionary = Regions.get_info(str(c.get("region", "dock")))
			if bd.has("boss"):
				bname = str(bd.boss[1])
			return "%s%s 쓰러뜨리기" % [where, bname]
		"barrel":
			return "%s기름통 %d개 터뜨리기" % [where, int(c.need)]
		"bait":
			return "%s쥐덫에서 미끼 치즈 %d개 빼 오기" % [where, int(c.need)]
	return "?"

## 원정 중 일어난 일 → 의뢰 진행
func contract_event(ev: String, info: Dictionary) -> Array:
	var finished := []
	for c in contracts:
		if c.done:
			continue
		var reg := str(c.get("region", ""))
		if reg != "" and reg != str(info.get("region", "")):
			continue
		match str(c.kind):
			"kill":
				if ev == "kill" and (c.target == "any" or c.target == str(info.get("type", ""))):
					c.have = int(c.have) + 1
			"boss":
				if ev == "kill" and bool(info.get("elite", false)):
					c.have = int(c.have) + 1
			"extract":
				if ev == "extract" and int(info.get("value", 0)) >= int(c.need):
					c.have = int(c.need)
			"barrel":
				if ev == "barrel":
					c.have = int(c.have) + 1
			"bait":
				if ev == "bait":
					c.have = int(c.have) + 1
		if int(c.have) >= int(c.need) and str(c.kind) != "fetch":
			c.done = true
			finished.append(c)
	return finished

func can_turn_in(c: Dictionary) -> bool:
	if c.done:
		return true
	return str(c.kind) == "fetch" and int(stash.get(c.target, 0)) >= int(c.need)

## 보상 받기 (납품 의뢰는 물건을 낸다) → 새 의뢰로 교체
func claim_contract(i: int) -> String:
	if i < 0 or i >= contracts.size():
		return ""
	var c: Dictionary = contracts[i]
	if not can_turn_in(c):
		return ""
	if str(c.kind) == "fetch":
		remove_item(c.target, int(c.need))
	coins += int(c.coins)
	var it := str(c.item)
	if DB.ITEMS.get(it, {}).get("cat", "") == "armor":
		armor[it] = int(armor.get(it, 0)) + 1
	else:
		add_item(it, 1)
	contracts.remove_at(i)
	stats["contracts"] = int(stats.get("contracts", 0)) + 1
	fill_contracts()
	save_game()
	return "%d냥 + %s" % [int(c.coins), DB.ITEMS[it].name]

func reroll_contract(i: int) -> void:
	if i < 0 or i >= contracts.size() or coins < 30:
		return
	coins -= 30
	var k := str(contracts[i].kind)
	contracts[i] = _new_contract(k if k != "boss" else "fetch")
	save_game()

# ── 쓰러진 자리의 가방 ───────────────────────────────
## 원정이 끝날 때: 이번 원정에 놓여 있던 가방들의 남은 내용물(remaining)과,
## 죽었다면 새 가방(new_bag)을 규칙에 따라 정리한다.
## 규칙: instant = 죽으면 바로 사라짐 / two = 회수 못 하고 또 죽으면 이전 가방은 사라짐 / keep = 회수할 때까지 남음(최대 3개)
func settle_lost_bags(remaining: Array, died: bool, new_bag: Dictionary) -> void:
	var rule := str(diff("bag_rule"))
	var kept := []
	# 다른 지역에 놓인 가방은 이번 원정과 상관없이 그대로
	for b in lost_bags:
		if str(b.get("region", "mart")) != LevelData.region:
			kept.append(b)
	for b in remaining:
		if (b.items as Array).is_empty():
			continue
		if died and rule != "keep":
			continue   # 두 번 연속 쓰러짐 → 이전 가방은 사라진다
		b.raids = int(b.get("raids", 0)) + 1
		kept.append(b)
	if died and rule != "instant" and not (new_bag.get("items", []) as Array).is_empty():
		kept.append(new_bag)
	while kept.size() > 3:
		kept.pop_front()
	lost_bags = kept
	save_game()

# ── 입력 ─────────────────────────────────────────────
func _setup_input() -> void:
	var keys := {
		"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN], "move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"reload": [KEY_R], "dodge": [KEY_SPACE], "melee": [KEY_V], "interact": [KEY_E], "inventory": [KEY_TAB, KEY_I],
		"map": [KEY_M], "heal": [KEY_Q], "skill": [KEY_F], "crouch": [KEY_C, KEY_CTRL], "eat": [KEY_G], "throw": [KEY_T], "sprint": [KEY_SHIFT], "weapon_1": [KEY_1], "weapon_2": [KEY_2], "pause": [KEY_ESCAPE],
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
