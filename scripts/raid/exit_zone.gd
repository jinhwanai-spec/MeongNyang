class_name ExitZone
extends Node2D
## 탈출 지점. 안에서 버티면 탈출 성공.

var label := "탈출구"
var rect := Rect2()
var need := 6.0
var locked := false
var lock_text := ""
var t := 0.0
var progress := 0.0
var kind := "manhole"  # 3D 표식: manhole / truck / boat
var flat_3d := false   # 3D 화면: 맨홀·트럭·글씨는 3D 모델이 그린다 (바닥 표시만)

func contains(p: Vector2) -> bool:
	return rect.has_point(p)

func _ready() -> void:
	z_index = -6

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

func _draw() -> void:
	var r := Rect2(rect.position - position, rect.size)
	var c := Color("#6CCB5F") if not locked else DB.C_DANGER
	var pulse := 0.5 + 0.5 * sin(t * 3.0)
	draw_rect(r, Color(c, 0.08 + pulse * 0.06))
	# 점선 테두리
	var dash := 14.0
	var pts := [r.position, r.position + Vector2(r.size.x, 0), r.end, r.position + Vector2(0, r.size.y)]
	for i in 4:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % 4]
		var L := a.distance_to(b)
		var n := int(L / dash)
		for k in n:
			if k % 2 == 0:
				draw_line(a.lerp(b, k / float(n)), a.lerp(b, (k + 1) / float(n)), Color(c, 0.75), 3)
	var cc := r.get_center()
	if flat_3d:
		return
	if label.begins_with("A"):
		# 맨홀
		draw_circle(cc, 30, Art.OUTLINE)
		draw_circle(cc, 27, Color("#4A505E"))
		for i in 4:
			draw_line(cc + Vector2(-20, -12 + i * 8), cc + Vector2(20, -12 + i * 8), Color("#2A2F3A"), 2)
	else:
		# 하역장 트럭
		Art.rrect(self, Rect2(cc + Vector2(-34, -60), Vector2(68, 90)), Color("#D8DEE6"), 6)
		Art.rrect(self, Rect2(cc + Vector2(-30, 30), Vector2(60, 30)), Color("#3E5C8A"), 6)
		draw_rect(Rect2(cc + Vector2(-24, 36), Vector2(48, 10)), Color("#8FB3C9"))
		draw_string(FX.font(), cc + Vector2(-26, -12), "멍냥택배", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, DB.C_HERO)
	# 신호탄 연기
	if not locked:
		for i in 4:
			var k := fmod(t * 0.5 + i * 0.25, 1.0)
			draw_circle(r.position + Vector2(r.size.x - 18, 10) + Vector2(sin(t + i) * 6, -k * 70), 6 + k * 12, Color(0.45, 0.9, 0.5, 0.35 * (1.0 - k)))
		draw_circle(r.position + Vector2(r.size.x - 18, 12), 5, Color("#B8FFB0"))
	var font := FX.font()
	var txt := label if not locked else label + " (잠김)"
	var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_string_outline(font, Vector2(cc.x - w * 0.5, r.position.y - 10), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 5, Color(0, 0, 0, 0.8))
	draw_string(font, Vector2(cc.x - w * 0.5, r.position.y - 10), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, c)
	if locked and lock_text != "":
		var w2 := font.get_string_size(lock_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_string_outline(font, Vector2(cc.x - w2 * 0.5, r.position.y + 12), lock_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, Color(0, 0, 0, 0.8))
		draw_string(font, Vector2(cc.x - w2 * 0.5, r.position.y + 12), lock_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, DB.C_TEXT)
