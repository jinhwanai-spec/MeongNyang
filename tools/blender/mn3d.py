# 멍냥서바이벌 3D 에셋 (게임용 GLB)
# 캐릭터는 부위별(머리·몸·팔·다리·꼬리) 오브젝트로 나눠 내보내고, 고도트에서 절차적으로 움직인다.
# 블렌더 좌표: Z 위, 정면 = -Y  (glTF로 내보내면 Y 위, 정면 = +Z)
import bpy, bmesh, math, os
from mathutils import Vector, Matrix
import mn_lib
from mn_lib import *

GAME_ROOT = ROOT
GLB_DIR = os.path.join(ROOT, "assets", "models")
PREV_DIR = os.path.join(ROOT, "assets", "_render", "models")

def M(name, hexcol, rough=0.6, metal=0.0, coat=0.0, emit=0.0):
    return mat(name, hexcol, rough, metal, coat, 0.0, emit)

# ── 부위 합치기 ───────────────────────────────────────
def merge(name, objs, pivot=(0, 0, 0), parent=None):
    """여러 오브젝트(곡선·모디파이어 포함)를 하나의 메시로 굽고, 원점을 pivot에 둔다"""
    bpy.context.view_layer.update()
    deps = bpy.context.evaluated_depsgraph_get()
    bm = bmesh.new()
    mats = []
    for ob in objs:
        ev = ob.evaluated_get(deps)
        try:
            me = ev.to_mesh()
        except Exception:
            continue
        if me is None:
            continue
        me = me.copy()
        me.transform(ob.matrix_world)
        slot_map = []
        for m in (ob.data.materials if hasattr(ob.data, "materials") else []):
            if m not in mats:
                mats.append(m)
            slot_map.append(mats.index(m))
        n0 = len(bm.faces)
        bm.from_mesh(me)
        bm.faces.ensure_lookup_table()
        for i in range(n0, len(bm.faces)):
            f = bm.faces[i]
            f.material_index = slot_map[f.material_index] if f.material_index < len(slot_map) else 0
        bpy.data.meshes.remove(me)
        ev.to_mesh_clear()
    pv = Vector(pivot)
    for v in bm.verts:
        v.co -= pv
    old = bpy.data.objects.get(name)
    if old is not None:
        old.name = name + "_old"
    out = bpy.data.meshes.new(name)
    bm.to_mesh(out)
    bm.free()
    for m in mats:
        out.materials.append(m)
    ob = bpy.data.objects.new(name, out)
    link(ob)
    ob.location = pv
    if parent is not None:
        ob.parent = parent
        ob.location = pv - parent.matrix_world.translation
    for o in objs:
        bpy.data.objects.remove(o, do_unlink=True)
    return ob

def export_glb(root, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    for o in mn_lib.SCN.objects:
        o.select_set(False)
    def sel(o):
        o.select_set(True)
        for c in o.children:
            sel(c)
    sel(root)
    bpy.context.view_layer.objects.active = root
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True, export_animations=False, export_cameras=False, export_lights=False,
                              use_active_scene=True)
    log("GLB", path)

def preview(path, target=(0, 0, 0.6), dist=4.0, elev=35.0, azim=-30.0, res=(512, 512), lens=50):
    cd = bpy.data.cameras.new("PrevCam")
    cd.lens = lens
    cam = bpy.data.objects.new("PrevCam", cd)
    link(cam)
    e, a = math.radians(elev), math.radians(azim)
    d = Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)))
    cam.location = Vector(target) + d * dist
    cam.rotation_mode = "QUATERNION"
    cam.rotation_quaternion = (-d).to_track_quat("-Z", "Y")
    mn_lib.SCN.camera = cam
    mn_lib.SCN.render.resolution_x, mn_lib.SCN.render.resolution_y = res
    three_point(target, 1.0)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    render(path)
    bpy.data.objects.remove(cam, do_unlink=True)

# ── 햄스터 ───────────────────────────────────────────
HAM = {
    "fur": "#E9A15E", "white": "#FFF4E6", "pink": "#F2A0A6", "helmet": "#5F5A40", "helmet_d": "#4A4632",
    "vest": "#B09A66", "vest_d": "#8C7A4E", "strap": "#34332F", "lens": "#1B2029", "frame": "#3A3D44",
    "pack": "#76704C", "nose": "#E77F8A", "metal": "#8E949C",
}

def build_hamster(fur_hex=None):
    new_scene("MN3D_hamster")
    C = dict(HAM)
    if fur_hex:
        C["fur"] = fur_hex
    m = {k: M("ham_" + k, v, 0.65) for k, v in C.items()}
    m["fur"] = M("fur", C["fur"], 0.7)            # 고도트에서 이 재질 색만 바꿔 8종 털색
    m["lens"] = M("ham_lens", C["lens"], 0.08, 0.0, 1.0)
    m["metal"] = M("ham_metal", C["metal"], 0.35, 0.8)
    m["shine"] = M("ham_shine", "#FFFFFF", 0.2, 0.0, 0.0, 3.0)
    root = empty("Hamster")

    # 몸통 (엉덩이 기준)
    P = []
    P.append(sphere("torso", 0.28, m["fur"], (0, 0, 0.40), (1.0, 0.92, 1.0)))
    P.append(sphere("bib", 0.17, m["white"], (0, -0.17, 0.55), (1.15, 0.6, 0.7)))
    P.append(sphere("vest", 0.315, m["vest"], (0, 0, 0.41), (1.04, 0.96, 0.78)))
    for i, x in enumerate((-0.12, 0.0, 0.12)):
        P.append(box("pouch%d" % i, (0.085, 0.06, 0.1), m["vest_d"], (x, -0.285, 0.38), bevel=0.018))
    P.append(torus("belt", 0.27, 0.026, m["strap"], (0, 0, 0.29), scale=(1.06, 0.98, 1)))
    P.append(box("buckle", (0.07, 0.03, 0.05), m["metal"], (0, -0.29, 0.29), bevel=0.008))
    for sx in (-1, 1):
        P.append(tube("strap%d" % sx, [(0.13 * sx, -0.25, 0.55), (0.17 * sx, -0.05, 0.62), (0.15 * sx, 0.2, 0.56)], 0.022, m["strap"]))
    P.append(box("pack", (0.36, 0.17, 0.34), m["pack"], (0, 0.27, 0.45), bevel=0.06))
    P.append(box("pack_pocket", (0.24, 0.05, 0.14), m["vest_d"], (0, 0.37, 0.38), bevel=0.025))
    P.append(cyl("bedroll", 0.06, 0.34, m["helmet_d"], (0, 0.27, 0.65), (0, math.radians(90), 0)))
    P.append(sphere("tail", 0.055, m["fur"], (0, 0.22, 0.2)))
    body = merge("body", P, (0, 0, 0.0), root)

    # 머리 (목 기준)
    neck = (0, -0.02, 0.6)
    H = []
    HZ = 0.89
    H.append(sphere("head", 0.38, m["fur"], (0, -0.01, HZ), (1.12, 1.0, 0.98)))
    # 얼굴 아래: 통통한 볼주머니 + 턱
    for sx in (-1, 1):
        H.append(sphere("cheek%d" % sx, 0.175, m["white"], (0.175 * sx, -0.2, HZ - 0.11), (1.0, 0.85, 0.88)))
        H.append(sphere("blush%d" % sx, 0.048, m["pink"], (0.255 * sx, -0.305, HZ - 0.05), (1.0, 0.35, 0.75)))
        # 귀 (헬멧 옆으로 쏙)
        H.append(sphere("ear%d" % sx, 0.12, m["fur"], (0.36 * sx, 0.02, HZ + 0.25), (1.0, 0.55, 1.08), (0, math.radians(-32 * sx), 0)))
        H.append(sphere("earin%d" % sx, 0.08, m["pink"], (0.365 * sx, -0.035, HZ + 0.25), (1.0, 0.35, 1.0), (0, math.radians(-32 * sx), 0)))
        # 고글 (눈 위)
        H.append(sphere("lens%d" % sx, 0.118, m["lens"], (0.145 * sx, -0.345, HZ + 0.045), (1.0, 0.48, 0.88)))
        H.append(torus("frame%d" % sx, 0.118, 0.021, m["frame"], (0.145 * sx, -0.352, HZ + 0.045), (math.radians(90), 0, 0), scale=(1.0, 0.88, 1)))
        H.append(sphere("shine%d" % sx, 0.026, m["shine"], (0.145 * sx - 0.04, -0.398, HZ + 0.09)))
        H.append(sphere("shine2%d" % sx, 0.012, m["shine"], (0.145 * sx + 0.035, -0.398, HZ + 0.005)))
        # 헤드셋
        H.append(cyl("cup%d" % sx, 0.09, 0.075, m["strap"], (0.415 * sx, 0.0, HZ - 0.02), (0, math.radians(90), 0), bevel=0.012))
    H.append(sphere("chin", 0.12, m["white"], (0, -0.27, HZ - 0.15), (1.1, 0.8, 0.75)))
    H.append(box("bridge", (0.07, 0.03, 0.03), m["frame"], (0, -0.375, HZ + 0.05), bevel=0.01))
    H.append(torus("goggle_strap", 0.39, 0.02, m["strap"], (0, -0.01, HZ + 0.045), scale=(1.1, 0.98, 1)))
    H.append(tube("mic", [(-0.42, -0.04, HZ - 0.06), (-0.36, -0.22, HZ - 0.13), (-0.2, -0.32, HZ - 0.15)], 0.012, m["strap"]))
    H.append(sphere("mic_tip", 0.026, m["strap"], (-0.19, -0.325, HZ - 0.15)))
    H.append(sphere("nose", 0.04, m["nose"], (0, -0.39, HZ - 0.04), (1.25, 0.8, 0.9)))
    H.append(sphere("mouth", 0.017, m["strap"], (0, -0.36, HZ - 0.105), (2.0, 0.6, 0.8)))
    # 헬멧: 머리 위 1/3만 덮는 캡
    H.append(sphere("helmet", 0.40, m["helmet"], (0, 0.0, HZ + 0.12), (1.04, 1.02, 0.74), cut=0.05))
    H.append(torus("brim", 0.40, 0.028, m["helmet_d"], (0, 0.0, HZ + 0.14), scale=(1.04, 1.02, 1)))
    H.append(box("helmet_band", (0.48, 0.05, 0.05), m["helmet_d"], (0, -0.04, HZ + 0.36), bevel=0.02))
    head = merge("head", H, neck, root)

    # 팔 (어깨 기준, 앞으로 총을 든 기본 자세)
    for sx, nm in ((-1, "arm_l"), (1, "arm_r")):
        sh = (0.27 * sx, -0.02, 0.52)
        A = [sphere(nm + "_a", 0.085, m["fur"], (0.27 * sx, -0.13, 0.47), (0.92, 1.55, 0.9)),
             sphere(nm + "_sleeve", 0.092, m["vest"], (0.275 * sx, -0.06, 0.5), (1.0, 0.9, 0.95)),
             sphere(nm + "_paw", 0.068, m["pink"], (0.255 * sx, -0.27, 0.45))]
        arm = merge(nm, A, sh, root)
        if sx == 1:
            g = empty("grip", (0, 0, 0), arm)
            g.location = Vector((0.255, -0.27, 0.45)) - Vector(sh)

    # 다리 (엉덩이 기준)
    for sx, nm in ((-1, "leg_l"), (1, "leg_r")):
        hip = (0.15 * sx, 0.0, 0.2)
        L = [sphere(nm + "_t", 0.115, m["fur"], (0.15 * sx, -0.02, 0.13), (1.0, 1.1, 1.0)),
             sphere(nm + "_f", 0.08, m["pink"], (0.15 * sx, -0.09, 0.045), (1.1, 1.55, 0.6))]
        merge(nm, L, hip, root)
    return root

def make_hamster(preview_only=False):
    root = build_hamster()
    if not preview_only:
        export_glb(root, os.path.join(GLB_DIR, "hamster.glb"))
    preview(os.path.join(PREV_DIR, "hamster_front.png"), (0, 0, 0.62), 3.2, 12, -28)
    preview(os.path.join(PREV_DIR, "hamster_game.png"), (0, 0, 0.5), 4.5, 58, 0)
    return root

# ── 고양이 적 ─────────────────────────────────────────
CATS = {
    # 길냥이 돌격병: 회색 줄무늬, 빨간 두건, 칼
    "hyena": {"fur": "#8C8C92", "white": "#E9E6E2", "stripe": "#55565E", "eye": "#F2C230", "vest": "#5E5A48", "acc": "#B83A35",
              "scale": 1.0, "helmet": False, "bandana": True, "beret": False, "armor": False},
    # 중장갑 흑냥이: 검은 고양이, 철모·방탄판, 망치
    "bulldog": {"fur": "#2B2A30", "white": "#3C3B42", "stripe": "#1E1D22", "eye": "#F5D23A", "vest": "#3D3A33", "acc": "#6B6B70",
                "scale": 1.22, "helmet": True, "bandana": False, "beret": False, "armor": True},
    # 흰냥 저격수: 흰 고양이, 베레모, 저격총
    "cat": {"fur": "#ECEAE6", "white": "#FFFFFF", "stripe": "#C9C4BD", "eye": "#7FC8F0", "vest": "#55603F", "acc": "#3E5A3A",
            "scale": 1.0, "helmet": False, "bandana": False, "beret": True, "armor": False},
}

def build_cat(kind):
    new_scene("MN3D_cat_" + kind)
    C = CATS[kind]
    k = C["scale"]
    m = {n: M("cat_%s_%s" % (kind, n), C[n], 0.7) for n in ("fur", "white", "stripe", "vest", "acc")}
    m["eye"] = M("cat_%s_eye" % kind, C["eye"], 0.25, 0.0, 0.6, 0.6)
    m["pupil"] = M("cat_pupil", "#14141A", 0.3)
    m["pink"] = M("cat_pink", "#E79AA2", 0.6)
    m["strap"] = M("cat_strap", "#2C2B28", 0.7)
    m["metal"] = M("cat_metal", "#7E848C", 0.35, 0.8)
    m["shine"] = M("cat_shine", "#FFFFFF", 0.2, 0.0, 0.0, 3.0)
    root = empty("Cat")
    S = lambda v: tuple(x * k for x in v)
    # 몸통
    P = [sphere("torso", 0.30 * k, m["fur"], S((0, 0, 0.52)), (0.95, 0.85, 1.2)),
         sphere("belly", 0.22 * k, m["white"], S((0, -0.13, 0.5)), (0.95, 0.55, 1.05)),
         sphere("vest", 0.315 * k, m["vest"], S((0, 0, 0.56)), (1.0, 0.9, 0.85))]
    for i, x in enumerate((-0.11, 0.0, 0.11)):
        P.append(box("pouch%d" % i, S((0.09, 0.06, 0.11)), m["acc"] if C["armor"] else m["strap"], S((x, -0.28, 0.52)), bevel=0.02 * k))
    if C["armor"]:
        P.append(box("plate", S((0.42, 0.08, 0.36)), m["acc"], S((0, -0.27, 0.6)), bevel=0.04 * k))
        for sx in (-1, 1):
            P.append(sphere("pauldron%d" % sx, 0.13 * k, m["acc"], S((0.3 * sx, 0, 0.78)), (1.0, 1.0, 0.7)))
    P.append(torus("belt", 0.265 * k, 0.03 * k, m["strap"], S((0, 0, 0.34)), scale=(1.05, 0.95, 1)))
    P.append(tube("tail", [S((0, 0.22, 0.34)), S((0.1, 0.42, 0.42)), S((0.22, 0.5, 0.7)), S((0.18, 0.44, 0.92))], 0.06 * k, m["fur"]))
    P.append(sphere("tail_tip", 0.065 * k, m["stripe"], S((0.18, 0.44, 0.94))))
    merge("body", P, (0, 0, 0), root)
    # 머리
    HZ = 1.02
    H = [sphere("head", 0.36 * k, m["fur"], S((0, -0.02, HZ)), (1.18, 1.0, 0.92)),
         sphere("muzzle", 0.16 * k, m["white"], S((0, -0.27, HZ - 0.1)), (1.25, 0.7, 0.75)),
         sphere("nose", 0.035 * k, m["pink"], S((0, -0.37, HZ - 0.05)), (1.3, 0.8, 0.8))]
    for sx in (-1, 1):
        # 뾰족한 귀
        e = cone("ear%d" % sx, 0.15 * k, 0.3 * k, m["fur"], S((0.24 * sx, 0.0, HZ + 0.3)), (math.radians(-8), math.radians(18 * sx), 0), seg=24)
        H.append(e)
        H.append(cone("earin%d" % sx, 0.09 * k, 0.2 * k, m["pink"], S((0.24 * sx, -0.06, HZ + 0.28)), (math.radians(-8), math.radians(18 * sx), 0), seg=20))
        # 매서운 눈
        H.append(sphere("eye%d" % sx, 0.085 * k, m["eye"], S((0.15 * sx, -0.31, HZ + 0.04)), (1.15, 0.45, 0.8), (0, math.radians(-12 * sx), 0)))
        H.append(sphere("pupil%d" % sx, 0.06 * k, m["pupil"], S((0.15 * sx, -0.345, HZ + 0.04)), (0.38, 0.4, 0.95)))
        H.append(sphere("eshine%d" % sx, 0.018 * k, m["shine"], S((0.15 * sx - 0.03, -0.37, HZ + 0.075))))
        H.append(box("brow%d" % sx, S((0.15, 0.03, 0.035)), m["stripe"], S((0.15 * sx, -0.32, HZ + 0.13)), (0, math.radians(20 * sx), 0), bevel=0.012 * k))
        # 수염
        for j in range(2):
            H.append(tube("whisker%d%d" % (sx, j), [S((0.12 * sx, -0.34, HZ - 0.08 - j * 0.03)), S((0.32 * sx, -0.36, HZ - 0.06 - j * 0.06))], 0.005 * k, m["white"], smooth_curve=False))
        H.append(sphere("cheekfur%d" % sx, 0.13 * k, m["fur"], S((0.3 * sx, -0.08, HZ - 0.12)), (0.8, 0.9, 0.7)))
    # 줄무늬 (이마)
    for i, x in enumerate((-0.07, 0.0, 0.07)):
        H.append(box("stripe%d" % i, S((0.03, 0.06, 0.13)), m["stripe"], S((x, -0.27, HZ + 0.24)), (math.radians(-35), 0, 0), bevel=0.012 * k))
    if C["helmet"]:
        H.append(sphere("helmet", 0.40 * k, m["acc"], S((0, 0, HZ + 0.1)), (1.12, 1.05, 0.75), cut=0.05))
        H.append(torus("hbrim", 0.4 * k, 0.03 * k, m["strap"], S((0, 0, HZ + 0.12)), scale=(1.12, 1.05, 1)))
        H.append(box("visor", S((0.5, 0.05, 0.08)), m["strap"], S((0, -0.36, HZ + 0.15)), bevel=0.02 * k))
    if C["bandana"]:
        H.append(torus("bandana", 0.37 * k, 0.045 * k, m["acc"], S((0, -0.02, HZ + 0.17)), (math.radians(-10), 0, 0), scale=(1.12, 1.0, 1)))
        H.append(tube("knot", [S((0.05, 0.35, HZ + 0.15)), S((0.12, 0.48, HZ + 0.05)), S((0.1, 0.55, HZ - 0.1))], 0.035 * k, m["acc"]))
    if C["beret"]:
        H.append(sphere("beret", 0.3 * k, m["acc"], S((0.08, 0.02, HZ + 0.3)), (1.15, 1.1, 0.42), (0, math.radians(-12), 0)))
        H.append(sphere("badge", 0.035 * k, m["metal"], S((-0.12, -0.25, HZ + 0.31))))
    merge("head", H, S((0, -0.02, 0.8)), root)
    # 팔·다리
    for sx, nm in ((-1, "arm_l"), (1, "arm_r")):
        sh = S((0.29 * sx, -0.02, 0.72))
        A = [sphere(nm + "_a", 0.09 * k, m["fur"], S((0.29 * sx, -0.13, 0.64)), (0.92, 1.6, 0.9)),
             sphere(nm + "_s", 0.1 * k, m["vest"], S((0.295 * sx, -0.05, 0.69)), (1.0, 0.9, 0.95)),
             sphere(nm + "_paw", 0.075 * k, m["white"], S((0.28 * sx, -0.28, 0.61)))]
        arm = merge(nm, A, sh, root)
        if sx == 1:
            g = empty("grip", (0, 0, 0), arm)
            g.location = Vector(S((0.28, -0.28, 0.61))) - Vector(sh)
    for sx, nm in ((-1, "leg_l"), (1, "leg_r")):
        hip = S((0.15 * sx, 0.0, 0.3))
        L = [sphere(nm + "_t", 0.12 * k, m["fur"], S((0.15 * sx, -0.01, 0.2)), (1.0, 1.0, 1.35)),
             sphere(nm + "_f", 0.09 * k, m["white"], S((0.15 * sx, -0.08, 0.05)), (1.05, 1.5, 0.6))]
        merge(nm, L, hip, root)
    return root

def make_cat(kind):
    root = build_cat(kind)
    export_glb(root, os.path.join(GLB_DIR, "cat_%s.glb" % kind))
    k = CATS[kind]["scale"]
    preview(os.path.join(PREV_DIR, "cat_%s_front.png" % kind), (0, 0, 0.8 * k), 4.2 * k, 12, -28)
    return root

# ── 무기 (손잡이 = 원점, 총구 = -Y 방향) ─────────────
def build_weapon(kind):
    new_scene("MN3D_w_" + kind)
    dark = M("w_dark", "#2E3036", 0.45, 0.4)
    metal = M("w_metal", "#7D838C", 0.3, 0.85)
    wood = M("w_wood", "#8A5A35", 0.6)
    tape = M("w_tape", "#C9A24A", 0.7)
    red = M("w_red", "#B8423A", 0.5)
    root = empty("Weapon")
    W = []
    if kind == "pistol":
        W += [box("slide", (0.06, 0.26, 0.07), dark, (0, -0.1, 0.07), bevel=0.012),
              box("grip", (0.055, 0.08, 0.14), dark, (0, 0.0, -0.01), (math.radians(-12), 0, 0), bevel=0.012),
              cyl("barrel", 0.016, 0.06, metal, (0, -0.24, 0.075), (math.radians(90), 0, 0))]
    elif kind == "shotgun":
        W += [cyl("barrel", 0.026, 0.62, dark, (0, -0.35, 0.06), (math.radians(90), 0, 0)),
              cyl("tube", 0.022, 0.48, metal, (0, -0.3, 0.015), (math.radians(90), 0, 0)),
              box("pump", (0.06, 0.16, 0.055), wood, (0, -0.32, 0.015), bevel=0.015),
              box("receiver", (0.065, 0.2, 0.09), dark, (0, -0.04, 0.05), bevel=0.012),
              box("stock", (0.06, 0.26, 0.09), wood, (0, 0.18, 0.02), (math.radians(8), 0, 0), bevel=0.02),
              box("grip", (0.05, 0.06, 0.12), wood, (0, 0.03, -0.04), (math.radians(-18), 0, 0), bevel=0.012)]
    elif kind == "crossbow":
        W += [box("stock", (0.06, 0.55, 0.06), wood, (0, -0.12, 0.04), bevel=0.012),
              cyl("tin", 0.06, 0.16, metal, (0, -0.02, 0.06), (math.radians(90), 0, 0)),
              tube("limb", [(-0.26, -0.3, 0.05), (0, -0.38, 0.06), (0.26, -0.3, 0.05)], 0.018, dark),
              tube("string", [(-0.26, -0.3, 0.05), (0, -0.12, 0.06), (0.26, -0.3, 0.05)], 0.004, tape, smooth_curve=False),
              cyl("bolt", 0.008, 0.4, metal, (0, -0.26, 0.08), (math.radians(90), 0, 0)),
              box("tapewrap", (0.07, 0.06, 0.07), tape, (0, -0.22, 0.04), bevel=0.01)]
    elif kind == "sniper":
        W += [cyl("barrel", 0.02, 0.75, dark, (0, -0.42, 0.06), (math.radians(90), 0, 0)),
              cyl("scope", 0.035, 0.26, dark, (0, -0.05, 0.14), (math.radians(90), 0, 0)),
              box("body", (0.07, 0.34, 0.09), M("w_olive", "#55603F", 0.6), (0, -0.02, 0.05), bevel=0.015),
              box("stock", (0.06, 0.24, 0.1), M("w_olive", "#55603F", 0.6), (0, 0.24, 0.03), bevel=0.02),
              cyl("muzzle", 0.03, 0.08, metal, (0, -0.8, 0.06), (math.radians(90), 0, 0))]
    elif kind == "knife":
        W += [box("blade", (0.02, 0.3, 0.06), metal, (0, -0.2, 0.0), bevel=0.006),
              box("handle", (0.035, 0.12, 0.045), dark, (0, -0.0, 0.0), bevel=0.01),
              box("guard", (0.08, 0.02, 0.06), dark, (0, -0.06, 0.0), bevel=0.005)]
    elif kind == "hammer":
        W += [cyl("handle", 0.025, 0.7, wood, (0, -0.25, 0.0), (math.radians(90), 0, 0)),
              box("head", (0.22, 0.14, 0.14), dark, (0, -0.6, 0.0), bevel=0.02),
              box("band", (0.23, 0.04, 0.15), red, (0, -0.6, 0.0), bevel=0.01)]
    elif kind == "bat":
        W += [cyl("pipe", 0.025, 0.55, metal, (0, -0.22, 0.0), (math.radians(90), 0, 0)),
              box("tape", (0.06, 0.12, 0.06), tape, (0, 0.02, 0.0), bevel=0.01)]
    merge("weapon", W, (0, 0, 0), root)
    return root

def make_weapons():
    for kind in ("pistol", "shotgun", "crossbow", "sniper", "knife", "hammer", "bat"):
        root = build_weapon(kind)
        export_glb(root, os.path.join(GLB_DIR, "w_%s.glb" % kind))

# ── 맵 소품 (mn_props 모델 재사용 + 추가 소품) ──────────
def _m(n, h, r=0.6, me=0.0, e=0.0):
    return M("x_" + n, h, r, me, 0.0, e)

def lamp():
    root = empty("lamp")
    pole = _m("pole", "#3B3F47", 0.4, 0.6)
    cyl("base", 0.14, 0.22, pole, (0, 0, 0.11), parent=root, bevel=0.02)
    cyl("pole", 0.045, 3.0, pole, (0, 0, 1.6), parent=root)
    tube("arm", [(0, 0, 3.0), (0, -0.1, 3.18), (0, -0.45, 3.2)], 0.035, pole, parent=root)
    box("head", (0.22, 0.34, 0.08), pole, (0, -0.5, 3.15), parent=root, bevel=0.03)
    box("bulb", (0.16, 0.26, 0.03), _m("bulb", "#FFE7B0", 0.3, 0.0, 6.0), (0, -0.5, 3.1), parent=root)
    return root

def bush(seed=0):
    import random
    rnd = random.Random(seed)
    root = empty("bush")
    g1, g2 = _m("leaf", "#4E7D3A", 0.8), _m("leaf2", "#6A9A47", 0.8)
    for i in range(7):
        a = rnd.uniform(0, math.tau)
        r = rnd.uniform(0.05, 0.28)
        sphere("b", rnd.uniform(0.16, 0.26), g1 if i % 2 else g2, (math.cos(a) * r, math.sin(a) * r, rnd.uniform(0.14, 0.3)), (1, 1, 0.85), parent=root, seg=16, ring=10)
    return root

def rock(seed=0):
    root = empty("rock")
    sphere("r", 0.22, _m("rock", "#8A8D93", 0.9), (0, 0, 0.1), (1.3, 1.0, 0.65), parent=root, seg=10, ring=7)
    sphere("r2", 0.12, _m("rock2", "#73767C", 0.9), (0.2, 0.1, 0.06), (1.2, 1.0, 0.7), parent=root, seg=8, ring=6)
    return root

def wcrate(s=1.0):
    root = empty("crate")
    w = _m("wood", "#A0703F", 0.7)
    d = _m("wood_d", "#6E4A28", 0.7)
    box("c", (0.7 * s, 0.7 * s, 0.62 * s), w, (0, 0, 0.31 * s), parent=root, bevel=0.02)
    for sx in (-1, 1):
        box("e", (0.06 * s, 0.72 * s, 0.64 * s), d, (sx * 0.33 * s, 0, 0.31 * s), parent=root, bevel=0.01)
    box("x", (0.08 * s, 0.02, 0.8 * s), d, (0, -0.355 * s, 0.31 * s), (0, math.radians(42), 0), parent=root)
    return root

def tires():
    root = empty("tires")
    t = _m("tire", "#24252A", 0.85)
    for i in range(3):
        torus("t", 0.22, 0.1, t, (0, 0, 0.1 + i * 0.19), parent=root, seg=24, rseg=10)
    return root

def pallet():
    root = empty("pallet")
    w = _m("pal", "#B98B55", 0.8)
    for i in range(5):
        box("s", (0.12, 0.9, 0.03), w, (-0.4 + i * 0.2, 0, 0.13), parent=root)
    for y in (-0.4, 0, 0.4):
        box("b", (0.95, 0.1, 0.1), w, (0, y, 0.06), parent=root)
    return root

def jersey(stripe=False):
    root = empty("barrier")
    c = _m("concrete", "#B7B6B0", 0.85)
    box("base", (1.2, 0.4, 0.2), c, (0, 0, 0.1), parent=root, bevel=0.03)
    box("top", (1.2, 0.18, 0.4), c, (0, 0, 0.4), parent=root, bevel=0.04)
    if stripe:
        for i in range(4):
            box("st", (0.14, 0.2, 0.42), _m("stripe_o", "#E8892E", 0.6), (-0.45 + i * 0.3, 0, 0.42), parent=root, bevel=0.01)
    return root

def ammo_box():
    root = empty("ammo")
    g = _m("olive", "#55603F", 0.6)
    box("b", (0.6, 0.36, 0.34), g, (0, 0, 0.17), parent=root, bevel=0.03)
    box("lid", (0.62, 0.38, 0.06), _m("olive_d", "#434C31", 0.6), (0, 0, 0.36), parent=root, bevel=0.02)
    box("lab", (0.24, 0.01, 0.1), _m("label", "#E8D9A8", 0.6), (0, -0.185, 0.2), parent=root)
    return root

def stump():
    root = empty("stump")
    cyl("s", 0.22, 0.3, _m("bark", "#6E4A2E", 0.9), (0, 0, 0.15), parent=root, seg=14)
    cyl("top", 0.2, 0.02, _m("ring", "#C9A574", 0.8), (0, 0, 0.305), parent=root, seg=14)
    return root

def manhole():
    root = empty("manhole")
    cyl("m", 0.75, 0.03, _m("iron", "#4A505E", 0.35, 0.7), (0, 0, 0.015), parent=root)
    for i in range(5):
        box("g", (1.1, 0.06, 0.04), _m("iron_d", "#2A2F3A", 0.5, 0.5), (0, -0.4 + i * 0.2, 0.03), parent=root)
    return root

EXTRA = {"lamp": lamp, "bush": lambda: bush(1), "bush2": lambda: bush(5), "rock": rock, "crate": lambda: wcrate(1.0),
         "crate_small": lambda: wcrate(0.7), "tires": tires, "pallet": pallet, "barrier_concrete": lambda: jersey(False),
         "barrier_stripe": lambda: jersey(True), "ammo_locker": ammo_box, "stump": stump, "manhole": manhole}

def make_props(only=None):
    import mn_props, importlib
    importlib.reload(mn_props)
    table = dict(mn_props.PROPS)
    table.update(EXTRA)
    done = []
    for name, fn in table.items():
        if only and name not in only:
            continue
        new_scene("MN3D_p_" + name)
        root = fn()
        export_glb(root, os.path.join(GLB_DIR, "props", name + ".glb"))
        done.append(name)
    return done

def purge_scenes(prefix="MN3D_"):
    for s in list(bpy.data.scenes):
        if s.name.startswith(prefix) and s != bpy.context.window.scene:
            for ob in list(s.collection.all_objects):
                bpy.data.objects.remove(ob, do_unlink=True)
            bpy.data.scenes.remove(s)
