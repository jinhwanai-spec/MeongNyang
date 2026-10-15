class_name BoltPickup
extends Node2D
## 바닥에 떨어진 석궁 화살. 가까이 가면 자동으로 회수.

var t := 0.0

func _ready() -> void:
	add_to_group("bolt_pickup")
	rotation = randf() * TAU
	z_index = -3

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 10 + sin(t * 4.0) * 2.0, Color(DB.C_LEGEND, 0.18))
	draw_line(Vector2(-14, 0), Vector2(10, 0), Art.OUTLINE, 4)
	draw_line(Vector2(-14, 0), Vector2(10, 0), Color("#C9A27A"), 2)
	draw_colored_polygon(PackedVector2Array([Vector2(14, 0), Vector2(8, -3), Vector2(8, 3)]), Color("#D8DEE6"))
	draw_colored_polygon(PackedVector2Array([Vector2(-14, 0), Vector2(-18, -4), Vector2(-11, 0), Vector2(-18, 4)]), DB.C_LEGEND)
