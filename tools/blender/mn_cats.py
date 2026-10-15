# 멍냥서바이벌 — Meshy AI 고양이 적 3종 가공 (줄이기·꼬리 다듬기·뼈대·애니메이션·GLB 내보내기)
# 블렌더에서: exec(open(r"...\tools\blender\mn_cats.py", encoding="utf-8").read())
import bpy, bmesh, math, os
from mathutils import Vector

PROJ = os.path.expanduser(r"~\Documents\멍냥서바이벌")
SRC = os.path.join(PROJ, "_patch", "catsrc")
PREV = os.path.join(PROJ, "_patch", "catprev")
KINDS = {"white": "cat", "black": "bulldog", "tabby": "hyena"}   # Meshy 파일 → 게임 적 종류

def scene_for(kind):
    nm = "CAT_" + kind
    sc = bpy.data.scenes.get(nm) or bpy.data.scenes.new(nm)
    bpy.context.window.scene = sc
    return sc

def clear(sc):
    for o in list(sc.objects):
        bpy.data.objects.remove(o, do_unlink=True)

def load(kind):
    sc = scene_for(kind)
    clear(sc)
    bpy.ops.import_scene.gltf(filepath=os.path.join(SRC, kind + ".glb"))
    ob = [o for o in sc.objects if o.type == "MESH"][0]
    ob.name = "cat_" + kind
    return sc, ob

def world_bbox(ob):
    ws = [ob.matrix_world @ v.co for v in ob.data.vertices]
    mn = Vector((min(v.x for v in ws), min(v.y for v in ws), min(v.z for v in ws)))
    mx = Vector((max(v.x for v in ws), max(v.y for v in ws), max(v.z for v in ws)))
    return mn, mx

def _cam(sc):
    cam = sc.objects.get("PV_cam")
    if not cam:
        cam = bpy.data.objects.new("PV_cam", bpy.data.cameras.new("PV_cam"))
        sc.collection.objects.link(cam)
    for nm, rot, en in [("PV_key", (50, 0, 30), 3.0), ("PV_fill", (60, 0, -140), 1.2)]:
        l = next((o for o in sc.objects if o.name.startswith(nm)), None)
        if not l:
            l = bpy.data.objects.new(nm, bpy.data.lights.new(nm, "SUN"))
            sc.collection.objects.link(l)
        l.rotation_euler = [math.radians(v) for v in rot]
        l.data.energy = en
    return cam

def shot(sc, name, azim, elev=12.0, target=(0, 0, 0), dist=6.0, ortho=0.0, lens=50, res=400):
    """azim 0 = 정면(-Y 쪽에서 봄), 90 = 오른쪽(+X)에서 봄, 180 = 뒤"""
    cam = _cam(sc)
    cam.data.type = "ORTHO" if ortho > 0 else "PERSP"
    cam.data.ortho_scale = ortho if ortho > 0 else 2.0
    cam.data.lens = lens
    e, a = math.radians(elev), math.radians(azim)
    d = Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)))
    cam.location = Vector(target) + d * dist
    cam.rotation_mode = "QUATERNION"
    cam.rotation_quaternion = (-d).to_track_quat("-Z", "Y")
    sc.camera = cam
    eng = [x.identifier for x in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    sc.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in eng else "BLENDER_EEVEE"
    sc.render.resolution_x = sc.render.resolution_y = res
    if not sc.world:
        sc.world = bpy.data.worlds.get("pvw") or bpy.data.worlds.new("pvw")
    sc.world.color = (0.25, 0.25, 0.28)
    os.makedirs(PREV, exist_ok=True)
    sc.render.filepath = os.path.join(PREV, name + ".png")
    bpy.ops.render.render(write_still=True, scene=sc.name)

def decimate(ob, target=26000):
    n = len(ob.data.polygons)
    if n <= target:
        return
    m = ob.modifiers.new("dec", "DECIMATE")
    m.decimate_type = "COLLAPSE"
    m.ratio = target / n
    m.use_collapse_triangulate = True
    bpy.context.view_layer.objects.active = ob
    with bpy.context.temp_override(object=ob, active_object=ob):
        bpy.ops.object.modifier_apply(modifier=m.name)

def islands(ob):
    """연결된 덩어리별 (꼭짓점 수, bbox) — 무기·장식 분리 확인용"""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.verts.ensure_lookup_table()
    seen = set()
    out = []
    for v in bm.verts:
        if v.index in seen:
            continue
        stack = [v]
        seen.add(v.index)
        ids = []
        while stack:
            a = stack.pop()
            ids.append(a.index)
            for e in a.link_edges:
                b = e.other_vert(a)
                if b.index not in seen:
                    seen.add(b.index)
                    stack.append(b)
        cs = [bm.verts[i].co for i in ids]
        mn = Vector((min(c.x for c in cs), min(c.y for c in cs), min(c.z for c in cs)))
        mx = Vector((max(c.x for c in cs), max(c.y for c in cs), max(c.z for c in cs)))
        out.append((len(ids), mn, mx, ids))
    bm.free()
    out.sort(key=lambda t: -t[0])
    return out

# ── 종류별 설정 (원본 좌표: 정면 = -Y, 위 = +Z) ──
# front/hind: 앞·뒷발 바닥 위치 (x, y) / neck: 머리 경계 높이(앞쪽) / tail: 꼬리 시작 y / cut_tail: 꼬리를 잘라 짧게
CFG = {
    "white": dict(front=[(-0.2, -0.52), (0.2, -0.52)], hind=[(-0.36, 0.02), (0.36, 0.02)], neck=-0.27,
                  tail=0.40, cut_tail=True, gun="w_sniper"),
    "black": dict(front=[(-0.16, -0.30), (0.19, -0.39)], hind=[(-0.2, 0.22), (0.2, 0.22)], neck=-0.30,
                  tail=0.42, cut_tail=False, gun=None),
    "tabby": dict(front=[(-0.22, -0.11), (0.16, -0.40)], hind=[(-0.16, 0.32), (0.18, 0.32)], neck=-0.32,
                  tail=0.42, cut_tail=False, gun=None),
}

def smooth(a, b, x):
    if b == a:
        return 1.0 if x >= b else 0.0
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)

def neck_z(c, y):
    """이 y 위치에서 머리가 시작되는 높이 (앞=턱, 뒤로 갈수록 올라감)"""
    return c["neck"] + 0.25 * max(0.0, y + 0.55)

def cut_tail(ob, c):
    """꼬리를 밑동만 남기고 잘라 짧게 (막대사탕 같은 꼬리 제거)"""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    zmin = min(v.co.z for v in bm.verts)
    kill = [v for v in bm.verts if v.co.y > c["tail"] + 0.07 and v.co.z > zmin + 0.12]
    bmesh.ops.delete(bm, geom=kill, context="VERTS")
    # 잘린 구멍 메우기
    edges = [e for e in bm.edges if e.is_boundary and min(v.co.y for v in e.verts) > c["tail"] - 0.05]
    if edges:
        bmesh.ops.holes_fill(bm, edges=edges, sides=0)
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.update()
    return len(kill)

GUN_POSE = {"white": dict(loc=(-0.05, -0.38, -0.62), scale=0.8)}

def add_gun(sc, ob, kind):
    """총 모델(게임 무기 GLB)을 턱 아래에 붙여 고양이 몸과 합침 → 가슴 뼈를 따라 움직임"""
    c = CFG[kind]
    if not c.get("gun"):
        return 0
    before = set(sc.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(PROJ, "assets", "models", c["gun"] + ".glb"))
    new = [o for o in sc.objects if o not in before]
    root = [o for o in new if o.parent is None][0]
    gp = GUN_POSE[kind]
    root.location = gp["loc"]
    root.scale = (gp["scale"],) * 3
    bpy.context.view_layer.update()
    meshes = [o for o in new if o.type == "MESH"]
    others = [o for o in new if o.type != "MESH"]
    n0 = len(ob.data.vertices)
    for m in meshes:
        m.data = m.data.copy()
        m.data.transform(m.matrix_world)
        m.parent = None
        m.matrix_world.identity()
    for o in sc.objects:
        o.select_set(False)
    for o in [ob] + meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = ob
    with bpy.context.temp_override(active_object=ob, selected_editable_objects=[ob] + meshes, selected_objects=[ob] + meshes, object=ob):
        bpy.ops.object.join()
    for o in others:
        bpy.data.objects.remove(o, do_unlink=True)
    vg = ob.vertex_groups.get("gun") or ob.vertex_groups.new(name="gun")
    vg.add(list(range(n0, len(ob.data.vertices))), 1.0, "REPLACE")
    return len(ob.data.vertices) - n0

BONES = ["root", "hips", "chest", "head", "front_l", "front_r", "hind_l", "hind_r", "tail1", "tail2"]

def weights(ob, kind):
    """부위별 규칙으로 뼈 가중치 (원본 좌표 기준)"""
    c = CFG[kind]
    vs = ob.data.vertices
    zmin = min(v.co.z for v in vs)
    for b in BONES[1:]:
        if b not in ob.vertex_groups:
            ob.vertex_groups.new(name=b)
    gun = ob.vertex_groups.get("gun")
    gun_ids = set()
    if gun:
        for v in vs:
            for g in v.groups:
                if g.group == gun.index and g.weight > 0.5:
                    gun_ids.add(v.index)
    G = {b: ob.vertex_groups[b] for b in BONES[1:]}
    for v in vs:
        x, y, z = v.co
        zr = z - zmin
        w = {}
        if v.index in gun_ids:
            w["chest"] = 1.0
        else:
            # 머리
            hd = smooth(-0.05, 0.05, z - neck_z(c, y))
            # 꼬리
            tl = 0.0 if c["cut_tail"] else smooth(c["tail"] - 0.06, c["tail"] + 0.06, y) * smooth(0.12, 0.2, zr)
            t2 = smooth(0.0, 0.25, ((y - c["tail"]) ** 2 + max(0.0, zr - 0.35) ** 2) ** 0.5 - 0.2) if tl > 0 else 0.0
            # 다리 (발 위치 근처 + 낮은 곳)
            leg = {}
            for nm, (px, py), r in (("front_l", c["front"][0], 0.13), ("front_r", c["front"][1], 0.13),
                                    ("hind_l", c["hind"][0], 0.15), ("hind_r", c["hind"][1], 0.15)):
                d = ((x - px) ** 2 + (y - py) ** 2) ** 0.5
                lw = (1.0 - smooth(r * 0.55, r, d)) * (1.0 - smooth(0.12, 0.26, zr))
                if lw > 0.0:
                    leg[nm] = lw
            rest = 1.0
            if hd > 0:
                w["head"] = hd
                rest -= hd
            if tl > 0 and rest > 0:
                a = tl * rest
                w["tail1"] = a * (1.0 - t2)
                w["tail2"] = a * t2
                rest -= a
            ls = sum(leg.values())
            if ls > 0 and rest > 0:
                k = min(1.0, ls) / ls * rest
                for nm, lw in leg.items():
                    w[nm] = lw * k
                rest -= min(1.0, ls) * rest
            if rest > 0:
                ch = 1.0 - smooth(-0.32, 0.02, y)
                w["chest"] = w.get("chest", 0.0) + rest * ch
                w["hips"] = w.get("hips", 0.0) + rest * (1.0 - ch)
        for b, val in w.items():
            if val > 0.001:
                G[b].add([v.index], val, "REPLACE")
    return zmin

def normalize(ob, kind):
    """키 1.0, 발바닥 z=0, 앞·뒷발 가운데가 원점 → 변환값 반환"""
    c = CFG[kind]
    vs = ob.data.vertices
    zmin = min(v.co.z for v in vs)
    zmax = max(v.co.z for v in vs)
    s = 1.0 / (zmax - zmin)
    fy = sum(p[1] for p in c["front"]) / 2.0
    hy = sum(p[1] for p in c["hind"]) / 2.0
    cy = (fy + hy) / 2.0
    def N(x, y, z):
        return Vector((x * s, (y - cy) * s, (z - zmin) * s))
    from mathutils import Matrix
    M = Matrix.Scale(s, 4) @ Matrix.Translation((0.0, -cy, -zmin))
    ob.data.transform(M)
    ob.data.update()
    return N, zmin, s

def build_armature(sc, ob, kind, N, zmin):
    c = CFG[kind]
    ad = bpy.data.armatures.new("rig_" + kind)
    arm = bpy.data.objects.new("rig_" + kind, ad)
    sc.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    for o in sc.objects:
        o.select_set(False)
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    eb = ad.edit_bones
    def bone(nm, h, t, parent=None):
        b = eb.new(nm)
        b.head = h
        b.tail = t
        b.roll = 0.0
        if parent:
            b.parent = eb[parent]
        return b
    cy = 0.0
    fy = sum(p[1] for p in c["front"]) / 2.0
    hy = sum(p[1] for p in c["hind"]) / 2.0
    bone("root", N(0, (fy + hy) / 2, zmin), N(0, (fy + hy) / 2, zmin + 0.2))
    bone("hips", N(0, hy, zmin + 0.15), N(0, hy, zmin + 0.45), "root")
    bone("chest", N(0, -0.2, zmin + 0.15), N(0, -0.2, zmin + 0.45), "hips")
    nz = neck_z(c, -0.3)
    bone("head", N(0, -0.3, nz), N(0, -0.3, nz + 0.5), "chest")
    for nm, (px, py), par in (("front_l", c["front"][0], "chest"), ("front_r", c["front"][1], "chest"),
                              ("hind_l", c["hind"][0], "hips"), ("hind_r", c["hind"][1], "hips")):
        bone(nm, N(px, py, zmin + 0.28), N(px, py, zmin), par)
    tb = zmin + 0.32
    ty = c["tail"]
    bone("tail1", N(0, ty, tb), N(0, ty + 0.15, tb + 0.25), "hips")
    bone("tail2", N(0, ty + 0.15, tb + 0.25), N(0, ty + 0.35, tb + 0.55), "tail1")
    eb["tail2"].use_connect = True
    bpy.ops.object.mode_set(mode="OBJECT")
    ob.parent = arm
    md = ob.modifiers.new("Armature", "ARMATURE")
    md.object = arm
    if "gun" in ob.vertex_groups:
        ob.vertex_groups.remove(ob.vertex_groups["gun"])
    return arm

FPS = 24

def _key(arm, frames, fn):
    """fn(bone, phase) → dict(rot=(x,y,z), loc=(x,y,z)) — 프레임마다 키"""
    for f in range(frames + 1):
        p = (f % frames) / frames * math.tau
        for pb in arm.pose.bones:
            pb.rotation_mode = "XYZ"
            r = fn(pb.name, p) or {}
            pb.rotation_euler = r.get("rot", (0.0, 0.0, 0.0))
            pb.location = r.get("loc", (0.0, 0.0, 0.0))
            pb.keyframe_insert("rotation_euler", frame=f)
            pb.keyframe_insert("location", frame=f)

def anim_idle(b, p):
    if b == "hips":
        return dict(loc=(0, 0.006 * math.sin(p), 0))
    if b == "chest":
        return dict(rot=(0.02 * math.sin(p), 0, 0))
    if b == "head":
        return dict(rot=(0.03 * math.sin(p + 0.6), 0.1 * math.sin(p), 0.04 * math.sin(2 * p)))
    if b == "tail1":
        return dict(rot=(0.05 * math.sin(2 * p), 0, 0.28 * math.sin(p)))
    if b == "tail2":
        return dict(rot=(0, 0, 0.34 * math.sin(p - 1.0)))

def _leg(p, ph, amp, lift):
    t = p + ph
    return dict(rot=(amp * math.cos(t), 0, 0), loc=(0, -lift * max(0.0, math.sin(t)), 0))

def anim_walk(b, p):
    # 대각선 다리가 같이 (총총걸음): 앞왼·뒤오 / 앞오·뒤왼
    if b == "front_l":
        return _leg(p, 0.0, 0.42, 0.05)
    if b == "hind_r":
        return _leg(p, 0.0, 0.36, 0.04)
    if b == "front_r":
        return _leg(p, math.pi, 0.42, 0.05)
    if b == "hind_l":
        return _leg(p, math.pi, 0.36, 0.04)
    if b == "hips":
        return dict(rot=(0, 0, 0.05 * math.sin(p)), loc=(0, 0.014 * math.cos(2 * p), 0))
    if b == "chest":
        return dict(rot=(0.03 * math.cos(2 * p), 0, -0.03 * math.sin(p)))
    if b == "head":
        return dict(rot=(-0.04 * math.cos(2 * p), 0.05 * math.sin(p), -0.04 * math.sin(p)))
    if b == "tail1":
        return dict(rot=(0.06 * math.cos(2 * p), 0, 0.3 * math.sin(p)))
    if b == "tail2":
        return dict(rot=(0, 0, 0.36 * math.sin(p - 0.9)))

def anim_run(b, p):
    # 깡충깡충 뛰기: 앞발 둘이 함께, 뒷발 둘이 함께
    if b == "front_l":
        return _leg(p, 0.0, 0.7, 0.09)
    if b == "front_r":
        return _leg(p, 0.35, 0.7, 0.09)
    if b == "hind_l":
        return _leg(p, math.pi, 0.62, 0.08)
    if b == "hind_r":
        return _leg(p, math.pi + 0.35, 0.62, 0.08)
    if b == "hips":
        return dict(rot=(0.12 * math.sin(p), 0, 0), loc=(0, 0.04 * abs(math.sin(p)), 0))
    if b == "chest":
        return dict(rot=(0.06 * math.sin(p + 0.5), 0, 0))
    if b == "head":
        return dict(rot=(-0.12 * math.sin(p + 0.3), 0, 0))
    if b == "tail1":
        return dict(rot=(0.25 * math.sin(p), 0, 0.12 * math.sin(p)))
    if b == "tail2":
        return dict(rot=(0.2 * math.sin(p - 0.8), 0, 0.15 * math.sin(p - 0.8)))

def make_anims(arm):
    arm.animation_data_create()
    ad = arm.animation_data
    for tr in list(ad.nla_tracks):
        ad.nla_tracks.remove(tr)
    for nm, frames, fn in (("idle", 48, anim_idle), ("walk", 16, anim_walk), ("run", 16, anim_run)):
        old = bpy.data.actions.get(nm + "_" + arm.name)
        if old:
            bpy.data.actions.remove(old)
        act = bpy.data.actions.new(nm + "_" + arm.name)
        ad.action = act
        _key(arm, frames, fn)
        ad.action = None
        tr = ad.nla_tracks.new()
        tr.name = nm
        st = tr.strips.new(nm, 0, act)
        st.name = nm
        tr.mute = False
    for pb in arm.pose.bones:
        pb.rotation_euler = (0, 0, 0)
        pb.location = (0, 0, 0)

def shrink_textures(ob, size=1024):
    for m in ob.data.materials:
        if not m or not m.node_tree:
            continue
        for n in m.node_tree.nodes:
            if n.type == "TEX_IMAGE" and n.image and n.image.size[0] > size:
                n.image.scale(size, size)

def export(sc, arm, ob, kind):
    out = os.path.join(PROJ, "assets", "models", "enemy_%s.glb" % KINDS[kind])
    for o in sc.objects:
        o.select_set(False)
    arm.select_set(True)
    ob.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True, export_yup=True,
                              export_animations=True, export_animation_mode="NLA_TRACKS",
                              export_image_format="JPEG", export_jpeg_quality=86,
                              export_cameras=False, export_lights=False, use_active_scene=True)
    return out, os.path.getsize(out)

def process(kind, do_export=True):
    sc, ob = load(kind)
    decimate(ob, 26000)
    c = CFG[kind]
    if c["cut_tail"]:
        cut_tail(ob, c)
    add_gun(sc, ob, kind)
    zmin = weights(ob, kind)
    N, zmin, s = normalize(ob, kind)
    arm = build_armature(sc, ob, kind, N, zmin)
    make_anims(arm)
    shrink_textures(ob)
    sc.render.fps = FPS
    res = export(sc, arm, ob, kind) if do_export else None
    return sc, ob, arm, res

def pose_shot(sc, arm, name, action, frame, azim=50, elev=30):
    ad = arm.animation_data
    for tr in ad.nla_tracks:
        tr.mute = True
    act = bpy.data.actions.get(action + "_" + arm.name)
    ad.action = act
    sc.frame_set(frame)
    shot(sc, name, azim, elev=elev, target=(0, 0, 0.45), dist=4.0, res=360)
    ad.action = None
    for tr in ad.nla_tracks:
        tr.mute = False

def reanim(kind):
    """이미 만든 장면에서 애니메이션만 다시 만들고 내보내기"""
    sc = bpy.data.scenes["CAT_" + kind]
    bpy.context.window.scene = sc
    arm = [o for o in sc.objects if o.type == "ARMATURE"][0]
    ob = [o for o in sc.objects if o.type == "MESH"][0]
    make_anims(arm)
    return export(sc, arm, ob, kind)

# ── 무기 (Meshy) ──
WSRC = os.path.join(os.path.expanduser("~"), "Documents", "멍냥서바이벌_에셋", "1_Meshy_원본", "weapons")

def weapon_load(wid):
    sc = bpy.data.scenes.get("WPN") or bpy.data.scenes.new("WPN")
    bpy.context.window.scene = sc
    clear(sc)
    bpy.ops.import_scene.gltf(filepath=os.path.join(WSRC, wid + ".glb"))
    ms = [o for o in sc.objects if o.type == "MESH"]
    return sc, ms

def weapon_info(wid):
    sc, ms = weapon_load(wid)
    out = []
    for o in ms:
        mn, mx = world_bbox(o)
        out.append((o.name, len(o.data.polygons), [round(v, 3) for v in mn], [round(v, 3) for v in mx]))
    return sc, out

# 무기: (게임 속 길이[타일], 손잡이 위치 = 뒤끝에서 길이 비율)
WSPEC = {
    "pistol": (0.34, 0.22), "revolver": (0.42, 0.2), "machine_pistol": (0.4, 0.3), "derringer": (0.24, 0.25),
    "sawed_off": (0.55, 0.28), "nail_gun": (0.42, 0.35), "smg": (0.6, 0.38), "assault_rifle": (0.82, 0.4),
    "carbine": (0.78, 0.38), "battle_rifle": (0.92, 0.38), "hunting_rifle": (0.95, 0.36), "sniper": (1.05, 0.34),
    "dmr": (0.95, 0.36), "lmg": (0.95, 0.4), "shotgun": (0.85, 0.3), "double_barrel": (0.88, 0.3),
    "auto_shotgun": (0.8, 0.38), "crossbow": (0.7, 0.3), "compound_bow": (0.75, 0.5), "harpoon_gun": (0.85, 0.3),
    "bat": (0.68, 0.12), "knife": (0.32, 0.18), "hammer": (0.42, 0.12), "machete": (0.6, 0.14), "katana": (0.85, 0.12),
    "crowbar": (0.6, 0.15), "fire_axe": (0.8, 0.12), "spear": (1.15, 0.3), "frying_pan": (0.5, 0.15), "sledgehammer": (0.85, 0.12),
}
WOUT = os.path.join(PROJ, "assets", "models", "weapons")
ICON = os.path.join(PROJ, "assets", "sprites", "icons")

def weapon_icon_only(wid):
    sc = bpy.data.scenes.get("WPN") or bpy.data.scenes.new("WPN")
    bpy.context.window.scene = sc
    clear(sc)
    bpy.ops.import_scene.gltf(filepath=os.path.join(WOUT, wid + ".glb"))
    ob = [o for o in sc.objects if o.type == "MESH"][0]
    weapon_icon(sc, ob, wid)

def weapon_process(wid, flip=False, icon=True):
    """길이·방향 맞추기: 앞(총구·날 끝) = -Y, 위 = +Z, 손잡이 = 원점 → GLB + 아이콘"""
    from mathutils import Matrix
    sc, ms = weapon_load(wid)
    if len(ms) > 1:
        for o in sc.objects:
            o.select_set(o in ms)
        bpy.context.view_layer.objects.active = ms[0]
        with bpy.context.temp_override(active_object=ms[0], selected_editable_objects=ms, selected_objects=ms):
            bpy.ops.object.join()
    ob = [o for o in sc.objects if o.type == "MESH"][0]
    ob.data.transform(ob.matrix_world)
    ob.parent = None
    ob.matrix_world = Matrix.Identity(4)
    for o in [o for o in sc.objects if o != ob]:
        bpy.data.objects.remove(o, do_unlink=True)
    mn, mx = world_bbox(ob)
    ext = mx - mn
    # 가장 긴 축을 X로
    if ext.y > ext.x and ext.y >= ext.z:
        ob.data.transform(Matrix.Rotation(math.radians(-90), 4, "Z"))
    elif ext.z > ext.x and ext.z > ext.y:
        ob.data.transform(Matrix.Rotation(math.radians(90), 4, "Y"))
    # 총구가 -X (그림에서 오른쪽을 향함) → -Y 로
    ob.data.transform(Matrix.Rotation(math.radians(90 if not flip else -90), 4, "Z"))
    mn, mx = world_bbox(ob)
    length, gf = WSPEC[wid]
    s = length / max(1e-6, (mx.y - mn.y))
    gy = mx.y - (mx.y - mn.y) * gf            # 뒤끝(+Y)에서 gf 만큼 앞
    gz = (mn.z + mx.z) * 0.5
    ob.data.transform(Matrix.Scale(s, 4) @ Matrix.Translation((-(mn.x + mx.x) * 0.5, -gy, -gz)))
    ob.data.update()
    ob.name = "w_" + wid
    for m in ob.data.materials:
        if m and m.node_tree:
            for n in m.node_tree.nodes:
                if n.type == "TEX_IMAGE" and n.image and n.image.size[0] > 512:
                    n.image.scale(512, 512)
    os.makedirs(WOUT, exist_ok=True)
    for o in sc.objects:
        o.select_set(False)
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    out = os.path.join(WOUT, wid + ".glb")
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True, export_yup=True,
                              export_animations=False, export_image_format="JPEG", export_jpeg_quality=88,
                              export_cameras=False, export_lights=False, use_active_scene=True)
    if icon:
        weapon_icon(sc, ob, wid)
    return out, len(ob.data.polygons)

def weapon_icon(sc, ob, wid, res=(384, 192)):
    mn, mx = world_bbox(ob)
    c = (mn + mx) * 0.5
    cam = _cam(sc)
    cam.data.type = "ORTHO"
    L = max(mx.y - mn.y, (mx.z - mn.z) * 2.0) * 1.08
    cam.data.ortho_scale = L
    cam.location = Vector((c.x - 5.0, c.y, c.z))
    cam.rotation_mode = "XYZ"
    cam.rotation_euler = (math.radians(90), 0, math.radians(-90))
    sc.camera = cam
    eng = [x.identifier for x in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    sc.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in eng else "BLENDER_EEVEE"
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.film_transparent = True
    if not sc.world:
        sc.world = bpy.data.worlds.get("pvw") or bpy.data.worlds.new("pvw")
    sc.world.color = (0.55, 0.55, 0.6)
    k = [o for o in sc.objects if o.name.startswith("PV_key")][0]
    k.rotation_euler = (math.radians(40), 0, math.radians(-110))
    k.data.energy = 3.5
    os.makedirs(ICON, exist_ok=True)
    sc.render.filepath = os.path.join(ICON, "w_" + wid + ".png")
    bpy.ops.render.render(write_still=True, scene=sc.name)
    sc.render.film_transparent = False
