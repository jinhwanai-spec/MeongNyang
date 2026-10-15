# 캐릭터 모델: 햄스터 용병(플레이어) + 고양이 적 3종
import math
from mathutils import Vector
from mn_lib import *

HEAD_C = Vector((0, 0, 1.06))
HEAD_R = 0.64
EYE_X, EYE_Z = 0.4, -0.1

SPECS = {
    "hamster": {
        "fur": "#F0A85E", "cream": "#FFF3E2", "inner": "#F5A3A8", "nose": "#F0828F", "eye": "hamster",
        "ears": "round", "cheeks": True, "helmet": "#6C6240", "goggle": True, "headset": True,
        "vest": "#6F6542", "pouch": "#5C5435", "pack": "#6A6040", "strap": "#3A3628", "tail": "nub",
        "feet": "#F7C9B8", "scale": 1.0,
    },
    "cat_tabby": {
        "fur": "#A9A9AD", "stripe": "#86868D", "cream": "#F4F2EE", "inner": "#F2A0A8", "nose": "#E98A98", "eye": "cat",
        "iris": "#F4C430", "ears": "pointy", "helmet": None, "bandana": "#C0392B",
        "vest": "#2F3238", "pouch": "#24262B", "pack": None, "strap": "#1C1D21", "tail": "long",
        "feet": "#F4F2EE", "scale": 0.95, "angry": True,
    },
    "cat_black": {
        "fur": "#3A3A42", "cream": "#4A4A52", "inner": "#C77D88", "nose": "#5A4048", "eye": "cat",
        "iris": "#F4C430", "ears": "pointy", "helmet": "#1E1F23", "goggle": True,
        "vest": "#2A3A2C", "pouch": "#22301F", "pack": "#2A3A2C", "strap": "#121315", "tail": "long",
        "feet": "#3A3A40", "scale": 1.18, "angry": True, "armor": True,
    },
    "cat_white": {
        "fur": "#F3F0EA", "patch": "#E09A52", "patch2": "#3A3A3E", "cream": "#FFFFFF", "inner": "#F2A0A8", "nose": "#F08C9C", "eye": "cat",
        "iris": "#F4C430", "ears": "pointy", "helmet": None, "cap": "#3A3D44", "bandana": "#2E4A7A",
        "vest": "#3A3D44", "pouch": "#2E3036", "pack": "#3A3D44", "strap": "#1C1D21", "tail": "long",
        "feet": "#FFFFFF", "scale": 1.0, "angry": True,
    },
}


def twotone(base, name, low_hex, ky=0.6, thresh=-0.42, soft=0.05):
    """털 재질 복사본 — 오브젝트 좌표 기준 아래·앞쪽을 크림색으로 (부드러운 경계)"""
    m = base.copy()
    m.name = name
    nt = m.node_tree
    b = nt.nodes.get("Principled BSDF")
    src = b.inputs["Base Color"].links[0].from_socket if b.inputs["Base Color"].is_linked else None
    top = nt.nodes.new("ShaderNodeRGB")
    top.outputs[0].default_value = tuple(b.inputs["Base Color"].default_value)
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Object"], sep.inputs[0])
    mul = nt.nodes.new("ShaderNodeMath"); mul.operation = "MULTIPLY"; mul.inputs[1].default_value = ky
    nt.links.new(sep.outputs[1], mul.inputs[0])
    add = nt.nodes.new("ShaderNodeMath"); add.operation = "ADD"
    nt.links.new(sep.outputs[2], add.inputs[0]); nt.links.new(mul.outputs[0], add.inputs[1])
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = thresh - soft
    mr.inputs["From Max"].default_value = thresh + soft
    nt.links.new(add.outputs[0], mr.inputs["Value"])
    mix = nt.nodes.new("ShaderNodeMix"); mix.data_type = "RGBA"
    nt.links.new(mr.outputs["Result"], mix.inputs[0])
    mix.inputs[6].default_value = hex_lin(low_hex) + [1]
    nt.links.new(src if src else top.outputs[0], mix.inputs[7])
    nt.links.new(mix.outputs[2], b.inputs["Base Color"])
    return m

class Char:
    pass

def build(kind):
    s = SPECS[kind]
    c = Char()
    c.kind = kind
    c.spec = s
    root = empty("root_" + kind)
    c.root = root
    fur = fur_mat(kind + "_fur", s["fur"], s.get("stripe"), 2.4)
    cream = mat(kind + "_cream", s["cream"], 0.6, sss=0.05)
    inner = mat(kind + "_inner", s["inner"], 0.5)
    c.fur_mat = fur
    c.paw_mat = mat(kind + "_feet", s["feet"], 0.55)

    # 하체 그룹 (발)
    c.foot_l = sphere("footL", 0.13, c.paw_mat, (-0.16, -0.05, 0.075), (1.0, 1.3, 0.6), parent=root)
    c.foot_r = sphere("footR", 0.13, c.paw_mat, (0.16, -0.05, 0.075), (1.0, 1.3, 0.6), parent=root)
    # 상체 그룹 (몸·머리·장비) — 걷기 때 통통 튀는 부분
    up = empty("upper", (0, 0, 0), root)
    c.upper = up
    body = sphere("body", 1.0, fur, (0, 0.02, 0.44), (0.46, 0.42, 0.42), parent=up)
    c.arms = []
    for sx in (-1, 1):  # 짤막한 팔
        ag = empty("arm%d" % sx, (sx * 0.38, -0.06, 0.6), up)
        ag.rotation_euler = (math.radians(-30), sx * math.radians(-18), 0)
        sphere("armU", 0.11, fur, (0, 0, -0.1), (0.9, 0.9, 1.4), parent=ag)
        sphere("armP", 0.085, c.paw_mat, (0, 0, -0.24), (1.0, 1.0, 0.9), parent=ag)
        c.arms.append(ag)
    sphere("belly", 1.0, cream, (0, -0.2, 0.3), (0.25, 0.18, 0.15), parent=up)
    if s.get("patch"):
        pm = mat(kind + "_patch", s["patch"], 0.6)
        sphere("patchB", 1.0, pm, (0.17, 0.1, 0.52), (0.22, 0.24, 0.2), parent=up)
    # 꼬리
    if s["tail"] == "nub":
        c.tail = sphere("tail", 0.08, inner, (0, 0.37, 0.24), parent=up)
    else:
        c.tail = empty("tailPivot", (0, 0.3, 0.26), up)
        c.tail.scale = (0.8, 0.8, 0.8)
        tube("tail", [(0, 0, 0), (0.05, 0.28, 0.0), (0.18, 0.5, 0.22), (0.15, 0.6, 0.55), (0.02, 0.55, 0.8)], 0.075, fur, c.tail)
    # 조끼
    vest = mat(kind + "_vest", s["vest"], 0.75)
    pouch = mat(kind + "_pouch", s["pouch"], 0.8)
    strap = mat(kind + "_strap", s["strap"], 0.8)
    sphere("vest", 1.0, vest, (0, 0.0, 0.56), (0.5, 0.46, 0.25), parent=up)
    for i, x in enumerate((-0.15, 0.15)):
        box("pouch%d" % i, (0.2, 0.1, 0.17), pouch, (x, -0.43, 0.52), (math.radians(-8), 0, 0), up, bevel=0.05, sub=1)
        box("flap%d" % i, (0.21, 0.11, 0.06), vest, (x, -0.45, 0.6), (math.radians(-8), 0, 0), up, bevel=0.03, sub=1)
    torus("belt", 0.45, 0.035, strap, (0, 0.0, 0.36), (0, 0, 0), up, scale=(1.0, 0.92, 1.0))
    box("buckle", (0.1, 0.04, 0.07), mat("buckle", "#C9B27A", 0.35, 0.8), (0, -0.42, 0.36), parent=up, bevel=0.015)
    if s.get("armor"):
        box("plate", (0.5, 0.1, 0.36), mat(kind + "_plate", "#3A3D44", 0.4, 0.6), (0, -0.41, 0.58), parent=up, bevel=0.05, sub=1)
        for sx in (-1, 1):
            sphere("pad%d" % sx, 1.0, vest, (sx * 0.36, 0.0, 0.66), (0.13, 0.18, 0.1), parent=up)
    # 배낭
    if s.get("pack"):
        pk = mat(kind + "_pack", s["pack"], 0.75)
        box("pack", (0.52, 0.3, 0.5), pk, (0, 0.42, 0.6), parent=up, bevel=0.12, sub=2)
        box("packFlap", (0.48, 0.17, 0.16), pouch, (0, 0.46, 0.8), parent=up, bevel=0.05, sub=1)
        box("packPocket", (0.34, 0.1, 0.2), pouch, (0, 0.58, 0.55), parent=up, bevel=0.04, sub=1)
        for sx in (-1, 1):
            box("strap%d" % sx, (0.07, 0.42, 0.05), strap, (sx * 0.19, 0.05, 0.74), (0.3, 0, 0), parent=up, bevel=0.02)
    # 머리
    head = empty("head", HEAD_C, up)
    head.scale = (1.1, 1.1, 1.1)
    c.head = head
    H = Vector((0, 0, 0))
    skull_m = twotone(fur, kind + "_skull", s["cream"]) if s.get("cheeks") else fur
    sphere("skull", HEAD_R, skull_m, (0, 0, 0), (1.12, 0.98, 0.88), parent=head)
    if s["eye"] == "cat":  # 볼털 뭉치
        for sx in (-1, 1):
            sphere("tuft%d" % sx, 0.2, fur, (sx * 0.56, -0.12, -0.24), (1.0, 0.8, 0.75), parent=head)
    if s.get("patch2") and False:
        sphere("patchH", HEAD_R * 0.55, mat(kind + "_patch2", s["patch2"], 0.6), (-0.34, -0.3, 0.02), (1.0, 0.9, 0.85), parent=head)
    if s.get("patch"):
        sphere("patchH2", HEAD_R * 0.45, mat(kind + "_patchc", s["patch"], 0.6), (0.33, 0.08, 0.28), (1.1, 1.0, 0.8), parent=head)
    # 주둥이·볼
    if s.get("cheeks"):
        for sx in (-1, 1):
            sphere("cheek%d" % sx, 0.2, cream, (sx * 0.3, -0.4, -0.28), (1.0, 0.85, 0.82), parent=head)
        sphere("muzzle", 0.12, cream, (0, -0.55, -0.2), (1.3, 0.7, 0.8), parent=head)
    else:
        sphere("muzzle", 0.24, cream, (0, -0.46, -0.17), (1.35, 0.75, 0.8), parent=head)
        sphere("chin", 0.16, cream, (0, -0.4, -0.32), (1.2, 0.8, 0.7), parent=head)
    # 볼터치
    blush = mat(kind + "_blush", "#F7A9A8" if s["eye"] == "hamster" else "#E99AA5", 0.6)
    for sx in (-1, 1):
        ob = sphere("blush%d" % sx, 0.085, blush, parent=head, scale=(1.3, 0.35, 0.8))
        face_on(ob, H, (sx * 0.62, -0.72, -0.22), HEAD_R * 0.97)
    # 코·입
    nose = sphere("nose", 0.055, mat(kind + "_nose", s["nose"], 0.35), parent=head, scale=(1.3, 0.8, 0.9))
    face_on(nose, H, (0, -1.0, -0.12), HEAD_R * 0.98 if s.get("cheeks") else HEAD_R * 1.0)
    nose.location.y -= 0.06
    mouth_m = mat("mouth", "#3B2626", 0.5)
    my = -0.62 if s.get("cheeks") else -0.66
    tube("mouth", [(-0.075, my, -0.2), (-0.035, my - 0.015, -0.235), (0, my, -0.205), (0.035, my - 0.015, -0.235), (0.075, my, -0.2)], 0.011, mouth_m, head)
    # 수염 (고양이)
    if s["eye"] == "cat":
        wm = mat("whisker", "#FFFFFF", 0.4)
        for sx in (-1, 1):
            for k in range(2):
                y = -0.52
                tube("wh%d%d" % (sx, k), [(sx * 0.24, y, -0.17 - k * 0.05), (sx * 0.4, y - 0.03, -0.15 - k * 0.07), (sx * 0.54, y + 0.03, -0.13 - k * 0.1)], 0.006, wm, head)
    # 눈 — 크고 낮게, 반짝이 2개 (귀염 포인트)
    c.eyes = []
    c.eyes_closed = []
    gloss = mat("eye_black", "#0D0D12", 0.08, coat=1.0, spec=1.0)
    hl = mat("eye_hl", "#FFFFFF", 0.3, emit=3.0)
    for sx in (-1, 1):
        ex, ez = sx * EYE_X, EYE_Z
        dirv = (ex, -0.9, ez)
        grp = empty("eye%d" % sx, (0, 0, 0), head)
        if s["eye"] == "hamster":
            e = sphere("eyeball", 0.2, gloss, parent=grp, scale=(0.86, 0.42, 1.06))
            face_on(e, H, dirv, HEAD_R * 0.9)
            gl = sphere("eyeglow", 0.1, mat("eye_glow", "#7A4A30", 0.2, emit=0.6), parent=grp, scale=(1.2, 0.3, 0.55))
            face_on(gl, H, (ex, -0.9, ez - 0.13), HEAD_R * 0.965)
        else:
            iris = mat(kind + "_iris", s["iris"], 0.12, coat=1.0)
            e = sphere("eyeball", 0.205, iris, parent=grp, scale=(0.95, 0.42, 1.04))
            face_on(e, H, dirv, HEAD_R * 0.9)
            p = sphere("pupil", 0.15, gloss, parent=grp, scale=(0.78, 0.42, 1.0))
            face_on(p, H, (ex, -0.9, ez - 0.02), HEAD_R * 0.975)
            if s.get("angry"):
                bm_ = mat(kind + "_brow", s.get("brow", "#2A2A30"), 0.6)
                br = sphere("brow", 0.1, bm_, parent=grp, scale=(1.5, 0.35, 0.36))
                face_on(br, H, (ex * 0.92, -0.9, ez + 0.3), HEAD_R * 0.985)
                br.rotation_quaternion = br.rotation_quaternion @ Quaternion((0, 1, 0), math.radians(-sx * 20))
        h1 = sphere("hl1", 0.058, hl, parent=grp)
        face_on(h1, H, (ex - 0.07, -0.9, ez + 0.11), HEAD_R * 0.975)
        h2 = sphere("hl2", 0.028, hl, parent=grp)
        face_on(h2, H, (ex + 0.07, -0.9, ez - 0.1), HEAD_R * 0.975)
        c.eyes.append(grp)
        # 감은 눈 (피격용 > <)
        cg = empty("eyeX%d" % sx, (0, 0, 0), head)
        ex = sx * 0.24
        ez = 0.03
        ey = -0.6
        tube("x1", [(ex - sx * 0.08, ey, ez + 0.06), (ex + sx * 0.02, ey - 0.02, ez), (ex - sx * 0.08, ey, ez - 0.06)], 0.018, gloss, cg, smooth_curve=False)
        cg.hide_render = True
        for ch in cg.children:
            ch.hide_render = True
        c.eyes_closed.append(cg)
    # 귀
    c.ears = []
    if s["ears"] == "round":
        for sx in (-1, 1):
            g = empty("ear%d" % sx, (sx * 0.62, 0.1, 0.46), head)
            g.rotation_euler = (math.radians(-10), sx * math.radians(38), 0)
            sphere("earO", 0.22, fur, (0, 0, 0), (1.0, 0.42, 1.0), parent=g)
            sphere("earI", 0.15, inner, (0, -0.05, -0.01), (1.0, 0.3, 1.0), parent=g)
            c.ears.append(g)
    else:
        for sx in (-1, 1):
            g = empty("ear%d" % sx, (sx * 0.42, 0.06, 0.4), head)
            g.rotation_euler = (math.radians(-8), sx * math.radians(26), 0)
            cone("earO", 0.25, 0.44, fur, (0, 0, 0.14), (0, 0, 0), g, seg=24, r2=0.045)
            ob = cone("earI", 0.16, 0.32, inner, (0, -0.09, 0.1), (0, 0, 0), g, seg=24, r2=0.03)
            g.scale = (1.0, 0.62, 1.0)
            ob.scale = (1, 0.5, 1)
            c.ears.append(g)
    # 헬멧
    if s.get("helmet"):
        hm = mat(kind + "_helmet", s["helmet"], 0.55)
        sphere("helmet", HEAD_R * 0.9, hm, (0, 0.08, 0.3), (1.08, 1.04, 0.86), parent=head, cut=0.12)
        torus("brim", HEAD_R * 0.86, 0.036, hm, (0, 0.08, 0.36), (math.radians(-8), 0, 0), head, scale=(1.12, 1.08, 1.0))
        if s.get("goggle"):
            gm = mat("goggle_frame", "#1E1E22", 0.5)
            lens = mat("goggle_lens", "#E8A23A", 0.05, coat=1.0, spec=1.0)
            GC = Vector((0, 0.08, 0.3))
            for sx in (-1, 1):
                fr = sphere("gframe%d" % sx, 0.14, gm, parent=head, scale=(1.25, 0.55, 0.85))
                face_on(fr, GC, (sx * 0.32, -0.85, 0.5), HEAD_R * 0.9)
                ln = sphere("glens%d" % sx, 0.12, lens, parent=head, scale=(1.2, 0.5, 0.78))
                face_on(ln, GC, (sx * 0.32, -0.85, 0.5), HEAD_R * 0.94)
    if s.get("cap"):
        cm = mat(kind + "_cap", s["cap"], 0.85)
        sphere("cap", HEAD_R * 0.88, cm, (0, 0.1, 0.3), (1.1, 1.06, 0.8), parent=head, cut=0.1)
        visor = box("visor", (0.55, 0.36, 0.05), cm, (0, -0.52, 0.36), (math.radians(-14), 0, 0), head, bevel=0.025, sub=1)
        visor.scale = (1.0, 1.0, 1.0)
        sphere("capBtn", 0.05, cm, (0, 0.12, 0.76), parent=head)
    if s.get("headset"):
        hs = mat("headset", "#2B2B2E", 0.45)
        for sx in (-1, 1):
            cyl("cup%d" % sx, 0.16, 0.12, hs, (sx * 0.66, 0.04, 0.02), (0, math.radians(90), 0), head, bevel=0.03)
        torus("band", HEAD_R * 1.04, 0.035, hs, (0, 0.06, 0.02), (math.radians(90), 0, 0), head, arc=0.5)
    if s.get("bandana"):
        bm = mat(kind + "_bandana", s["bandana"], 0.7)
        if not s.get("cap"):  # 이마 두건
            torus("bandana", HEAD_R * 0.92, 0.045, bm, (0, 0.03, 0.27), (math.radians(10), 0, 0), head, scale=(1.12, 1.02, 1.0))
            sphere("knot", 0.08, bm, (0.12, 0.6, 0.2), parent=head)
            for sx in (-1, 1):
                box("tail%d" % sx, (0.08, 0.04, 0.26), bm, (0.12 + sx * 0.1, 0.66, 0.05), (0, sx * math.radians(20), 0), head, bevel=0.015)
        else:  # 목 스카프
            torus("bandana", 0.36, 0.07, bm, (0, -0.02, 0.8), (math.radians(8), 0, 0), up, scale=(1.08, 0.98, 1.0))
            sphere("knot", 0.09, bm, (0.16, -0.32, 0.76), parent=up)
    c.root.scale = (s["scale"],) * 3
    return c

def pose(c, mode, t):
    """mode: idle/walk/hurt, t: 0..1"""
    tau = 2 * math.pi
    for g in c.eyes:
        g.hide_render = False
        for ch in g.children:
            ch.hide_render = False
    for g in c.eyes_closed:
        for ch in g.children:
            ch.hide_render = True
    c.upper.location = (0, 0, 0)
    c.upper.rotation_euler = (0, 0, 0)
    c.upper.scale = (1, 1, 1)
    c.head.rotation_euler = (0, 0, 0)
    c.foot_l.location = (-0.16, -0.05, 0.075)
    c.foot_r.location = (0.16, -0.05, 0.075)
    for i, a in enumerate(c.arms):
        sx = -1 if i == 0 else 1
        a.rotation_euler = (math.radians(-30), sx * math.radians(-18), 0)
    for i, e in enumerate(c.ears):
        sx = -1 if i == 0 else 1
        base = c.ears[i].rotation_euler.copy()
    if mode == "idle":
        b = math.sin(t * tau)
        c.upper.location = (0, 0, 0.015 * b)
        c.upper.scale = (1 + 0.012 * b, 1 + 0.012 * b, 1 - 0.01 * b)
        c.head.rotation_euler = (0, math.radians(2.5 * math.sin(t * tau)), 0)
        if hasattr(c, "tail") and c.tail:
            c.tail.rotation_euler = (0, 0, math.radians(12 * math.sin(t * tau)))
        if t > 0.7:  # 깜빡임
            _blink(c)
    elif mode == "walk":
        ph = t * tau
        lift_l = max(0.0, math.sin(ph)) * 0.1
        lift_r = max(0.0, math.sin(ph + math.pi)) * 0.1
        c.foot_l.location = (-0.16, -0.05 - 0.13 * math.cos(ph), 0.075 + lift_l)
        c.foot_r.location = (0.16, -0.05 + 0.13 * math.cos(ph), 0.075 + lift_r)
        bob = abs(math.sin(ph))
        c.upper.location = (0, 0, 0.07 * bob)
        c.upper.scale = (1 + 0.03 * (1 - bob), 1 + 0.03 * (1 - bob), 1 - 0.04 * (1 - bob))
        c.upper.rotation_euler = (math.radians(-7), math.radians(5 * math.sin(ph)), math.radians(4 * math.cos(ph)))
        for i, a in enumerate(c.arms):
            sx = -1 if i == 0 else 1
            a.rotation_euler = (math.radians(-30 + 28 * math.cos(ph) * sx), sx * math.radians(-18), 0)
        c.head.rotation_euler = (math.radians(3 * bob), 0, 0)
        if hasattr(c, "tail") and c.tail:
            c.tail.rotation_euler = (0, 0, math.radians(18 * math.sin(ph)))
    elif mode == "hurt":
        c.upper.rotation_euler = (math.radians(6), math.radians(-6), 0)
        c.upper.scale = (1.05, 1.05, 0.94)
        c.head.rotation_euler = (math.radians(-6), 0, 0)
        for g in c.eyes:
            for ch in g.children:
                ch.hide_render = True
        for g in c.eyes_closed:
            for ch in g.children:
                ch.hide_render = False
    elif mode == "happy":
        c.upper.location = (0, 0, 0.03)
        c.head.rotation_euler = (0, math.radians(6), 0)
        _blink(c)

def _blink(c):
    for g in c.eyes:
        for ch in g.children:
            ch.hide_render = True
    for g in c.eyes_closed:
        for ch in g.children:
            ch.hide_render = False

# ── 무기 + 앞발 ─────────────────────────────────────
GUNMETAL = "#2C2F36"

def weapon(kind, paw_hex, fur_hex=None):
    """원점 = 손잡이(회전 중심), +X = 총구 방향"""
    root = empty("w_" + kind)
    gm = mat("gunmetal", GUNMETAL, 0.35, 0.7)
    dark = mat("gun_dark", "#1B1D22", 0.5, 0.3)
    wood = mat("wood", "#8A5A35", 0.55)
    orange = mat("tip_orange", "#F2994A", 0.4)
    paw = mat("paw_" + paw_hex, paw_hex, 0.55, sss=0.05)
    parts = [root]
    def P(o):
        parts.append(o)
        return o
    if kind == "pistol":
        P(box("slide", (0.62, 0.17, 0.17), gm, (0.24, 0, 0.1), parent=root, bevel=0.025))
        P(box("grip", (0.16, 0.15, 0.32), dark, (-0.01, 0, -0.08), (0, math.radians(-14), 0), root, bevel=0.03))
        P(box("frame", (0.42, 0.15, 0.08), dark, (0.16, 0, 0.0), parent=root, bevel=0.02))
        P(torus("guard", 0.07, 0.015, dark, (0.11, 0, -0.04), (math.radians(90), 0, 0), root, arc=0.5))
        P(box("sight", (0.04, 0.05, 0.04), orange, (0.52, 0, 0.2), parent=root))
        paws = [(0.0, -0.1, -0.02)]
    elif kind == "shotgun":
        P(cyl("barrel", 0.055, 1.1, gm, (0.55, 0, 0.1), (0, math.radians(90), 0), root))
        P(cyl("tube", 0.045, 0.85, dark, (0.45, 0, -0.01), (0, math.radians(90), 0), root))
        P(box("receiver", (0.36, 0.14, 0.2), gm, (0.0, 0, 0.06), parent=root, bevel=0.025))
        P(box("pump", (0.34, 0.15, 0.12), wood, (0.52, 0, -0.01), parent=root, bevel=0.035))
        P(box("stock", (0.55, 0.13, 0.2), wood, (-0.38, 0, -0.02), (0, math.radians(8), 0), root, bevel=0.04))
        P(box("grip", (0.12, 0.12, 0.2), wood, (-0.08, 0, -0.1), (0, math.radians(-20), 0), root, bevel=0.03))
        paws = [(-0.06, -0.1, -0.08), (0.52, -0.1, -0.02)]
    elif kind == "crossbow":
        P(box("stock", (0.95, 0.12, 0.13), wood, (0.2, 0, 0.0), parent=root, bevel=0.03))
        P(box("rail", (0.7, 0.08, 0.05), gm, (0.35, 0, 0.08), parent=root, bevel=0.01))
        P(box("grip", (0.12, 0.11, 0.24), wood, (-0.05, 0, -0.12), (0, math.radians(-15), 0), root, bevel=0.03))
        limb = mat("limb", "#D64545", 0.45)
        P(tube("limbs", [(0.6, -0.55, -0.0), (0.72, -0.3, 0.02), (0.76, 0, 0.04), (0.72, 0.3, 0.02), (0.6, 0.55, 0.0)], 0.035, limb, root))
        string = mat("string", "#EDE6D6", 0.6)
        P(tube("str", [(0.6, -0.55, 0), (0.32, 0, 0.08), (0.6, 0.55, 0)], 0.008, string, root, smooth_curve=False))
        P(cyl("bolt", 0.018, 0.8, mat("bolt", "#C9A27A", 0.6), (0.55, 0, 0.12), (0, math.radians(90), 0), root))
        P(cone("tip", 0.04, 0.1, mat("steel", "#C9D1DA", 0.25, 0.9), (0.98, 0, 0.12), (0, math.radians(90), 0), root))
        paws = [(-0.05, -0.1, -0.1), (0.45, -0.1, -0.04)]
    elif kind == "bat":
        P(cyl("bat", 0.06, 1.0, mat("pipe", "#9AA3B2", 0.3, 0.9), (0.45, 0, 0), (0, math.radians(90), 0), root, r2=0.075))
        P(cyl("tape", 0.065, 0.25, mat("tape", "#D64545", 0.7), (0.05, 0, 0), (0, math.radians(90), 0), root))
        paws = [(0.0, -0.1, 0.0)]
    elif kind == "knife":
        P(box("handle", (0.26, 0.09, 0.1), dark, (0.0, 0, 0), parent=root, bevel=0.03))
        P(box("guardk", (0.04, 0.12, 0.18), gm, (0.14, 0, 0), parent=root, bevel=0.01))
        blade = P(box("blade", (0.42, 0.03, 0.12), mat("blade", "#D9DEE6", 0.15, 1.0), (0.36, 0, 0.0), parent=root, bevel=0.01))
        paws = [(0.0, -0.08, 0.0)]
    elif kind == "hammer":
        P(cyl("handle", 0.045, 1.05, wood, (0.45, 0, 0), (0, math.radians(90), 0), root))
        P(box("head", (0.26, 0.24, 0.48), mat("hammer_head", "#5A606B", 0.35, 0.8), (0.95, 0, 0.0), parent=root, bevel=0.04))
        P(cyl("grip", 0.05, 0.25, dark, (0.05, 0, 0), (0, math.radians(90), 0), root))
        paws = [(0.0, -0.08, 0.0), (0.4, -0.08, 0.0)]
    elif kind == "sniper":
        P(cyl("barrel", 0.035, 1.25, gm, (0.75, 0, 0.08), (0, math.radians(90), 0), root))
        P(box("body", (0.6, 0.13, 0.2), dark, (0.12, 0, 0.04), parent=root, bevel=0.03))
        P(box("stock", (0.55, 0.12, 0.24), mat("sniper_stock", "#4B5A3A", 0.6), (-0.42, 0, -0.03), parent=root, bevel=0.05))
        P(cyl("scope", 0.06, 0.55, dark, (0.15, 0, 0.24), (0, math.radians(90), 0), root))
        P(cyl("lensF", 0.07, 0.05, mat("lens_red", "#D64545", 0.1, emit=1.5), (0.44, 0, 0.24), (0, math.radians(90), 0), root))
        P(box("mag", (0.1, 0.1, 0.18), gm, (0.1, 0, -0.12), parent=root, bevel=0.02))
        P(box("grip", (0.1, 0.1, 0.2), dark, (-0.1, 0, -0.12), (0, math.radians(-15), 0), root, bevel=0.02))
        paws = [(-0.1, -0.1, -0.08), (0.42, -0.1, 0.0)]
    elif kind == "rifle":
        P(cyl("barrel", 0.04, 0.6, gm, (0.75, 0, 0.08), (0, math.radians(90), 0), root))
        P(box("upper", (0.75, 0.13, 0.15), dark, (0.2, 0, 0.08), parent=root, bevel=0.025))
        P(box("hand", (0.4, 0.15, 0.14), dark, (0.55, 0, 0.06), parent=root, bevel=0.03))
        P(box("mag", (0.12, 0.1, 0.3), gm, (0.12, 0, -0.12), (0, math.radians(12), 0), root, bevel=0.02))
        P(box("stock", (0.4, 0.11, 0.18), dark, (-0.38, 0, 0.02), parent=root, bevel=0.04))
        P(cyl("scope", 0.05, 0.3, gm, (0.18, 0, 0.23), (0, math.radians(90), 0), root))
        P(box("grip", (0.1, 0.1, 0.2), dark, (-0.08, 0, -0.1), (0, math.radians(-15), 0), root, bevel=0.02))
        paws = [(-0.06, -0.1, -0.08), (0.55, -0.1, 0.0)]
    for i, p in enumerate(paws):
        P(sphere("paw%d" % i, 0.085, paw, p, (1.0, 0.85, 0.9), parent=root))
    return root, parts
