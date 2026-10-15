class_name ItemIcon
extends Control
## UI용 아이템/무기 아이콘 칸

var id := ""
var weapon := false
var count := -1
var danger := false
var dim := false

static func make(item_id: String, size: float = 56.0, is_weapon: bool = false, n: int = -1) -> ItemIcon:
	var ic := ItemIcon.new()
	ic.id = item_id
	ic.weapon = is_weapon
	ic.count = n
	ic.custom_minimum_size = Vector2(size * (1.8 if is_weapon else 1.0), size)
	ic.mouse_filter = Control.MOUSE_FILTER_PASS
	if not is_weapon and DB.ITEMS.has(item_id):
		var it: Dictionary = DB.ITEMS[item_id]
		ic.tooltip_text = "%s  [%s]\n판매가 %d냥\n%s" % [it.name, DB.RARITY_NAMES[int(it.r)], int(it.v), it.desc]
	elif is_weapon:
		ic.tooltip_text = "%s\n%s" % [DB.WEAPONS[item_id].name, DB.WEAPONS[item_id].desc]
	return ic

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var rc := DB.rarity_color(int(DB.WEAPONS[id].r) if weapon else int(DB.ITEMS[id].r))
	var border := DB.C_DANGER if danger else rc
	UITheme.box(Color(rc.darkened(0.78), 0.95), 8, border, 2).draw(get_canvas_item(), r)
	if dim:
		modulate = Color(1, 1, 1, 0.4)
	if weapon:
		Art.draw_weapon_icon(self, id, r.get_center() + Vector2(-4, 0), size.y / 40.0)
	else:
		Art.draw_item_icon(self, id, r.grow(-6))
	if count >= 0:
		var f := UITheme.black()
		var s := "×%d" % count
		draw_string_outline(f, Vector2(4, size.y - 5), s, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 8, 14, 4, Color(0, 0, 0, 0.9))
		draw_string(f, Vector2(4, size.y - 5), s, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 8, 14, DB.C_TEXT)
