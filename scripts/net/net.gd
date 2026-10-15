extends Node
## 협동 멀티 (LAN, 2~4명). 오토로드 "Net".
## 방식: 호스트가 적(고양이)의 AI·체력을 책임지고, 각자 자기 햄스터는 자기가 움직인다(반응성).
## 같은 시드로 맵·상자 내용을 똑같이 만들고, 전리품은 각자 따로(개인 전리품).

signal players_changed
signal connected_ok
signal connect_failed
signal session_ended(reason: String)
signal coop_start

const PORT := 24680
const MAX_PLAYERS := 4
const STATE_HZ := 20.0
const ENEMY_HZ := 15.0

var active := false          # 멀티 세션 중
var in_raid := false
var raid_seed := 0
var players := {}            # peer_id -> {"name", "hamster", "ready"}
var raid: Raid
var _st := 0.0
var _et := 0.0

func is_host() -> bool:
	return active and multiplayer.is_server()

func is_client() -> bool:
	return active and not multiplayer.is_server()

func my_id() -> int:
	return multiplayer.get_unique_id() if active else 1

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(func():
		_hello.rpc_id(1, Settings.nickname, GameState.hamster)
		connected_ok.emit())
	multiplayer.connection_failed.connect(func():
		leave()
		connect_failed.emit())
	multiplayer.server_disconnected.connect(func():
		var was := in_raid
		leave()
		session_ended.emit("호스트와 연결이 끊겼어요" if not was else "호스트가 원정을 끝냈어요"))

# ── 방 만들기 / 들어가기 ──────────────────────────────
func host() -> Error:
	var p := ENetMultiplayerPeer.new()
	var err := p.create_server(PORT, MAX_PLAYERS - 1)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = p
	active = true
	players = {1: {"name": Settings.nickname, "hamster": GameState.hamster, "ready": true}}
	players_changed.emit()
	return OK

func join(ip: String) -> Error:
	var p := ENetMultiplayerPeer.new()
	var err := p.create_client(ip.strip_edges() if ip.strip_edges() != "" else "127.0.0.1", PORT)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = p
	active = true
	return OK

func leave() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	active = false
	in_raid = false
	players = {}
	raid = null
	players_changed.emit()

func local_ips() -> Array:
	var out := []
	for ip in IP.get_local_addresses():
		if ip.count(".") == 3 and not ip.begins_with("127.") and not ip.begins_with("169.254"):
			out.append(ip)
	return out

func _on_peer_connected(_id: int) -> void:
	pass

func _on_peer_disconnected(id: int) -> void:
	players.erase(id)
	if is_host():
		_sync_players.rpc(players)
	players_changed.emit()
	if raid and is_instance_valid(raid):
		raid.net_remove_peer(id)

@rpc("any_peer", "reliable")
func _hello(nick: String, hamster: String) -> void:
	if not is_host():
		return
	var id := multiplayer.get_remote_sender_id()
	if players.size() >= MAX_PLAYERS or in_raid:
		return
	players[id] = {"name": nick, "hamster": hamster, "ready": false}
	_sync_players.rpc(players)
	players_changed.emit()

@rpc("authority", "reliable", "call_local")
func _sync_players(p: Dictionary) -> void:
	players = p
	players_changed.emit()

func set_my_info(ready: bool) -> void:
	if not active:
		return
	_update_info.rpc_id(1, GameState.hamster, ready)
	if is_host():
		_update_info(GameState.hamster, ready)

@rpc("any_peer", "reliable")
func _update_info(hamster: String, ready: bool) -> void:
	if not is_host():
		return
	var id := multiplayer.get_remote_sender_id()
	if id == 0:
		id = 1
	if players.has(id):
		players[id].hamster = hamster
		players[id].ready = ready
		_sync_players.rpc(players)
		players_changed.emit()

func all_ready() -> bool:
	for id in players:
		if not bool(players[id].ready):
			return false
	return players.size() >= 1

func order_of(id: int) -> int:
	var ids := players.keys()
	ids.sort()
	return maxi(0, ids.find(id))

# ── 원정 시작 ────────────────────────────────────────
func host_start() -> void:
	if not is_host():
		return
	_start.rpc(randi())

@rpc("authority", "reliable", "call_local")
func _start(s: int) -> void:
	raid_seed = s
	in_raid = true
	coop_start.emit()

func raid_ended() -> void:
	in_raid = false
	if is_host():
		_host_raid_over.rpc()

@rpc("authority", "reliable")
func _host_raid_over() -> void:
	if raid and is_instance_valid(raid) and not raid.ending:
		raid.net_host_left()
	in_raid = false

# ── 원정 중 동기화 ───────────────────────────────────
func tick(delta: float) -> void:
	if not active or raid == null or not is_instance_valid(raid) or raid.player == null:
		return
	_st += delta
	if _st >= 1.0 / STATE_HZ:
		_st = 0.0
		_player_state.rpc(raid.net_my_state())
	if is_host():
		_et += delta
		if _et >= 1.0 / ENEMY_HZ:
			_et = 0.0
			_enemy_states.rpc(raid.net_enemy_states(), raid.time_left)

@rpc("any_peer", "unreliable_ordered")
func _player_state(st: Array) -> void:
	if raid and is_instance_valid(raid):
		raid.net_apply_player(multiplayer.get_remote_sender_id(), st)

@rpc("authority", "unreliable_ordered")
func _enemy_states(list: Array, tleft: float) -> void:
	if raid and is_instance_valid(raid):
		raid.net_apply_enemies(list, tleft)

## 클라이언트가 맞힌 적 피해 → 호스트
func send_hit(eid: int, dmg: float, from: Vector2, kick: float) -> void:
	_hit.rpc_id(1, eid, dmg, from, kick)

@rpc("any_peer", "reliable")
func _hit(eid: int, dmg: float, from: Vector2, kick: float) -> void:
	if raid and is_instance_valid(raid):
		raid.net_hit_enemy(eid, dmg, from, kick, multiplayer.get_remote_sender_id())

func enemy_died(eid: int, killer: int) -> void:
	_enemy_died.rpc(eid, killer)

@rpc("authority", "reliable")
func _enemy_died(eid: int, killer: int) -> void:
	if raid and is_instance_valid(raid):
		raid.net_enemy_died(eid, killer)

func enemy_spawned(eid: int, t: String, pos: Vector2) -> void:
	_enemy_spawned.rpc(eid, t, pos)

@rpc("authority", "reliable")
func _enemy_spawned(eid: int, t: String, pos: Vector2) -> void:
	if raid and is_instance_valid(raid):
		raid.net_spawn_enemy(eid, t, pos)

## 호스트의 적이 다른 플레이어를 때림 → 그 플레이어에게
func hurt_peer(peer: int, dmg: float, from: Vector2) -> void:
	_hurt.rpc_id(peer, dmg, from)

@rpc("authority", "reliable")
func _hurt(dmg: float, from: Vector2) -> void:
	if raid and is_instance_valid(raid) and raid.player and not raid.player.dead:
		raid.player.take_damage(dmg, from)

## 총 쏘기 연출 (다른 사람 화면에)
func fired(origin: Vector2, dir: Vector2, speed: float, dist: float, wid: String, enemy: bool) -> void:
	_fired.rpc(origin, dir, speed, dist, wid, enemy)

@rpc("any_peer", "unreliable")
func _fired(origin: Vector2, dir: Vector2, speed: float, dist: float, wid: String, enemy: bool) -> void:
	if raid and is_instance_valid(raid):
		raid.net_remote_fire(origin, dir, speed, dist, wid, enemy)

## 소음 (클라이언트 → 호스트의 고양이들이 듣게)
func noise(pos: Vector2, r: float) -> void:
	_noise.rpc_id(1, pos, r)

@rpc("any_peer", "unreliable")
func _noise(pos: Vector2, r: float) -> void:
	if raid and is_instance_valid(raid):
		raid.emit_noise(pos, r, false)

func power_on() -> void:
	_power.rpc()

@rpc("any_peer", "reliable")
func _power() -> void:
	if raid and is_instance_valid(raid):
		raid.net_power_on()

func left_raid() -> void:
	if active:
		_left.rpc()

@rpc("any_peer", "reliable")
func _left() -> void:
	if raid and is_instance_valid(raid):
		raid.net_remove_peer(multiplayer.get_remote_sender_id())

func _process(delta: float) -> void:
	if in_raid:
		tick(delta)
