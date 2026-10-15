class_name UITheme
extends RefCounted
## 공통 UI 테마 (반투명 다크 네이비 + 따뜻한 주황 강조)

static var _theme: Theme
static var _bold: Font
static var _black: Font

static func bold() -> Font:
	if _bold == null:
		_bold = load("res://assets/fonts/NotoSansKR-Bold.otf")
	return _bold

static func black() -> Font:
	if _black == null:
		_black = load("res://assets/fonts/NotoSansKR-Black.otf")
	return _black

static func box(bg: Color, radius: int = 10, border: Color = Color(0, 0, 0, 0), bw: int = 0, pad: int = 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	if bw > 0:
		sb.border_color = border
		sb.set_border_width_all(bw)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad * 0.6
	sb.content_margin_bottom = pad * 0.6
	sb.anti_aliasing = true
	return sb

static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = bold()
	t.default_font_size = 17
	t.set_color("font_color", "Label", DB.C_TEXT)
	t.set_color("font_color", "Button", DB.C_TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.35))
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_stylebox("normal", "Button", box(Color("#2A3142"), 10, Color("#3B4458"), 2, 16))
	t.set_stylebox("hover", "Button", box(Color("#38415A"), 10, DB.C_HERO, 2, 16))
	t.set_stylebox("pressed", "Button", box(DB.C_HERO.darkened(0.25), 10, DB.C_HERO, 2, 16))
	t.set_stylebox("disabled", "Button", box(Color("#22283A"), 10, Color("#2A3142"), 2, 16))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), 10, Color(1, 1, 1, 0.4), 2, 16))
	t.set_stylebox("panel", "PanelContainer", box(DB.C_UI, 14, Color(1, 1, 1, 0.06), 2, 16))
	t.set_stylebox("panel", "Panel", box(DB.C_UI, 14, Color(1, 1, 1, 0.06), 2, 16))
	t.set_stylebox("tab_selected", "TabContainer", box(Color("#38415A"), 8, DB.C_HERO, 0, 16))
	t.set_stylebox("tab_unselected", "TabContainer", box(Color("#22283A"), 8, Color(0, 0, 0, 0), 0, 16))
	t.set_stylebox("tab_hovered", "TabContainer", box(Color("#2E364A"), 8, Color(0, 0, 0, 0), 0, 16))
	t.set_stylebox("panel", "TabContainer", box(Color(0, 0, 0, 0), 0, Color(0, 0, 0, 0), 0, 4))
	t.set_color("font_selected_color", "TabContainer", DB.C_HERO)
	t.set_color("font_unselected_color", "TabContainer", DB.C_MUTED)
	t.set_color("font_hovered_color", "TabContainer", DB.C_TEXT)
	t.set_font_size("font_size", "TabContainer", 18)
	var sb_scroll := StyleBoxFlat.new()
	sb_scroll.bg_color = Color(1, 1, 1, 0.05)
	sb_scroll.set_corner_radius_all(4)
	t.set_stylebox("scroll", "VScrollBar", sb_scroll)
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(1, 1, 1, 0.25)
	grab.set_corner_radius_all(4)
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab)
	_theme = t
	return t

static func label(text: String, size: int = 17, color: Color = DB.C_TEXT, heavy: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if heavy:
		l.add_theme_font_override("font", black())
	return l

static func button(text: String, size: int = 18, accent: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.focus_mode = Control.FOCUS_NONE
	if accent:
		b.add_theme_stylebox_override("normal", box(DB.C_HERO, 12, DB.C_HERO.darkened(0.3), 3, 22))
		b.add_theme_stylebox_override("hover", box(DB.C_HERO.lightened(0.12), 12, Color.WHITE, 3, 22))
		b.add_theme_stylebox_override("pressed", box(DB.C_HERO.darkened(0.15), 12, Color.WHITE, 3, 22))
		b.add_theme_color_override("font_color", Color("#1B1A22"))
		b.add_theme_color_override("font_hover_color", Color("#1B1A22"))
		b.add_theme_color_override("font_pressed_color", Color("#1B1A22"))
		b.add_theme_font_override("font", black())
	b.mouse_entered.connect(func(): Sfx.play("hover", -16.0))
	b.pressed.connect(func(): Sfx.play("click", -8.0))
	return b
