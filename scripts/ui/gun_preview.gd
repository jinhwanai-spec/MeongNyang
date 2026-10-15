class_name GunPreview
extends SubViewportContainer
## 무기 제작소 UI: 부품을 끼운 총을 3D로 천천히 돌려 보여 준다.

var vp: SubViewport
var pivot: Node3D
var t := 0.0

static func make(wid: String, mods: Dictionary, w: int = 240, h: int = 96) -> GunPreview:
	var g := GunPreview.new()
	g.custom_minimum_size = Vector2(w, h)
	g.stretch = true
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.vp = SubViewport.new()
	g.vp.size = Vector2i(w, h)
	g.vp.transparent_bg = true
	g.vp.own_world_3d = true
	g.vp.msaa_3d = Viewport.MSAA_4X
	g.add_child(g.vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1, 0.95, 0.9)
	e.ambient_light_energy = 0.7
	env.environment = e
	g.vp.add_child(env)
	var l := DirectionalLight3D.new()
	l.rotation_degrees = Vector3(-40, 30, 0)
	l.light_energy = 1.2
	g.vp.add_child(l)
	g.pivot = Node3D.new()
	g.vp.add_child(g.pivot)
	var gun := EnemyModel.weapon_scene(wid)
	if gun:
		ProcModels.attach_mods(gun, wid, mods)
		var a := ProcModels._aabb(gun)
		gun.position = -a.get_center()
		g.pivot.add_child(gun)
		var cam := Camera3D.new()
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = maxf(a.size.z * 0.55, a.size.y * 1.4)
		var cp := Vector3(3.0, 0.4, 0)
		cam.transform = Transform3D(Basis.looking_at(-cp, Vector3.UP), cp)
		g.vp.add_child(cam)
	return g

func _process(delta: float) -> void:
	t += delta
	if pivot:
		pivot.rotation.y = sin(t * 0.8) * 0.5
