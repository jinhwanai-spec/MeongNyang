class_name HideoutRoom
extends Node3D
## 3D 은신처 방 (블렌더 hideout.glb) + 따뜻한 조명 + NPC + 장소 이름표.
## 로비(걸어 다니기)와 메인화면 배경이 함께 쓴다.

const STATIONS := {
	"st_prep": ["출발 준비", "용병·무기·갑옷·난이도", 0],
	"st_board": ["의뢰 게시판", "의뢰 확인·보상 받기 (출발 준비 탭)", 0],
	"st_craft": ["무기 제작소", "총·탄약·부품 만들기 / 부품 장착", 1],
	"st_potion": ["물약 제작소", "물약·구급상자 달이기", 2],
	"st_armor": ["갑옷 제작소", "헬멧·조끼 만들기 / 수리", 3],
	"st_market": ["냥이 시장", "팔고 사기", 4],
	"st_stash": ["보관함", "모은 물건", 5],
	"st_door": ["출구", "나가면 원정 시작", -1],
}
## 블렌더 방에 없는 새 장소 (코드로 세운 제작소)
const EXTRA_MARKERS := {
	"st_potion": Vector3(12.6, 0, 2.7), "npc_potion": Vector3(13.25, 0, 3.75),
	"st_armor": Vector3(9.6, 0, 7.6), "npc_armor": Vector3(12.05, 0, 8.25),
	"st_board": Vector3(12.9, 0, 7.75),
}

var room: Node3D
var markers := {}      # 이름 -> Vector3
var colliders := []    # [중심 Vector2(타일), 반크기 Vector2(타일)]
var env: Environment
var sun: DirectionalLight3D
var labels := {}
var t := 0.0
var npcs: Array[Node3D] = []
var forge_light: OmniLight3D

func _ready() -> void:
	room = (load("res://assets/models/hideout.glb") as PackedScene).instantiate()
	add_child(room)
	_read_markers(room)
	for k in EXTRA_MARKERS:
		if not markers.has(k):
			markers[k] = EXTRA_MARKERS[k]
	_stations()
	_env()
	_npcs()
	_labels()

func _read_markers(n: Node) -> void:
	for c in n.get_children():
		if c is Node3D:
			var nm: String = c.name
			var p: Vector3 = (c as Node3D).global_transform.origin if c.is_inside_tree() else (c as Node3D).position
			if nm.begins_with("col_"):
				var s: Vector3 = (c as Node3D).scale
				colliders.append([Vector2(p.x, p.z), Vector2(absf(s.x), absf(s.z))])
			elif nm.begins_with("st_") or nm.begins_with("npc_") or nm.begins_with("light_") or nm == "spawn":
				markers[nm] = p
		_read_markers(c)

## 제작소 소품 (코드로 만든 3D) + 충돌
func _stations() -> void:
	var potion := ProcModels.potion_lab()
	potion.position = markers["st_potion"] + Vector3(0.8, 0, -0.75)
	potion.rotation.y = -PI * 0.5
	add_child(potion)
	colliders.append([Vector2(13.35, 2.2), Vector2(0.55, 1.2)])
	var forge := ProcModels.armor_forge()
	forge_light = forge.get_meta("fire_light")
	forge.position = markers["st_armor"] + Vector3(0.9, 0, 0.9)
	forge.rotation.y = 0.0
	add_child(forge)
	colliders.append([Vector2(10.4, 8.5), Vector2(0.9, 0.55)])
	var board := ProcModels.quest_board()
	board.position = Vector3(13.85, 0, 7.6)
	board.rotation.y = -PI * 0.5
	add_child(board)
	# 무기 제작소 벽 진열대: 시설 단계가 오를수록 총이 늘어난다
	var wall_ids := ["assault_rifle", "shotgun", "sniper", "smg", "katana"]
	if GameState.fac("weapon") >= 2:
		wall_ids += ["lmg", "crossbow"]
	if GameState.fac("weapon") >= 3:
		wall_ids += ["dmr", "fire_axe"]
	var rack := ProcModels.weapon_wall(wall_ids)
	rack.position = Vector3(7.2 - (wall_ids.size() - 5) * 0.3, 0, 0.62)
	add_child(rack)
	_facility_dress()

## 시설 강화 단계가 눈에 보이게: 금빛 별 명패 + 단계별 소품 + 3단계 조명
func _facility_dress() -> void:
	var spots := {
		"weapon": [Vector3(7.2, 2.35, 0.75), Color("#FFB070")],
		"potion": [markers["st_potion"] + Vector3(0.8, 2.0, -0.75), Color("#7CFF9A")],
		"armor": [markers["st_armor"] + Vector3(0.9, 2.1, 0.9), Color("#FF8A4A")],
	}
	for st in spots:
		var lv := GameState.fac(st)
		if lv < 2:
			continue
		var at: Vector3 = spots[st][0]
		var col: Color = spots[st][1]
		var plate := Label3D.new()
		plate.text = "★".repeat(lv)
		plate.font_size = 64
		plate.pixel_size = 0.006
		plate.modulate = Color("#FFD34E")
		plate.outline_size = 14
		plate.outline_modulate = Color(0.25, 0.12, 0.02)
		plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		plate.position = at
		add_child(plate)
		if st == "potion":
			for i in (lv - 1) * 2:
				var pt := ProcModels.potion(["potion_heal", "potion_iron", "potion_swift", "potion_focus"][i % 4])
				pt.position = markers["st_potion"] + Vector3(0.15 + i * 0.22, 0, 0.35)
				pt.scale = Vector3.ONE * 1.6
				add_child(pt)
		if lv >= 3:
			var ol := OmniLight3D.new()
			ol.light_color = col
			ol.light_energy = 0.8
			ol.omni_range = 2.5
			ol.position = at + Vector3(0, -0.6, 0.4)
			add_child(ol)

func marker(n: String) -> Vector3:
	return markers.get(n, Vector3(7, 0, 6))

func _env() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#120E0C")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 0.82, 0.66)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.ssao_intensity = 2.0
	env.ssil_enabled = true
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_hdr_threshold = 1.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.1
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.85, 0.7)
	sun.light_energy = 0.55
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-62, -30, 0)
	add_child(sun)
	Settings.apply_env(env, sun)
	for k in markers:
		if str(k).begins_with("light_"):
			var o := OmniLight3D.new()
			o.position = markers[k] + Vector3(0, 2.3, 0)
			o.light_color = Color(1.0, 0.78, 0.5) if k != "light_door" else Color(0.5, 1.0, 0.65)
			o.light_energy = 2.2 if k != "light_center" else 2.8
			o.omni_range = 6.0 if k != "light_center" else 8.0
			o.shadow_enabled = k == "light_center"
			add_child(o)

func _model(path: String, pos: Vector3, yaw_deg: float, sc: float) -> Node3D:
	var m := (load(path) as PackedScene).instantiate() as Node3D
	m.position = pos
	m.rotation_degrees.y = yaw_deg
	m.scale = Vector3.ONE * sc
	add_child(m)
	return m

var npc_pitch := 52.0

func _npc(sheet: String, anim: String, pos: Vector3, sc: float = 1.0) -> CharBillboard:
	var b := CharBillboard.new()
	b.position = pos
	add_child(b)
	b.setup_static(sheet, anim, npc_pitch, sc)
	return b

## 3D 고양이 NPC (적 모델과 같은 Meshy 모델, 대기 애니메이션) — 카메라 쪽을 보고 서 있음
func _npc3d(tp: String, pos: Vector3, yaw: float) -> Node3D:
	var m := EnemyModel.load_model(tp, true)
	m.position = pos
	m.rotation.y = yaw
	m.scale *= 0.95
	add_child(m)
	return m

func _npcs() -> void:
	# 기술 고양이 나비 (작업대), 시장 상인 (줄무늬 고양이), 잠자는 동료 햄스터 — 시트 그림 그대로
	if EnemyModel.available("cat") and EnemyModel.available("hyena"):
		npcs.append(_npc3d("cat", marker("npc_navi"), 0.35))
		npcs.append(_npc3d("hyena", marker("npc_market"), -0.3))
		npcs.append(_npc3d("cat", marker("npc_potion"), -1.2))
		if EnemyModel.available("bulldog"):
			npcs.append(_npc3d("bulldog", marker("npc_armor"), -0.7))
	else:
		npcs.append(_npc("cat_white", "idle", marker("npc_navi")))
		npcs.append(_npc("cat_tabby", "idle", marker("npc_market")))
	if ModelChar.available():
		var sl := ModelChar.load_model(true)
		sl.position = marker("npc_sleep") + Vector3(0.2, 0.32, 0)
		sl.rotation_degrees = Vector3(0, 30, 82)
		sl.scale = Vector3.ONE * 0.8
		add_child(sl)
		npcs.append(sl)
	else:
		npcs.append(_npc("hamster", "sleep", marker("npc_sleep") + Vector3(0, 0.25, 0.2), 0.85))

func _labels() -> void:
	for k in STATIONS:
		if not markers.has(k):
			continue
		var l := Label3D.new()
		l.text = STATIONS[k][0]
		var fk: String = {"st_craft": "weapon", "st_potion": "potion", "st_armor": "armor"}.get(k, "")
		if fk != "" and GameState.fac(fk) > 1:
			l.text += "  Lv.%d" % GameState.fac(fk)
		l.font = FX.font()
		l.font_size = 30
		l.outline_size = 10
		l.modulate = Color("#FFE7B0") if k != "st_door" else Color("#9CFFB4")
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.fixed_size = true
		l.pixel_size = 0.0007
		l.no_depth_test = true
		l.position = markers[k] + Vector3(0, 2.0, 0)
		add_child(l)
		labels[k] = l

func _process(delta: float) -> void:
	t += delta
	if forge_light:
		forge_light.light_energy = 2.0 + sin(t * 13.0) * 0.25 + sin(t * 7.3) * 0.2
	for k in labels:
		(labels[k] as Label3D).position.y = markers[k].y + 2.0 + sin(t * 2.0 + k.length()) * 0.05

