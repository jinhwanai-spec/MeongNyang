class_name Settings
extends RefCounted
## 게임 설정 (user://settings.cfg). 소리·화면·그래픽 품질·화면 흔들림.

const PATH := "user://settings.cfg"
static var master := 0.8
static var sfx := 0.9
static var music := 0.7
static var fullscreen := false
static var vsync := true
static var quality := 2        # 0 낮음 · 1 보통 · 2 높음
static var shake := 1.0
static var nickname := "햄찌"
static var _loaded := false

static func load_settings() -> void:
	_loaded = true
	var c := ConfigFile.new()
	if c.load(PATH) != OK:
		return
	master = float(c.get_value("audio", "master", master))
	sfx = float(c.get_value("audio", "sfx", sfx))
	music = float(c.get_value("audio", "music", music))
	fullscreen = bool(c.get_value("video", "fullscreen", fullscreen))
	vsync = bool(c.get_value("video", "vsync", vsync))
	quality = int(c.get_value("video", "quality", quality))
	shake = float(c.get_value("game", "shake", shake))
	nickname = str(c.get_value("game", "nickname", nickname))

static func save_settings() -> void:
	var c := ConfigFile.new()
	c.set_value("audio", "master", master)
	c.set_value("audio", "sfx", sfx)
	c.set_value("audio", "music", music)
	c.set_value("video", "fullscreen", fullscreen)
	c.set_value("video", "vsync", vsync)
	c.set_value("video", "quality", quality)
	c.set_value("game", "shake", shake)
	c.set_value("game", "nickname", nickname)
	c.save(PATH)

static func apply() -> void:
	if not _loaded:
		load_settings()
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master, 0.0001)))
	if Engine.has_singleton("Sfx") or true:
		var tree := Engine.get_main_loop() as SceneTree
		if tree and tree.root.has_node("Sfx"):
			var s = tree.root.get_node("Sfx")
			s.music_volume_db = linear_to_db(maxf(music, 0.0001)) - 4.0
			s.sfx_volume_db = linear_to_db(maxf(sfx, 0.0001))
			if s.get("_music"):
				s._music.volume_db = s.music_volume_db
	if not DisplayServer.get_name().begins_with("headless"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)

## 3D 환경에 그래픽 품질 반영
static func apply_env(e: Environment, sun: DirectionalLight3D = null) -> void:
	if not _loaded:
		load_settings()
	e.ssao_enabled = quality >= 1
	e.ssil_enabled = quality >= 2
	e.glow_enabled = quality >= 1
	if sun:
		sun.shadow_enabled = true
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if quality < 2 else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		sun.shadow_blur = 1.0 if quality == 0 else 2.5
