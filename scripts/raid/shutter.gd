class_name Shutter
extends StaticBody2D
## 하역장 셔터 (세로 3칸). 발전기가 켜지면 천천히 올라간다.

var open_k := 0.0
var opening := false
var shape: CollisionShape2D
var tiles := 3

func _ready() -> void:
	collision_layer = 1
	shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(DB.TILE, DB.TILE * tiles)
	shape.shape = rect
	shape.position = Vector2(DB.TILE * 0.5, DB.TILE * tiles * 0.5)
	add_child(shape)
	z_index = -1

func open() -> void:
	opening = true
	Sfx.play_at("shutter", global_position, 0.0)

func is_open() -> bool:
	return open_k >= 1.0

func _process(delta: float) -> void:
	if opening and open_k < 1.0:
		open_k = minf(1.0, open_k + delta / 5.0)
		if open_k >= 1.0:
			shape.set_deferred("disabled", true)
		queue_redraw()

func _draw() -> void:
	var T := float(DB.TILE)
	var h := T * tiles * (1.0 - open_k)
	draw_rect(Rect2(0, 0, T, T * tiles), Color("#1B1A22"))
	if h > 2.0:
		draw_rect(Rect2(4, 0, T - 8, h), Color("#8D96A3"))
		var n := int(h / 8.0)
		for i in n:
			draw_line(Vector2(4, i * 8 + 4), Vector2(T - 4, i * 8 + 4), Color(0, 0, 0, 0.3), 2)
		draw_rect(Rect2(4, h - 6, T - 8, 6), Color("#F2C14E"))
	draw_rect(Rect2(0, 0, 4, T * tiles), Color("#4C586B"))
	draw_rect(Rect2(T - 4, 0, 4, T * tiles), Color("#4C586B"))
