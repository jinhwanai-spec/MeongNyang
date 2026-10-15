extends Node
## 효과음·배경음 재생기. assets/sfx/이름.wav 를 자동으로 불러온다.

const POOL := 16
var _cache := {}
var _players: Array[AudioStreamPlayer] = []
var _players2d: Array[AudioStreamPlayer2D] = []
var _i := 0
var _j := 0
var _music: AudioStreamPlayer
var _music_name := ""
var sfx_volume_db := 0.0
var music_volume_db := -8.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
		var p2 := AudioStreamPlayer2D.new()
		p2.max_distance = 1500.0
		p2.attenuation = 1.6
		add_child(p2)
		_players2d.append(p2)
	_music = AudioStreamPlayer.new()
	add_child(_music)

func _stream(name_: String) -> AudioStream:
	if _cache.has(name_):
		return _cache[name_]
	var path := "res://assets/sfx/%s.wav" % name_
	var s: AudioStream = null
	if ResourceLoader.exists(path):
		s = load(path)
	_cache[name_] = s
	return s

func play(name_: String, vol_db: float = 0.0, pitch_var: float = 0.0) -> void:
	var s := _stream(name_)
	if s == null:
		return
	var p := _players[_i]
	_i = (_i + 1) % POOL
	p.stream = s
	p.volume_db = vol_db + sfx_volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.play()

func play_at(name_: String, pos: Vector2, vol_db: float = 0.0, pitch_var: float = 0.0) -> void:
	var s := _stream(name_)
	if s == null:
		return
	var p := _players2d[_j]
	_j = (_j + 1) % POOL
	p.stream = s
	p.global_position = pos
	p.volume_db = vol_db + sfx_volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.play()

func music(name_: String) -> void:
	if name_ == _music_name:
		return
	_music_name = name_
	var s := _stream("music_" + name_)
	if s == null:
		_music.stop()
		return
	if s is AudioStreamWAV:
		var w := s as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(w.get_length() * w.mix_rate)
	_music.stream = s
	_music.volume_db = music_volume_db
	_music.play()
