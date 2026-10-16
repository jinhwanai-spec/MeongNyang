class_name SkillObj
extends Node2D
## 햄스터 전술 스킬이 남기는 물체: 솔방울 지뢰 / 해바라기 간식 상자 / 치즈 폭탄

var raid: Raid
var kind := ""
var t := 0.0
var life := 8.0
var from := Vector2.ZERO
var to := Vector2.ZERO
var armed := 0.0
var done := false

static func spawn(r: Raid, k: String, pos: Vector2, target: Vector2 = Vector2.ZERO) -> SkillObj:
	var o := SkillObj.new()
	o.raid = r
	o.kind = k
	o.position = pos
	o.from = pos
	o.to = target
	match k:
		"mine":
			o.life = 90.0
			o.armed = 0.6
			o.z_index = -3
		"snack":
			o.life = 8.0
			o.z_index = -3
		"bomb", "smoke":
			o.life = 0.6
			o.z_index = 5
	r.fx_layer.add_child(o)
	return o

func _process(delta: float) -> void:
	t += delta
	if kind != "snack":
		armed = maxf(0.0, armed - delta)
	match kind:
		"mine":
			if armed <= 0.0:
				for e in get_tree().get_nodes_in_group("enemy"):
					if not e.dead and e.global_position.distance_to(global_position) < 30.0:
						_explode(80.0, 50.0, 2.0)
						return
		"snack":
			var p: Player = raid.player
			if p and not p.dead and p.global_position.distance_to(global_position) < 76.0:
				p.hp = minf(p.max_hp, p.hp + 6.0 * delta)
				armed -= delta
				if armed <= -0.6:
					armed = 0.0
					FX.heal_burst(raid.fx_layer, p.global_position + Vector2(0, -30))
		"smoke":
			var ks := clampf(t / life, 0.0, 1.0)
			position = from.lerp(to, ks) + Vector2(0, -sin(ks * PI) * 70.0)
			if ks >= 1.0:
				raid.add_smoke(to, 105.0, 9.0)
				Sfx.play_at("smoke_hiss", to, -2.0, 0.1)
				queue_free()
				return
		"bomb":
			var k := clampf(t / life, 0.0, 1.0)
			position = from.lerp(to, k) + Vector2(0, -sin(k * PI) * 70.0)
			if k >= 1.0:
				position = to
				_explode(100.0, 70.0, 0.8)
				return
	if t >= life:
		queue_free()
	queue_redraw()

func _explode(radius: float, dmg: float, stun: float) -> void:
	if done:
		return
	done = true
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.dead:
			continue
		var d: float = e.global_position.distance_to(global_position)
		if d < radius:
			e.take_damage(dmg * (1.0 - d / radius * 0.4), global_position, 420.0)
			if not e.dead:
				e.stun_for(stun)
	FX.explosion(raid.fx_layer, global_position, radius)
	raid.shake(9.0)
	raid.emit_noise(global_position, 520.0 if kind == "bomb" else 300.0)
	Sfx.play_at("slam", global_position, 0.0)
	queue_free()

func _draw() -> void:
	match kind:
		"mine":
			draw_colored_polygon(Art.ellipse_pts(Vector2(0, 2), 12, 5, 16), Color(0, 0, 0, 0.3))
			draw_circle(Vector2(0, -4), 8, Color("#8A5A35"))
			for i in 6:
				var a := TAU * i / 6.0 + 0.3
				draw_line(Vector2(0, -4) + Vector2.from_angle(a) * 3.0, Vector2(0, -4) + Vector2.from_angle(a) * 9.0, Color("#5E3B22"), 2.0)
			var blink := armed <= 0.0 and fmod(t, 1.0) < 0.15
			draw_circle(Vector2(0, -12), 2.5, Color("#6CCB5F") if not blink else Color.WHITE)
		"snack":
			var a2 := 1.0 - maxf(0.0, (t - life + 1.0))
			draw_colored_polygon(Art.ellipse_pts(Vector2.ZERO, 76, 30, 40), Color(0.45, 0.85, 0.4, 0.10 * a2))
			draw_arc(Vector2.ZERO, 76, 0, TAU, 48, Color(0.45, 0.85, 0.4, 0.5 * a2), 2.0, true)
			Art.rrect(self, Rect2(-14, -14, 28, 16), Color("#F2C14E"), 4, 2)
			for i in 4:
				draw_circle(Vector2(-8 + i * 5.5, -8), 2.5, Color("#2E2E34"))
		"bomb":
			draw_colored_polygon(PackedVector2Array([Vector2(-10, 4), Vector2(10, -6), Vector2(10, 6)]), Color("#F6C445"))
			draw_circle(Vector2(4, -1), 2, Color("#D9A22E"))
			draw_circle(Vector2(-2, 2), 1.5, Color("#D9A22E"))

