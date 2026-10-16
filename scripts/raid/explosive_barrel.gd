class_name ExplosiveBarrel
extends StaticBody2D
## 빨간 기름통: 총알·근접에 맞아 체력이 다하면 폭발 (주변 고양이·햄스터 모두 피해, 큰 소리)

const RADIUS := 115.0
const DMG := 75.0
var raid: Raid
var hp := 30.0
var done := false
var cell := Vector2i.ZERO
var marker: Node2D

func setup(r: Raid, pos: Vector2, c: Vector2i) -> void:
	raid = r
	position = pos
	cell = c

func _ready() -> void:
	add_to_group("fuel_barrel")
	collision_layer = 1
	collision_mask = 0
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = 13.0
	cs.shape = sh
	add_child(cs)
	# 3D 모형용 표시 노드는 world 바로 아래에 둬야 3D 화면이 알아본다
	marker = Node2D.new()
	marker.position = position
	marker.set_meta("prop3d", "proc:barrel_boom")
	marker.set_meta("prop_off", Vector2.ZERO)
	marker.set_meta("prop_scale", 1.25)
	raid.world.add_child.call_deferred(marker)
	raid.astar.set_point_solid(cell, true)

func bullet_hit(dmg: float, at: Vector2) -> void:
	if done:
		return
	hp -= dmg
	if is_instance_valid(FX.fx3d):
		FX.fx3d.sparks(at, (at - global_position).normalized(), Color(1, 0.8, 0.4), 5, 0.5)
	if hp <= 0.0:
		explode()

func explode() -> void:
	if done:
		return
	done = true
	var pos := global_position
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.dead:
			continue
		var d: float = e.global_position.distance_to(pos)
		if d < RADIUS:
			e.take_damage(DMG * (1.0 - d / RADIUS * 0.5), pos, 480.0)
	var pd := raid.player.global_position.distance_to(pos)
	if pd < RADIUS:
		raid.player.take_damage(DMG * 0.6 * (1.0 - pd / RADIUS * 0.5), pos)
	# 이웃 기름통도 연쇄 폭발
	for b in get_tree().get_nodes_in_group("fuel_barrel"):
		if b != self and not b.done and b.global_position.distance_to(pos) < RADIUS * 0.9:
			b.get_tree().create_timer(0.18).timeout.connect(b.explode)
	FX.explosion(raid.fx_layer, pos, RADIUS)
	if is_instance_valid(FX.fx3d):
		FX.fx3d.boom(pos, RADIUS)
	raid.shake(12.0)
	raid.emit_noise(pos, 650.0)
	Sfx.play_at("explosion", pos, 2.0, 0.1)
	raid.astar.set_point_solid(cell, false)
	raid._contract("barrel")
	collision_layer = 0
	# 3D 모형을 바꾸려고 표시 노드를 새로 만든다
	var burnt := Node2D.new()
	burnt.position = pos
	burnt.set_meta("prop3d", "proc:barrel_burnt")
	burnt.set_meta("prop_off", Vector2.ZERO)
	burnt.set_meta("prop_scale", 1.25)
	raid.world.add_child(burnt)
	marker.queue_free()
