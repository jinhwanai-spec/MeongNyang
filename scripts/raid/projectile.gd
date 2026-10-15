class_name Projectile
extends Node2D
## 총알·화살. 매 프레임 레이캐스트로 벽/대상 충돌을 검사한다.

var raid: Raid
var vel := Vector2.ZERO
var dmg := 10.0
var max_dist := 600.0
var travelled := 0.0
var from_player := true
var weapon := ""
var kick := 60.0
var pierce := 0
var recoverable := false
var exclude: Array[RID] = []
var origin := Vector2.ZERO

func setup(r: Raid, pos: Vector2, dir: Vector2, speed: float, damage: float, dist: float, player_owned: bool, wid: String) -> void:
	raid = r
	position = pos
	origin = pos
	vel = dir * speed
	dmg = damage
	max_dist = dist
	from_player = player_owned
	weapon = wid
	rotation = dir.angle()
	z_index = 5

func _physics_process(delta: float) -> void:
	var step := vel * delta
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(global_position, global_position + step)
	q.collision_mask = (1 | 4) if from_player else (1 | 2)
	q.exclude = exclude
	var hit := space.intersect_ray(q)
	if hit:
		var col: Object = hit.collider
		if col is Enemy and from_player:
			var e: Enemy = col
			if not e.dead:
				var fall := clampf(1.0 - (travelled / max_dist) * 0.5, 0.5, 1.0)
				e.take_damage(dmg * fall, origin, kick)
				FX.hit_spark(raid.fx_layer, hit.position, -vel.normalized(), Color("#FFE3A3"))
				if recoverable and randf() < 0.5:
					raid.spawn_bolt_pickup(e.global_position + Vector2(randf_range(-12, 12), 6))
			if pierce > 0:
				pierce -= 1
				exclude.append(e.get_rid())
				global_position = hit.position
				return
			queue_free()
			return
		elif col is Player and not from_player:
			(col as Player).take_damage(dmg, origin)
			queue_free()
			return
		# 벽
		FX.hit_spark(raid.fx_layer, hit.position, hit.normal, Color("#C9D1DA"))
		Sfx.play_at("ricochet", hit.position, -12.0)
		if recoverable:
			raid.spawn_bolt_pickup(hit.position + hit.normal * 10.0)
		queue_free()
		return
	global_position += step
	travelled += step.length()
	if travelled >= max_dist:
		if recoverable:
			raid.spawn_bolt_pickup(global_position)
		queue_free()
	queue_redraw()

func _draw() -> void:
	if weapon == "enemy_bolt":
		var l := minf(34.0, travelled + 4.0)
		draw_line(Vector2(-l, 0), Vector2(0, 0), Color(1, 0.3, 0.25, 0.5), 6, true)
		draw_line(Vector2(-l * 0.7, 0), Vector2(2, 0), Color("#FFD0C8"), 2.5, true)
		draw_circle(Vector2.ZERO, 8, Color(DB.C_DANGER, 0.25))
	elif weapon == "crossbow":
		var c := Color("#F2C14E")
		draw_line(Vector2(-22, 0), Vector2(6, 0), Art.OUTLINE, 5, true)
		draw_line(Vector2(-22, 0), Vector2(6, 0), Color("#C9A27A"), 2.5, true)
		draw_colored_polygon(PackedVector2Array([Vector2(12, 0), Vector2(4, -4), Vector2(4, 4)]), Color("#D8DEE6"))
		draw_colored_polygon(PackedVector2Array([Vector2(-22, 0), Vector2(-27, -5), Vector2(-17, 0), Vector2(-27, 5)]), c)
		if not from_player:
			draw_circle(Vector2.ZERO, 10, Color(DB.C_DANGER, 0.25))
	else:
		var length := minf(26.0, travelled + 4.0)
		draw_line(Vector2(-length, 0), Vector2(0, 0), Color(1, 0.85, 0.5, 0.45), 4, true)
		draw_line(Vector2(-length * 0.6, 0), Vector2(2, 0), Color("#FFF5D6"), 2, true)
