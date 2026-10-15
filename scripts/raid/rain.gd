extends Node2D
## 폭풍이 다가올수록 굵어지는 빗줄기 (화면 공간)

var strength := 0.0
var drops: Array = []

func _ready() -> void:
	for i in 220:
		drops.append([Vector2(randf() * 1920, randf() * 1080), randf_range(700, 1100), randf_range(10, 22)])

func _process(delta: float) -> void:
	if strength <= 0.01:
		if visible:
			visible = false
		return
	visible = true
	var vs := get_viewport_rect().size
	for d in drops:
		d[0].y += d[1] * delta
		d[0].x -= d[1] * 0.25 * delta
		if d[0].y > vs.y:
			d[0] = Vector2(randf() * (vs.x + 200), -20)
	queue_redraw()

func _draw() -> void:
	var n := int(drops.size() * strength)
	var c := Color(0.75, 0.82, 1.0, 0.28 * strength + 0.06)
	for i in n:
		var d: Array = drops[i]
		draw_line(d[0], d[0] + Vector2(-0.25, 1.0) * d[2], c, 1.5)
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color(0.2, 0.25, 0.4, 0.08 * strength))
