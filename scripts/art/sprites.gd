class_name Sprites
extends RefCounted
## 블렌더에서 렌더한 스프라이트 접근 도우미 (assets/sprites)

const BASE := "res://assets/sprites/"
const SCALE := 0.6          # 렌더 해상도 → 게임 화면 배율 (캐릭터·무기)
static var _tex := {}

static func _load(path: String) -> Texture2D:
	if _tex.has(path):
		return _tex[path]
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path)
	_tex[path] = t
	return t

# ── 캐릭터 ───────────────────────────────────────────
static func char_info(kind: String) -> Dictionary:
	return SpriteData.DATA.chars.get(kind, {})

static func char_tex(kind: String) -> Texture2D:
	return _load(BASE + "chars/%s.png" % kind)

static func has_anim(kind: String, anim: String) -> bool:
	return char_info(kind).anims.has(anim)

static func char_frame(kind: String, anim: String, t: float) -> int:
	var info := char_info(kind)
	var a: Array = info.anims.get(anim, info.anims.idle)
	return int(a[0]) + int(floor(t)) % int(a[1])

## Sprite2D를 캐릭터 스트립으로 설정
static func setup_char_sprite(spr: Sprite2D, kind: String) -> void:
	var info := char_info(kind)
	spr.texture = char_tex(kind)
	spr.hframes = int(info.count)
	spr.centered = false
	var k := char_scale(kind)
	spr.scale = Vector2(k, k)
	spr.offset = -Vector2(info.anchor[0], info.anchor[1])
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

## 게임 화면 배율 (시트 스프라이트는 종류별 목표 키에 맞춤)
static func char_scale(kind: String) -> float:
	return float(char_info(kind).get("scale", SCALE))

## 캐릭터 머리 위 높이(px, 게임 배율)
static func char_height(kind: String) -> float:
	var info := char_info(kind)
	return float(info.get("h", info.anchor[1])) * char_scale(kind)

static func face_char_sprite(spr: Sprite2D, kind: String, facing: float) -> void:
	var info := char_info(kind)
	spr.flip_h = (facing < 0.0) != bool(info.get("faces_left", false))
	var ax: float = info.anchor[0]
	if spr.flip_h:
		ax = float(info.frame[0]) - ax
	spr.offset = -Vector2(ax, info.anchor[1])

## 캔버스에 캐릭터 한 프레임 그리기 (UI·은신처·타이틀용). pos = 발 위치
static func draw_char(ci: CanvasItem, kind: String, frame: int, pos: Vector2, scale_k: float, flip: bool = false, mod: Color = Color.WHITE) -> void:
	var tex := char_tex(kind)
	if tex == null:
		return
	var info := char_info(kind)
	var fw: float = info.frame[0]
	var fh: float = info.frame[1]
	var src := Rect2(frame * fw, 0, fw, fh)
	# UI 배율은 예전 렌더(키 약 140px) 기준 → 시트 스프라이트 키로 보정
	if info.has("h"):
		scale_k *= 140.0 / float(info.h)
	if info.get("faces_left", false):
		flip = not flip
	var ax: float = info.anchor[0]
	if flip:
		ax = fw - ax
	if flip:
		# 음수 크기 사각형은 그려지지 않으므로 좌우 반전 변환으로 그린다
		ci.draw_set_transform(pos, 0.0, Vector2(-1, 1))
		ci.draw_texture_rect_region(tex, Rect2(-Vector2(info.anchor[0], info.anchor[1]) * scale_k, Vector2(fw, fh) * scale_k), src, mod)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var dst := Rect2(pos - Vector2(ax, info.anchor[1]) * scale_k, Vector2(fw, fh) * scale_k)
	ci.draw_texture_rect_region(tex, dst, src, mod)

# ── 무기 ─────────────────────────────────────────────
static func weapon_key(owner: String, wid: String) -> String:
	return "%s__%s" % [owner, wid]

static func weapon_tex(owner: String, wid: String) -> Texture2D:
	return _load(BASE + "weapons/%s.png" % weapon_key(owner, wid))

static func weapon_info(owner: String, wid: String) -> Dictionary:
	return SpriteData.DATA.weapons.get(weapon_key(owner, wid), {})

static func setup_weapon_sprite(spr: Sprite2D, owner: String, wid: String) -> void:
	var info := weapon_info(owner, wid)
	spr.texture = weapon_tex(owner, wid)
	spr.centered = false
	spr.scale = Vector2(SCALE, SCALE)
	if info.is_empty():
		return
	spr.offset = -Vector2(info.anchor[0], info.anchor[1])

static func aim_weapon_sprite(spr: Sprite2D, owner: String, wid: String, flipped: bool) -> void:
	var info := weapon_info(owner, wid)
	if info.is_empty():
		return
	spr.flip_v = flipped
	var ay: float = info.anchor[1]
	if flipped:
		ay = float(info.size[1]) - ay
	spr.offset = -Vector2(info.anchor[0], ay)

## 총구까지 거리(px, 게임 배율)
static func muzzle_dist(owner: String, wid: String) -> float:
	# 시트 캐릭터는 총을 몸에 붙여 들고 있으므로 몸 크기 기준 거리
	if char_info(owner).has("h"):
		return char_height(owner) * 0.46
	var info := weapon_info(owner, wid)
	if info.is_empty():
		return 30.0
	return (float(info.size[0]) - float(info.anchor[0])) * SCALE - 4.0

# ── 소품 ─────────────────────────────────────────────
static func prop_tex(name_: String) -> Texture2D:
	return _load(BASE + "props/%s.png" % name_)

static func prop_info(name_: String) -> Dictionary:
	return SpriteData.DATA.props.get(name_, {})

## center = 타일 중심(발판 중앙)
static func draw_prop(ci: CanvasItem, name_: String, center: Vector2, modulate: Color = Color.WHITE) -> void:
	var tex := prop_tex(name_)
	var info := prop_info(name_)
	if tex == null or info.is_empty():
		return
	var s := float(DB.TILE) / float(info.px_per_tile)
	var dst := Rect2(center - Vector2(info.anchor[0], info.anchor[1]) * s, Vector2(tex.get_size()) * s)
	ci.draw_texture_rect(tex, dst, false, modulate)

static func make_prop_sprite(name_: String) -> Sprite2D:
	var spr := Sprite2D.new()
	var info := prop_info(name_)
	spr.texture = prop_tex(name_)
	spr.centered = false
	if not info.is_empty():
		var s := float(DB.TILE) / float(info.px_per_tile)
		spr.scale = Vector2(s, s)
		spr.offset = -Vector2(info.anchor[0], info.anchor[1])
	return spr

# ── 시트 소품(맵 장식) ─────────────────────────────
static func sprop_info(name_: String) -> Dictionary:
	return SpriteData.DATA.get("sprops", {}).get(name_, {})

static func make_sprop_sprite(name_: String, size_k: float = 1.0) -> Sprite2D:
	var spr := Sprite2D.new()
	var info := sprop_info(name_)
	spr.texture = _load(BASE + "sprops/%s.png" % name_)
	spr.centered = false
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if not info.is_empty():
		var s := float(DB.TILE) / float(info.px_per_tile) * size_k
		spr.scale = Vector2(s, s)
		spr.offset = -Vector2(info.anchor[0], info.anchor[1])
		# 바닥 그림자 (스프라이트 뒤)
		var sh := Node2D.new()
		sh.show_behind_parent = true
		var w: float = float(info.size[0]) * 0.42
		sh.draw.connect(func(): sh.draw_colored_polygon(Art.ellipse_pts(Vector2(0, -2), w, w * 0.32, 20), Color(0, 0, 0, 0.28)))
		spr.add_child(sh)
	return spr

static func draw_sprop(ci: CanvasItem, name_: String, center: Vector2, modulate: Color = Color.WHITE, size_k: float = 1.0) -> void:
	var tex := _load(BASE + "sprops/%s.png" % name_)
	var info := sprop_info(name_)
	if tex == null or info.is_empty():
		return
	var s := float(DB.TILE) / float(info.px_per_tile) * size_k
	ci.draw_texture_rect(tex, Rect2(center - Vector2(info.anchor[0], info.anchor[1]) * s, Vector2(tex.get_size()) * s), false, modulate)

# ── 이펙트·UI 아이콘 (시트) ─────────────────────────
static func fx_tex(name_: String) -> Texture2D:
	return _load(BASE + "fx/%s.png" % name_)

static func ui_tex(name_: String) -> Texture2D:
	return _load(BASE + "ui/%s.png" % name_)

static func icon_tex(name_: String) -> Texture2D:
	return _load(BASE + "icons/%s.png" % name_)

## 텍스처를 사각형 안에 비율 유지로 그리기
static func draw_fit(ci: CanvasItem, tex: Texture2D, r: Rect2, mod: Color = Color.WHITE) -> void:
	if tex == null:
		return
	var ts := Vector2(tex.get_size())
	var k := minf(r.size.x / ts.x, r.size.y / ts.y)
	var sz := ts * k
	ci.draw_texture_rect(tex, Rect2(r.get_center() - sz * 0.5, sz), false, mod)

# ── 아이템 아이콘 ────────────────────────────────────
static func item_tex(id: String) -> Texture2D:
	if id.begins_with("w_") or id == "ammo_rifle":
		var t := icon_tex(id)
		if t:
			return t
	if not SpriteData.DATA.items.has(id):
		# 새 아이템(물약·갑옷·부품·재료)은 3D로 렌더한 아이콘
		if ResourceLoader.exists(BASE + "icons/%s.png" % id):
			return _load(BASE + "icons/%s.png" % id)
		return null
	return _load(BASE + "items/%s.png" % id)

static func draw_item(ci: CanvasItem, id: String, r: Rect2) -> bool:
	var tex := item_tex(id)
	if tex == null:
		return false
	var ts := Vector2(tex.get_size())
	var k := minf(r.size.x / ts.x, r.size.y / ts.y)
	var sz := ts * k
	ci.draw_texture_rect(tex, Rect2(r.get_center() - sz * 0.5, sz), false)
	return true

## 흰색 번쩍임 셰이더 (피격 연출)
static var _flash_shader: Shader
static func flash_material() -> ShaderMaterial:
	if _flash_shader == null:
		_flash_shader = Shader.new()
		_flash_shader.code = "shader_type canvas_item;\nrender_mode unshaded;\nuniform float flash = 0.0;\nuniform vec3 lift = vec3(1.0);\nvoid fragment() {\n\tvec4 c = COLOR;\n\tc.rgb = mix(c.rgb * lift, vec3(1.0), flash);\n\tCOLOR = c;\n}\n"
	var m := ShaderMaterial.new()
	m.shader = _flash_shader
	m.set_shader_parameter("lift", LIFT)
	return m

## 레이드의 밤 색조(CanvasModulate)를 캐릭터에서 되돌려 밝고 선명하게 보이게 함
static var LIFT := Vector3.ONE
