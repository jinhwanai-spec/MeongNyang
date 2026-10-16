extends Node
## 화면 전환: 타이틀 → 은신처 → 원정 → 결과 → 은신처 ...

var current: Node
var fade: ColorRect
var deploy_from := ""   # 연속 원정이면 출발 지역 (출격 카드 왼쪽 이름)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Settings.apply()
	var cl := CanvasLayer.new()
	cl.layer = 100
	add_child(cl)
	fade = ColorRect.new()
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0.05, 0.06, 0.09, 0.0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(fade)
	var args := OS.get_cmdline_user_args()
	if args.has("--raid"):
		start_raid()
	elif args.has("--hideout"):
		show_hideout()
	else:
		show_title()

func _swap(n: Node) -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	if current:
		current.queue_free()
	current = n
	add_child(n)
	move_child(n, 0)
	fade.color.a = 1.0
	var tw := create_tween()
	if n is Raid:
		# 출격 카드: 어두운 화면 뒤에서 3D 셰이더를 미리 굽는 동안 이동 연출
		var card := DeployCard.make(LevelData.region, deploy_from)
		deploy_from = ""
		fade.get_parent().add_child(card)
		if not Net.active:
			get_tree().paused = true
		tw.tween_interval(card.dur)
		tw.tween_callback(func(): get_tree().paused = false)
		tw.tween_property(card, "modulate:a", 0.0, 0.35)
		tw.parallel().tween_property(fade, "color:a", 0.0, 0.35)
		tw.tween_callback(card.queue_free)
		return
	tw.tween_property(fade, "color:a", 0.0, 0.35)

func show_title() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var t := MainMenu.new()
	t.play.connect(show_hideout)
	t.new_game.connect(func():
		GameState.new_game()
		show_hideout())
	t.multi.connect(show_multiplayer)
	_swap(t)

## 은신처: 3D 로비를 걸어 다니다 출구로 나가면 원정 시작
func show_hideout() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var h := Lobby.new()
	h.start_raid.connect(start_raid)
	h.to_title.connect(show_title)
	_swap(h)

func show_multiplayer() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var m := MultiplayerMenu.new()
	m.back.connect(show_title)
	m.start_coop.connect(start_raid)
	_swap(m)

func start_raid() -> void:
	var kit := GameState.begin_raid()
	var r := Raid.new()
	r.setup(kit)
	r.finished.connect(show_result)
	_swap(r)

func show_result(result: Dictionary) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var rs := ResultScreen.new()
	rs.result = result
	rs.done.connect(func():
		if Net.active:
			show_multiplayer()
		else:
			show_hideout())
	rs.next_raid.connect(func(rid: String):
		deploy_from = LevelData.region
		GameState.region = rid
		GameState.save_game()
		start_raid())
	_swap(rs)
