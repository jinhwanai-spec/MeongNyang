# 멍냥서바이벌 블렌더 에셋 공용 라이브러리 (Blender 4.2 ~ 5.x)
import bpy, bmesh, math, os, json, traceback
from mathutils import Vector, Euler, Matrix, Quaternion

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "_render")
SRC = os.path.join(ROOT, "assets", "source")
os.makedirs(OUT, exist_ok=True)
os.makedirs(SRC, exist_ok=True)
LOG = os.path.join(OUT, "log.txt")
META_PATH = os.path.join(OUT, "meta.json")

def log(*a):
    with open(LOG, "a", encoding="utf-8") as f:
        f.write(" ".join(str(x) for x in a) + "\n")

def load_meta():
    if os.path.exists(META_PATH):
        with open(META_PATH, encoding="utf-8") as f:
            return json.load(f)
    return {}

def save_meta(m):
    with open(META_PATH, "w", encoding="utf-8") as f:
        json.dump(m, f, ensure_ascii=False, indent=1)

# ── 씬 ─────────────────────────────────────────────
SCN = None

def new_scene(name):
    global SCN
    old = bpy.data.scenes.get(name)
    if old:
        for ob in list(old.collection.all_objects):
            bpy.data.objects.remove(ob, do_unlink=True)
        bpy.data.scenes.remove(old)
    SCN = bpy.data.scenes.new(name)
    try:
        bpy.context.window.scene = SCN
    except Exception:
        pass
    r = SCN.render
    for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            r.engine = eng
            break
        except Exception:
            pass
    r.film_transparent = True
    r.image_settings.file_format = "PNG"
    r.image_settings.color_mode = "RGBA"
    r.resolution_percentage = 100
    try:
        SCN.eevee.taa_render_samples = 48
    except Exception:
        pass
    for attr, val in (("use_gtao", True), ("gtao_distance", 0.4), ("use_shadows", True)):
        try:
            setattr(SCN.eevee, attr, val)
        except Exception:
            pass
    try:
        SCN.view_settings.view_transform = "AgX"
        SCN.view_settings.look = "AgX - Punchy"
    except Exception:
        try:
            SCN.view_settings.view_transform = "Standard"
        except Exception:
            pass
    SCN.view_settings.exposure = 0.15
    w = bpy.data.worlds.new(name + "_world")
    try:
        w.use_nodes = True
    except Exception:
        pass
    bg = w.node_tree.nodes.get("Background")
    if bg:
        bg.inputs[0].default_value = (0.62, 0.66, 0.74, 1)
        bg.inputs[1].default_value = 0.55
    SCN.world = w
    return SCN

def link(ob, parent=None):
    SCN.collection.objects.link(ob)
    if parent is not None:
        ob.parent = parent
    return ob

def empty(name, loc=(0, 0, 0), parent=None):
    e = bpy.data.objects.new(name, None)
    e.location = loc
    return link(e, parent)

# ── 재질 ───────────────────────────────────────────
def hex_lin(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c]

def _set(b, names, val):
    for n in names:
        if n in b.inputs:
            try:
                b.inputs[n].default_value = val
                return
            except Exception:
                pass

_MATS = {}

def mat(name, color, rough=0.55, metal=0.0, coat=0.0, sss=0.0, emit=0.0, spec=0.5):
    key = (name, color, rough, metal, coat, sss, emit)
    if key in _MATS:
        return _MATS[key]
    m = bpy.data.materials.new(name)
    try:
        m.use_nodes = True
    except Exception:
        pass
    b = m.node_tree.nodes.get("Principled BSDF")
    col = hex_lin(color) + [1.0]
    _set(b, ["Base Color"], col)
    _set(b, ["Roughness"], rough)
    _set(b, ["Metallic"], metal)
    _set(b, ["Coat Weight", "Clearcoat"], coat)
    _set(b, ["Specular IOR Level", "Specular"], spec)
    if sss > 0:
        _set(b, ["Subsurface Weight", "Subsurface"], sss)
        _set(b, ["Subsurface Radius"], (0.6, 0.3, 0.2))
        _set(b, ["Subsurface Scale"], 0.05)
    if emit > 0:
        _set(b, ["Emission Color", "Emission"], col)
        _set(b, ["Emission Strength"], emit)
    _MATS[key] = m
    return m

def stripe_mat(name, base, stripe, scale=5.0, axis="Z", rough=0.6):
    """줄무늬(태비) 털 재질"""
    m = bpy.data.materials.new(name)
    try:
        m.use_nodes = True
    except Exception:
        pass
    nt = m.node_tree
    b = nt.nodes.get("Principled BSDF")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    wave = nt.nodes.new("ShaderNodeTexWave")
    wave.wave_type = "BANDS"
    try:
        wave.bands_direction = axis
    except Exception:
        pass
    wave.inputs["Scale"].default_value = scale
    wave.inputs["Distortion"].default_value = 3.0
    if "Detail" in wave.inputs:
        wave.inputs["Detail"].default_value = 1.5
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.55
    ramp.color_ramp.elements[0].color = hex_lin(base) + [1]
    ramp.color_ramp.elements[1].position = 0.7
    ramp.color_ramp.elements[1].color = hex_lin(stripe) + [1]
    nt.links.new(tc.outputs["Object"], wave.inputs["Vector"])
    nt.links.new(wave.outputs["Fac"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], b.inputs["Base Color"])
    _set(b, ["Roughness"], rough)
    return m

def fur_mat(name, color, stripe=None, stripe_scale=2.2, rough=0.62):
    """부드러운 털 질감(노이즈 범프) + 선택적 줄무늬"""
    m = stripe_mat(name, color, stripe, stripe_scale, "Z", rough) if stripe else mat(name + "_b", color, rough, sss=0.04)
    if not stripe:
        m = m.copy()
        m.name = name
    nt = m.node_tree
    b = nt.nodes.get("Principled BSDF")
    try:
        noise = nt.nodes.new("ShaderNodeTexNoise")
        noise.inputs["Scale"].default_value = 140.0
        if "Detail" in noise.inputs:
            noise.inputs["Detail"].default_value = 4.0
        bump = nt.nodes.new("ShaderNodeBump")
        bump.inputs["Strength"].default_value = 0.12
        bump.inputs["Distance"].default_value = 0.02
        nt.links.new(noise.outputs["Fac"], bump.inputs["Height"])
        nt.links.new(bump.outputs["Normal"], b.inputs["Normal"])
        _set(b, ["Sheen Weight", "Sheen"], 0.6)
        _set(b, ["Sheen Roughness"], 0.4)
    except Exception as ex:
        log("fur bump fail", ex)
    return m

def set_mat(ob, m):
    if ob.data is None:
        return ob
    ob.data.materials.clear()
    ob.data.materials.append(m)
    return ob

# ── 메시 ───────────────────────────────────────────
def _finish(name, bm, m=None, smooth=True, sub=0, parent=None, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    if smooth:
        try:
            me.shade_smooth()
        except Exception:
            for p in me.polygons:
                p.use_smooth = True
    ob = bpy.data.objects.new(name, me)
    link(ob, parent)
    ob.location = loc
    ob.rotation_euler = rot
    ob.scale = scale
    if sub:
        md = ob.modifiers.new("Sub", "SUBSURF")
        md.levels = sub
        md.render_levels = sub
    if m:
        set_mat(ob, m)
    return ob

def sphere(name, r=1.0, m=None, loc=(0, 0, 0), scale=(1, 1, 1), rot=(0, 0, 0), parent=None, seg=40, ring=24, cut=None):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=ring, radius=r)
    if cut is not None:
        # cut: z 아래를 잘라 반구 (예: 헬멧)
        geom = [v for v in bm.verts if v.co.z < cut * r - 1e-4]
        bmesh.ops.delete(bm, geom=geom, context="VERTS")
    return _finish(name, bm, m, True, 0, parent, loc, rot, scale)

def box(name, size=(1, 1, 1), m=None, loc=(0, 0, 0), rot=(0, 0, 0), parent=None, bevel=0.0, sub=0, segs=3):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
    ob = _finish(name, bm, m, bevel > 0 or sub > 0, 0, parent, loc, rot)
    if bevel > 0:
        md = ob.modifiers.new("Bevel", "BEVEL")
        md.width = bevel
        md.segments = segs
        try:
            md.harden_normals = False
        except Exception:
            pass
    if sub:
        md2 = ob.modifiers.new("Sub", "SUBSURF")
        md2.levels = sub
        md2.render_levels = sub
    return ob

def cyl(name, r=0.5, depth=1.0, m=None, loc=(0, 0, 0), rot=(0, 0, 0), parent=None, r2=None, seg=32, bevel=0.0, smooth=True):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg, radius1=r, radius2=r if r2 is None else r2, depth=depth)
    ob = _finish(name, bm, m, smooth, 0, parent, loc, rot)
    if bevel > 0:
        md = ob.modifiers.new("Bevel", "BEVEL")
        md.width = bevel
        md.segments = 3
        md.limit_method = "ANGLE"
    return ob

def cone(name, r=0.5, depth=1.0, m=None, loc=(0, 0, 0), rot=(0, 0, 0), parent=None, seg=32, r2=0.0):
    return cyl(name, r, depth, m, loc, rot, parent, r2=r2, seg=seg)

def torus(name, R=1.0, r=0.2, m=None, loc=(0, 0, 0), rot=(0, 0, 0), parent=None, seg=48, rseg=16, arc=1.0, scale=(1, 1, 1)):
    bm = bmesh.new()
    rings = []
    n = seg if arc >= 1.0 else seg + 1
    for i in range(n):
        a = 2 * math.pi * arc * i / seg
        ring = []
        for j in range(rseg):
            b = 2 * math.pi * j / rseg
            x = (R + r * math.cos(b)) * math.cos(a)
            y = (R + r * math.cos(b)) * math.sin(a)
            z = r * math.sin(b)
            ring.append(bm.verts.new((x, y, z)))
        rings.append(ring)
    for i in range(len(rings) - (0 if arc >= 1.0 else 1)):
        r1 = rings[i]
        r2_ = rings[(i + 1) % len(rings)]
        for j in range(rseg):
            bm.faces.new((r1[j], r1[(j + 1) % rseg], r2_[(j + 1) % rseg], r2_[j]))
    if arc < 1.0:
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])
    bm.normal_update()
    return _finish(name, bm, m, True, 0, parent, loc, rot, scale)

def tube(name, pts, radius=0.03, m=None, parent=None, res=6, smooth_curve=True):
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = radius
    cu.bevel_resolution = res
    try:
        cu.use_fill_caps = True
    except Exception:
        pass
    if smooth_curve:
        sp = cu.splines.new("NURBS")
        sp.points.add(len(pts) - 1)
        for i, p in enumerate(pts):
            sp.points[i].co = (p[0], p[1], p[2], 1)
        sp.use_endpoint_u = True
        sp.order_u = min(4, len(pts))
    else:
        sp = cu.splines.new("POLY")
        sp.points.add(len(pts) - 1)
        for i, p in enumerate(pts):
            sp.points[i].co = (p[0], p[1], p[2], 1)
    ob = bpy.data.objects.new(name, cu)
    link(ob, parent)
    if m:
        cu.materials.append(m)
    return ob

def face_on(ob, center, direction, dist):
    """center에서 direction 방향 표면에 ob를 붙이고 -Y축이 바깥을 보게 회전"""
    d = Vector(direction).normalized()
    ob.location = Vector(center) + d * dist
    q = (-d).to_track_quat("Y", "Z")
    ob.rotation_mode = "QUATERNION"
    ob.rotation_quaternion = q
    return ob

# ── 조명·카메라 ────────────────────────────────────
def three_point(target=(0, 0, 1), strength=1.0):
    def area(name, loc, energy, size, color=(1, 1, 1)):
        ld = bpy.data.lights.new(name, "AREA")
        ld.energy = energy * strength
        ld.size = size
        ld.color = color
        ob = bpy.data.objects.new(name, ld)
        link(ob)
        ob.location = loc
        dirv = Vector(target) - Vector(loc)
        ob.rotation_mode = "QUATERNION"
        ob.rotation_quaternion = dirv.to_track_quat("-Z", "Y")
        return ob
    area("Key", (-4, -6, 7), 900, 5, (1.0, 0.96, 0.9))
    area("Fill", (6, -5, 3), 350, 6, (0.85, 0.9, 1.0))
    area("Rim", (2, 6, 5), 700, 4, (1.0, 0.95, 0.9))
    area("Top", (0, 0, 9), 250, 8)

def ortho_cam(name="Cam", target=(0, 0, 1), elev=22.0, azim=0.0, scale=3.0, res=(320, 320)):
    cd = bpy.data.cameras.new(name)
    cd.type = "ORTHO"
    cd.ortho_scale = scale
    cd.clip_start = 0.1
    cd.clip_end = 100
    ob = bpy.data.objects.new(name, cd)
    link(ob)
    e = math.radians(elev)
    a = math.radians(azim)
    dirv = Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)))
    ob.location = Vector(target) + dirv * 30
    ob.rotation_mode = "QUATERNION"
    ob.rotation_quaternion = (-dirv).to_track_quat("-Z", "Y")
    SCN.camera = ob
    SCN.render.resolution_x = res[0]
    SCN.render.resolution_y = res[1]
    return ob

def project(cam, world_pt):
    from bpy_extras.object_utils import world_to_camera_view
    bpy.context.view_layer.update()
    co = world_to_camera_view(SCN, cam, Vector(world_pt))
    return [co.x * SCN.render.resolution_x, (1.0 - co.y) * SCN.render.resolution_y]

def fit_cam(cam, objs, margin=1.12, square=True, px_per_unit=None):
    """카메라를 오브젝트들에 맞춘다 (직교)"""
    bpy.context.view_layer.update()
    inv = cam.matrix_world.inverted()
    xs, ys = [], []
    for ob in objs:
        if ob.type not in ("MESH", "CURVE"):
            continue
        for c in ob.bound_box:
            p = inv @ (ob.matrix_world @ Vector(c))
            xs.append(p.x)
            ys.append(p.y)
    if not xs:
        return
    cx = (min(xs) + max(xs)) / 2
    cy = (min(ys) + max(ys)) / 2
    w = (max(xs) - min(xs)) * margin
    h = (max(ys) - min(ys)) * margin
    shift = cam.matrix_world.to_3x3() @ Vector((cx, cy, 0))
    cam.location = cam.location + shift
    if px_per_unit:
        rx = max(8, int(math.ceil(w * px_per_unit)))
        ry = max(8, int(math.ceil(h * px_per_unit)))
        SCN.render.resolution_x = rx
        SCN.render.resolution_y = ry
        cam.data.ortho_scale = max(rx, ry) / px_per_unit
    else:
        cam.data.ortho_scale = max(w, h)
        if square:
            pass

def render(path):
    SCN.render.filepath = path
    bpy.ops.render.render(write_still=True, scene=SCN.name)

def save_source(name, objs):
    """에셋 원본을 .blend로 저장 (사용자가 직접 편집 가능)"""
    try:
        p = os.path.join(SRC, name + ".blend")
        data = set()
        for ob in objs:
            data.add(ob)
        bpy.data.libraries.write(p, data, fake_user=True)
    except Exception as ex:
        log("save_source fail", name, ex)

def all_children(ob):
    out = [ob]
    for c in ob.children:
        out += all_children(c)
    return out
