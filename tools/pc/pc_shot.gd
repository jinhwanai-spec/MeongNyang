extends Node
# PC 실화면 확인용: 메인 씬을 띄우고 장면별 스크린샷을 _patch/shots 에 저장 후 종료
var main: Node
var frame := 0
var out := ""
var steps := []

var _save_backup := ""

func _ready() -> void:
	# 테스트 실행이 실제 저장 파일(원정 횟수·장비)을 바꾸지 않도록 백업 후 종료 시 복원
	if FileAccess.file_exists("user://save.json"):
		_save_backup = FileAccess.get_file_as_string("user://save.json")
	out = ProjectSettings.globalize_path("res://_patch/shots/")
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	var plan := "8:title;60:snap:title;65:hideout;130:snap:hideout;135:raid;220:snap:raid1;225:tp:20.5,15.3;300:snap:raid2;305:tp:40,20;380:snap:raid3;385:tp:12.5,28.6;460:snap:raid4;470:quit"
	if FileAccess.file_exists("res://_patch/plan.txt"):
		plan = FileAccess.get_file_as_string("res://_patch/plan.txt").strip_edges()
	steps = plan.split(";")

func snap(name_: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(out + name_ + ".png")
	print("saved ", name_)

func _process(_d: float) -> void:
	frame += 1
	for s in steps:
		var parts: PackedStringArray = s.split(":")
		if parts.size() < 2 or int(parts[0]) != frame:
			continue
		var arg := parts[2] if parts.size() > 2 else ""
		match parts[1]:
			"snap": snap(arg)
			"ham": get_node("/root/GameState").hamster = arg
			"skill": main.current.player.use_skill()
			"crouch": main.current.player.crouching = arg == "1"
			"hideout": main.show_hideout()
			"raid": main.start_raid()
			"press": Input.action_press(arg)
			"release": Input.action_release(arg)
			"title": main.show_title()
			"tp":
				var xy := arg.split(",")
				main.current.player.global_position = Vector2(float(xy[0]), float(xy[1])) * 48.0
			"alert":
				for e in get_tree().get_nodes_in_group("enemy"):
					if e.global_position.distance_to(main.current.player.global_position) < 700:
						e.awareness = 1.0
						e._set_state(Enemy.S.CHASE)
			"quit":
				_restore_save()
				get_tree().quit()

func _restore_save() -> void:
	if _save_backup != "":
		var f := FileAccess.open("user://save.json", FileAccess.WRITE)
		f.store_string(_save_backup)
		f.close()
