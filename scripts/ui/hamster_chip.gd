class_name HamsterChip
extends Button
## 은신처 출발 준비: 햄스터 용병 초상 버튼 (선택 시 노란 테두리 + 살짝 뛰어오름)

var hid := ""
var selected := false
var t := 0.0

static func make(id: String, sel: bool) -> HamsterChip:
	var c := HamsterChip.new()
	c.hid = id
	c.selected = sel
	c.custom_minimum_size = Vector2(64, 88)
	c.flat = true
	c.focus_mode = Control.FOCUS_NONE
	c.tooltip_text = "%s · %s" % [DB.HAMSTERS[id].name, DB.HAMSTERS[id].role]
	return c

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

func _draw() -> void:
	var r := Rect2(Vector2(2, 2), size - Vector2(4, 4))
	var hov := is_hovered()
	var fur := Color(str(DB.HAMSTERS[hid].fur))
	Art.rrect(self, r, Color("#2A2430") if not selected else Color("#3B3226"), 10, 0)
	draw_rect(Rect2(r.position + Vector2(4, 4), Vector2(r.size.x - 8, 46)), Color(fur, 0.22))
	var kind := "hamster_" + hid
	if Sprites.char_info(kind).is_empty():
		kind = "hamster"
	var anim := "portrait_happy" if selected else "portrait"
	if not Sprites.has_anim(kind, anim):
		anim = "idle_front"
	var bob := -absf(sin(t * 5.0)) * 4.0 if selected else 0.0
	Sprites.draw_char(self, kind, Sprites.char_frame(kind, anim, t), Vector2(size.x * 0.5, 60 + bob), 0.56 if selected or hov else 0.5)
	var f := UITheme.bold()
	var nm: String = DB.HAMSTERS[hid].name
	draw_string(f, Vector2(0, size.y - 10), nm, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, DB.C_LEGEND if selected else DB.C_TEXT)
	var bc := DB.C_LEGEND if selected else (Color(1, 1, 1, 0.35) if hov else Color(1, 1, 1, 0.08))
	draw_style_box(UITheme.box(Color(0, 0, 0, 0), 10, bc, 3 if selected else 2, 0), r)
