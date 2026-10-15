class_name Generator
extends StaticBody2D
## 창고 발전기. 켜면 하역장 셔터(탈출구 B)가 열리지만, 큰 소음으로 적을 부른다.

var raid: Raid
var powered := false
var highlighted := false
var t := 0.0

func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(DB.TILE - 4, DB.TILE - 10)
	shape.shape = rect
	shape.position = Vector2(0, -DB.TILE * 0.5 + 2)
	add_child(shape)

func display_name() -> String:
	return "비상 발전기"

func can_interact(_p: Node) -> bool:
	return not powered

func hold_time() -> float:
	return 3.5

func prompt() -> String:
	return "E  발전기 가동 (하역장 셔터 개방 · 큰 소음!)"

func on_search_start() -> void:
	Sfx.play_at("crank", global_position, -2.0)
	raid.emit_noise(global_position, 200.0)

func on_interact(_p: Node) -> void:
	powered = true
	raid.power_on()

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

func _draw() -> void:
	var T := float(DB.TILE)
	var base := Vector2(-T * 0.5, -T)
	if highlighted and not powered:
		draw_rect(Rect2(base - Vector2(4, 12), Vector2(T + 8, T + 16)), Color(1, 0.95, 0.7, 0.2))
	var shake := Vector2(randf_range(-1, 1), randf_range(-1, 1)) if powered else Vector2.ZERO
	Sprites.draw_prop(self, "generator", Vector2(0, -T * 0.5) + shake)
	if powered:
		var k := fmod(t, 0.6) / 0.6
		draw_circle(base + Vector2(10, -12 - k * 20), 4 + k * 6, Color(0.6, 0.6, 0.65, 0.5 * (1.0 - k)))
