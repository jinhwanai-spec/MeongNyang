extends Node
## 화면 전환: 타이틀 → 은신처 → 원정 → 결과 → 은신처 ...

var current: Node
var fade: ColorRect

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
	_swap(rs)
