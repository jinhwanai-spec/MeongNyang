extends Node
# PC 실화면 확인용: 메인 씬을 띄우고 장면별 스크린샷을 _patch/shots 에 저장 후 종료
var main: Node
var frame := 0
var out := ""
var steps := []

var _save_backup := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # 출격 카드(일시정지) 중에도 프레임을 센다
	# 테스트 실행이 실제 저장 파일(원정 횟수·장비)을 바꾸지 않도록 백업 후 종료 시 복원
	out = ProjectSettings.globalize_path("res://_patch/shots/")
	DirAccess.make_dir_recursive_absolute(out)
	# 지난 테스트가 중간에 멈춰 복원을 못 했으면 디스크에 남긴 백업으로 먼저 되돌린다
	var bk := ProjectSettings.globalize_path("res://_patch/save_backup.json")
	if FileAccess.file_exists(bk):
		_save_backup = FileAccess.get_file_as_string(bk)
		var w := FileAccess.open("user://save.json", FileAccess.WRITE)
		w.store_string(_save_backup)
		w.close()
		get_node("/root/GameState").load_game()
	elif FileAccess.file_exists("user://save.json"):
		_save_backup = FileAccess.get_file_as_string("user://save.json")
		var b := FileAccess.open(bk, FileAccess.WRITE)
		b.store_string(_save_backup)
		b.close()
	# 확인용: 저장 파일 사본 + 진행 기록
	var sc := FileAccess.open(out + "save_copy.json", FileAccess.WRITE)
	if sc:
		sc.store_string(_save_backup)
		sc.close()
	_log("start")
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	var plan := "8:title;60:snap:title;65:hideout;130:snap:hideout;135:raid;220:snap:raid1;225:tp:20.5,15.3;300:snap:raid2;305:tp:40,20;380:snap:raid3;385:tp:12.5,28.6;460:snap:raid4;470:quit"
	if FileAccess.file_exists("res://_patch/plan.txt"):
		plan = FileAccess.get_file_as_string("res://_patch/plan.txt").strip_edges()
	steps = plan.split(";")

func _log(t: String) -> void:
	var lf := FileAccess.open(out + "log.txt", FileAccess.READ_WRITE if FileAccess.file_exists(out + "log.txt") else FileAccess.WRITE)
	if lf:
		lf.seek_end()
		lf.store_line("%d %s" % [frame, t])
		lf.close()

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
		_log(parts[1] + ":" + arg)
		match parts[1]:
			"snap": snap(arg)
			"ham": get_node("/root/GameState").hamster = arg
			"skill": main.current.player.use_skill()
			"crouch": main.current.player.crouching = arg == "1"
			"hideout": main.show_hideout()
			"raid": main.start_raid()
			"fps":
				_log("FPS=%d" % Engine.get_frames_per_second())
				print("FPS=%d refresh=%.1f physics=%d vsync=%d" % [Engine.get_frames_per_second(), DisplayServer.screen_get_refresh_rate(), Engine.physics_ticks_per_second, DisplayServer.window_get_vsync_mode()])
			"mp": main.show_multiplayer()
			"mp_host":
				get_node("/root/Net").host()
				main.current._refresh()
			"mp_leave": get_node("/root/Net").leave()
			"press": Input.action_press(arg)
			"release": Input.action_release(arg)
			"title": main.show_title()
			"station": main.current._open_station(arg)
			"close": main.current._close_panel()
			"tab": main.current.panel.tabs.current_tab = int(arg)
			"ltp":
				var lxy := arg.split(",")
				main.current.player.global_position = Vector2(float(lxy[0]), float(lxy[1])) * 48.0
			"power":
				main.current.generator.powered = true
				main.current.power_on(false)
			"melee": main.current.player._melee()
			"lo":
				var kv2 := arg.split("=")
				var gs2 = get_node("/root/GameState")
				gs2.loadout[kv2[0]] = kv2[1]
				if kv2[0] in ["helmet", "vest"]:
					gs2.armor[kv2[1]] = 1
				elif kv2[0] in ["primary", "sidearm", "melee"]:
					gs2.weapons[kv2[1]] = 1
			"mod":
				var kv3 := arg.split("=")
				var gs3 = get_node("/root/GameState")
				if not gs3.mods.has(kv3[0]):
					gs3.mods[kv3[0]] = {}
				gs3.mods[kv3[0]][DB.ATTACHMENTS[kv3[1]].slot] = kv3[1]
			"give": get_node("/root/GameState").add_item(arg, 3)
			"region": get_node("/root/GameState").region = arg
			"extract":
				var rr = main.current
				rr.extract_zone = rr.exits[int(arg)]
				rr._end(true, rr.exits[int(arg)].label)
			"earmor":
				var ea := arg.split(",")
				Enemy.force_armor = [ea[0], ea[1]]
			"ammo": get_node("/root/GameState").ammo[arg] = 200
			"diff": get_node("/root/GameState").set_difficulty_preset(arg)
			"die":
				main.current.player.iframes = 0.0
				main.current.player.take_damage(99999.0, main.current.player.global_position)
			"tp":
				var xy := arg.split(",")
				main.current.player.global_position = Vector2(float(xy[0]), float(xy[1])) * 48.0
			"spawn3":
				var r = main.current
				var pp: Vector2 = r.player.global_position
				var i := 0
				for t in ["hyena", "bulldog", "cat"]:
					r._spawn_enemy(t, pp + Vector2(-150 + i * 150, -130 + (i % 2) * 50))
					i += 1
			"freeze":
				for e in get_tree().get_nodes_in_group("enemy"):
					e.process_mode = Node.PROCESS_MODE_DISABLED
			"unfreeze":
				for e in get_tree().get_nodes_in_group("enemy"):
					e.process_mode = Node.PROCESS_MODE_INHERIT
			"storm": main.current.storm_k = float(arg)
			"nextr": main.current.next_raid.emit(arg)
			"fac": get_node("/root/GameState").facility = {"weapon": int(arg), "potion": int(arg), "armor": int(arg)}
			"shield": Enemy.force_shield = arg != "0"
			"weather": Raid.force_weather = arg
			"tptrap":
				main.current.player.global_position = main.current.traps[int(arg)][1] + Vector2(-60, 0)
			"tpbarrel":
				main.current.player.global_position = get_tree().get_nodes_in_group("fuel_barrel")[int(arg)].global_position + Vector2(-150, 30)
			"boom":
				get_tree().get_nodes_in_group("fuel_barrel")[int(arg)].explode()
			"god":
				main.current.player.hp = 99999.0
				main.current.player.max_hp = 99999.0
			"camd":
				main.current.view3d.cam_dist = float(arg)
			"kill":
				for e in get_tree().get_nodes_in_group("enemy"):
					if e.global_position.distance_to(main.current.player.global_position) < float(arg if arg != "" else "400"):
						e.take_damage(999.0, main.current.player.global_position, 0.0)
			"autofire":
				var pl = main.current.player
				var en = null
				for e in get_tree().get_nodes_in_group("enemy"):
					if en == null or e.global_position.distance_to(pl.global_position) < en.global_position.distance_to(pl.global_position):
						en = e
				if en:
					pl.aim_dir = (en.global_position - pl.global_position).normalized()
				pl.input_locked = true
				pl.fire_cd = 0.0
				pl._fire()
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
	var d := DirAccess.open("res://_patch")
	if d and d.file_exists("save_backup.json"):
		var e := d.remove("save_backup.json")
		_log("backup removed %d" % e)
