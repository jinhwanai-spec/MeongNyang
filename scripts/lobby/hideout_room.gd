class_name HideoutRoom
extends Node3D
## 3D 은신처 방 (블렌더 hideout.glb) + 따뜻한 조명 + NPC + 장소 이름표.
## 로비(걸어 다니기)와 메인화면 배경이 함께 쓴다.

const STATIONS := {
	"st_prep": ["출발 준비", "용병·무기·간식 고르기", 0],
	"st_craft": ["작업대", "나비의 제작", 1],
	"st_market": ["냥이 시장", "팔고 사기", 2],
	"st_stash": ["보관함", "모은 물건", 3],
	"st_door": ["출구", "나가면 원정 시작", -1],
}

var room: Node3D
var markers := {}      # 이름 -> Vector3
var colliders := []    # [중심 Vector2(타일), 반크기 Vector2(타일)]
var env: Environment
var sun: DirectionalLight3D
var labels := {}
var t := 0.0
var npcs: Array[Node3D] = []

func _ready() -> void:
	room = (load("res://assets/models/hideout.glb") as PackedScene).instantiate()
	add_child(room)
	_read_markers(room)
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

func _npcs() -> void:
	# 기술 고양이 나비 (작업대), 시장 상인 (줄무늬 고양이), 잠자는 동료 햄스터 — 시트 그림 그대로
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
	for k in labels:
		(labels[k] as Label3D).position.y = markers[k].y + 2.0 + sin(t * 2.0 + k.length()) * 0.05

