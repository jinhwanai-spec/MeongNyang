class_name Birds
extends Node3D
## 바닥에서 모이를 쪼는 새 무리. 햄스터가 다가가면 푸드덕 날아오르며 소리를 낸다
## (근처 고양이가 그 소리를 듣고 이쪽을 살피러 온다)

var raid: Raid
var flock: Array = []      # [Node3D, 날기 시작했나, 속도 Vector3, 날개 위상]
var center2d := Vector2.ZERO
var flushed := false
var t := 0.0

static func make(r: Raid, center_tile: Vector2, kind: String, n: int) -> Birds:
	var b := Birds.new()
	b.raid = r
	b.center2d = center_tile * float(DB.TILE)
	for i in n:
		var m := ProcModels.bird(kind)
		m.position = Vector3(center_tile.x + randf_range(-0.8, 0.8), 0.0, center_tile.y + randf_range(-0.6, 0.6))
		m.rotation.y = randf() * TAU
		m.scale = Vector3.ONE * (1.25 if kind == "gull" else 1.0)
		b.add_child(m)
		b.flock.append([m, false, Vector3.ZERO, randf() * TAU])
	return b

func _process(delta: float) -> void:
	t += delta
	if raid == null or raid.player == null:
		return
	if not flushed:
		var d := raid.player.global_position.distance_to(center2d)
		var near := d < float(DB.TILE) * (2.2 if raid.player.crouching else 3.6)
		# 총소리가 가까우면 놀라서 날아간다
		if near:
			_flush()
	for f in flock:
		var m: Node3D = f[0]
		var wings: Node3D = m.get_node("wings")
		if not f[1]:
			# 땅에서 콕콕 쪼기
			m.rotation.z = maxf(0.0, sin(t * 6.0 + f[3])) * 0.35
			continue
		f[3] += delta * 28.0
		wings.get_node("L").rotation.x = sin(f[3]) * 0.9
		wings.get_node("R").rotation.x = -sin(f[3]) * 0.9
		m.position += f[2] * delta
		f[2].y += delta * 0.8
		if m.position.y > 9.0:
			m.visible = false

func _flush() -> void:
	flushed = true
	Sfx.play_at("dodge", center2d, -4.0, 0.3)
	raid.emit_noise(center2d, 260.0)
	var away := (center2d - raid.player.global_position).normalized()
	for f in flock:
		var m: Node3D = f[0]
		var dir := Vector3(away.x + randf_range(-0.5, 0.5), 0, away.y + randf_range(-0.5, 0.5)).normalized()
		f[1] = true
		f[2] = dir * randf_range(3.0, 4.5) + Vector3(0, randf_range(1.6, 2.4), 0)
		m.rotation = Vector3(0, atan2(-dir.z, dir.x), 0)
		m.rotation.z = 0.25
