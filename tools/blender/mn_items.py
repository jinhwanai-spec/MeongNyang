# 아이템 아이콘 (3/4 시점, 128px 기준)
import math, os
from mn_lib import *
import mn_lib

def M(n, c, r=0.5, m=0.0, **kw):
    return mat("i_" + n, c, r, m, **kw)

def canned_food(R):
    cyl("can", 0.35, 0.5, M("tin", "#C3CBD5", 0.35, 0.55), (0, 0, 0.25), parent=R, bevel=0.02)
    cyl("label", 0.355, 0.3, M("can_label", "#3E5C8A", 0.5), (0, 0, 0.25), parent=R)
    sphere("fish", 0.1, M("fish", "#F2994A", 0.5), (0, -0.33, 0.25), (1.6, 0.4, 0.8), parent=R)

def kibble(R):
    box("bag", (0.6, 0.28, 0.95), M("kibble", "#C0392B", 0.6), (0, 0, 0.48), parent=R, bevel=0.1, sub=1)
    box("top", (0.62, 0.1, 0.12), M("kibble_d", "#922B21", 0.6), (0, 0, 0.97), parent=R, bevel=0.03)
    cyl("badge", 0.18, 0.02, M("badge", "#F3EEE6", 0.5), (0, -0.15, 0.5), (math.radians(90), 0, 0), R)
    for x, z in ((-0.05, 0.53), (0.06, 0.47), (0.0, 0.42)):
        sphere("k", 0.04, M("kib", "#8A5A3B", 0.6), (x, -0.17, z), parent=R)

def churu(R):
    box("tube", (0.18, 0.08, 0.8), M("churu", "#F29BB0", 0.4), (0, 0, 0.4), (0, math.radians(20), 0), R, bevel=0.06, sub=1)
    box("lbl", (0.16, 0.085, 0.2), M("churu_l", "#FFFFFF", 0.5), (0.03, 0, 0.42), (0, math.radians(20), 0), R)

def energy_drink(R):
    cyl("can", 0.2, 0.7, M("edrink", "#3FC1C9", 0.25, 0.6), (0, 0, 0.35), parent=R, bevel=0.02)
    cyl("top", 0.17, 0.04, M("tin", "#C3CBD5", 0.35, 0.55), (0, 0, 0.72), parent=R)
    box("bolt", (0.08, 0.02, 0.3), M("bolt_y", "#F2C14E", 0.4, emit=0.5), (0, -0.2, 0.36), (0, math.radians(20), 0), R)

def bandage(R):
    cyl("roll", 0.3, 0.32, M("bandage", "#F3EEE6", 0.7), (0, 0, 0.3), (math.radians(90), 0, 0), R, bevel=0.03)
    cyl("hole", 0.1, 0.34, M("bandage_in", "#C9B8A0", 0.7), (0, 0, 0.3), (math.radians(90), 0, 0), R)
    box("tail", (0.3, 0.3, 0.02), M("bandage", "#F3EEE6", 0.7), (0.32, 0, 0.02), parent=R)

def medkit(R):
    box("case", (0.9, 0.4, 0.64), M("medkit", "#E8ECF0", 0.35), (0, 0, 0.32), parent=R, bevel=0.06)
    r = M("medred", "#D64545", 0.4)
    box("cv", (0.14, 0.02, 0.4), r, (0, -0.205, 0.32), parent=R)
    box("ch", (0.4, 0.02, 0.14), r, (0, -0.205, 0.32), parent=R)
    torus("handle", 0.14, 0.03, M("mk_h", "#5A616E", 0.4), (0, 0, 0.66), (math.radians(90), 0, 0), R, arc=0.5)

def screws(R):
    m = M("screw", "#AEB6C2", 0.38, 0.55)
    for i, (x, y, rz) in enumerate(((-0.15, 0, 0.3), (0.1, 0.1, -0.5), (0.05, -0.15, 1.2))):
        g = empty("s", (x, y, 0.06), R)
        g.rotation_euler = (0, math.radians(90), rz)
        cyl("shaft", 0.04, 0.4, m, (0, 0, 0.2), parent=g)
        cyl("head", 0.09, 0.05, m, (0, 0, 0.0), parent=g, bevel=0.01)

def pipe(R):
    cyl("pipe", 0.12, 1.8, M("pipe", "#8E98A8", 0.38, 0.55), (0, 0, 0.9), parent=R)
    cyl("joint", 0.15, 0.15, M("pipe_j", "#6E7788", 0.4, 0.5), (0, 0, 1.75), parent=R)

def rope(R):
    m = M("rope", "#E5C063", 0.8)
    for i in range(4):
        torus("coil", 0.32 - i * 0.02, 0.06, m, (0, 0, 0.07 + i * 0.1), parent=R)
    tube("end", [(0.3, 0, 0.35), (0.45, -0.1, 0.25), (0.55, -0.25, 0.05)], 0.05, m, R)

def spring(R):
    pts = []
    for i in range(60):
        a = i / 60 * 6 * math.tau
        pts.append((math.cos(a) * 0.25, math.sin(a) * 0.25, i / 60 * 0.9))
    tube("spring", pts, 0.035, M("spring", "#B9C1CC", 0.35, 0.55), R)

def duct_tape(R):
    torus("tape", 0.3, 0.15, M("duct", "#9AA3B2", 0.4, 0.2), (0, 0, 0.15), (0, 0, 0), R, scale=(1, 1, 0.9))
    cyl("core", 0.16, 0.28, M("core", "#C8955E", 0.7), (0, 0, 0.15), parent=R)

def battery(R):
    cyl("bat", 0.2, 0.75, M("battery", "#2B303A", 0.35), (0, 0, 0.375), parent=R, bevel=0.02)
    cyl("band", 0.205, 0.25, M("battery_y", "#F2C14E", 0.35), (0, 0, 0.62), parent=R)
    cyl("tip", 0.07, 0.06, M("tin", "#C3CBD5", 0.35, 0.55), (0, 0, 0.78), parent=R)

def circuit(R):
    box("pcb", (0.6, 1.1, 0.05), M("pcb", "#2E7D4F", 0.45), (0, 0, 0.03), parent=R, bevel=0.01)
    for i in range(4):
        box("chip", (0.18, 0.14, 0.05), M("chip", "#1B1A22", 0.4), (-0.1 + (i % 2) * 0.22, -0.3 + i * 0.18, 0.08), parent=R, bevel=0.005)
    for i in range(6):
        box("trace", (0.4, 0.015, 0.005), M("trace", "#F2C14E", 0.3, 0.9), (0.05, -0.45 + i * 0.17, 0.06), parent=R)
    cyl("cap", 0.06, 0.15, M("capb", "#3E5C8A", 0.4), (0.2, 0.4, 0.13), parent=R)

def toy_mouse(R):
    sphere("body", 0.3, M("toy", "#9AA3B2", 0.6), (0, 0, 0.22), (1.3, 0.85, 0.75), parent=R)
    for sx in (-1, 1):
        sphere("ear", 0.1, M("toy_ear", "#F29BB0", 0.5), (-0.28, sx * 0.14, 0.4), (0.4, 1, 1), parent=R)
    sphere("nose", 0.04, M("toy_nose", "#F29BB0", 0.5), (-0.4, 0, 0.22), parent=R)
    tube("tail", [(0.38, 0, 0.18), (0.6, 0.1, 0.1), (0.7, -0.05, 0.05)], 0.02, M("toy_tail", "#F29BB0", 0.5), R)

def catnip(R):
    box("box", (1.2, 0.5, 0.5), M("catnip", "#5F8F4E", 0.5), (0, 0, 0.25), parent=R, bevel=0.04)
    box("win", (0.6, 0.02, 0.28), M("catnip_w", "#BFD9EC", 0.1, coat=1.0), (0, -0.255, 0.25), parent=R)
    for i in range(3):
        sphere("leaf", 0.09, M("leafc", "#9ED07D", 0.5), (-0.15 + i * 0.15, -0.24, 0.25), (1.6, 0.3, 0.8), parent=R)

def silver_bell(R):
    sphere("bell", 0.35, M("silver", "#C9D0D9", 0.3, 0.6), (0, 0, 0.35), parent=R)
    box("slot", (0.5, 0.02, 0.06), M("slot", "#3A3F4A", 0.4), (0, -0.33, 0.25), parent=R)
    torus("loop", 0.08, 0.025, M("silver", "#C9D0D9", 0.3, 0.6), (0, 0, 0.72), (math.radians(90), 0, 0), R)
    torus("ribbon", 0.36, 0.04, M("ribbon", "#D64545", 0.5), (0, 0, 0.62), parent=R, scale=(0.6, 0.6, 1))

def lucky_coin(R):
    cyl("coin", 0.4, 0.08, M("gold", "#F2C14E", 0.3, 0.7), (0, 0, 0.4), (math.radians(60), 0, math.radians(-20)), R, seg=48, bevel=0.015)
    cyl("emb", 0.24, 0.1, M("gold_d", "#D9A63A", 0.35, 0.6), (0, 0, 0.4), (math.radians(60), 0, math.radians(-20)), R, seg=48)

def old_camera(R):
    box("body", (0.9, 0.45, 0.6), M("cam", "#E8DCC8", 0.5), (0, 0, 0.3), parent=R, bevel=0.06)
    cyl("lens", 0.2, 0.2, M("lensb", "#2B303A", 0.3), (0, -0.28, 0.3), (math.radians(90), 0, 0), R, bevel=0.02)
    cyl("glass", 0.14, 0.05, M("lensg", "#3E5C8A", 0.05, coat=1.0), (0, -0.38, 0.3), (math.radians(90), 0, 0), R)
    box("flash", (0.2, 0.05, 0.1), M("flash", "#D64545", 0.4), (0.28, -0.23, 0.48), parent=R)

def gold_collar(R):
    torus("collar", 0.36, 0.07, M("gold", "#F2C14E", 0.2, 1.0), (0, 0, 0.12), (math.radians(20), 0, 0), R)
    sphere("gem", 0.1, M("gem", "#3FC1C9", 0.05, coat=1.0, emit=0.4), (0, -0.4, 0.0), parent=R)

def _bullets(R, color, shell=False, bolt=False):
    for i in range(3):
        x = -0.25 + i * 0.25
        if bolt:
            cyl("shaft", 0.03, 0.9, M("boltw", "#C9A27A", 0.6), (x, 0, 0.45), parent=R)
            cone("tip", 0.06, 0.15, M("steel", "#C9D1DA", 0.2, 1.0), (x, 0, 0.95), parent=R)
            box("fl", (0.14, 0.01, 0.15), M("fletch", "#D64545", 0.5), (x, 0, 0.1), parent=R)
        elif shell:
            cyl("case", 0.1, 0.45, M("shell", color, 0.4), (x, 0, 0.3), parent=R, bevel=0.01)
            cyl("brass", 0.105, 0.12, M("brass", "#D9A63A", 0.25, 1.0), (x, 0, 0.06), parent=R)
        else:
            cyl("case", 0.08, 0.35, M("brass", "#D9A63A", 0.25, 1.0), (x, 0, 0.175), parent=R)
            sphere("tip", 0.08, M("copper", "#C77B45", 0.3, 1.0), (x, 0, 0.36), (1, 1, 1.5), parent=R)

def sunflower_seed(R):
    dark = M("seed_d", "#2E2E34", 0.45, coat=0.3)
    light = M("seed_l", "#ECE6D8", 0.5)
    for i, (x, y, rz) in enumerate(((-0.22, 0.05, 20), (0.14, -0.06, -25), (0.0, 0.2, 75))):
        g = empty("sg%d" % i, (x, y, 0.1), R)
        g.rotation_euler = (0, 0, math.radians(rz))
        sphere("seed", 0.22, dark, (0, 0, 0), (0.5, 1.0, 0.32), parent=g)
        for k in (-1, 0, 1):
            sphere("str", 0.2, light, (k * 0.05, 0, 0.012), (0.06, 0.92, 0.3), parent=g)
    sphere("kernel", 0.12, M("kernel", "#F3E3B5", 0.6), (0.3, 0.22, 0.08), (0.5, 0.9, 0.35), parent=R)

def cheese(R):
    import bmesh
    me = bpy.data.meshes.new("cheese")
    bm = bmesh.new()
    pts = [(0, 0), (0.8, -0.3), (0.8, 0.3)]
    vs = [bm.verts.new((x - 0.4, y, z)) for z in (0.0, 0.45) for (x, y) in pts]
    bm.faces.new(vs[0:3][::-1]); bm.faces.new(vs[3:6])
    for i in range(3):
        j = (i + 1) % 3
        bm.faces.new((vs[i], vs[j], vs[j + 3], vs[i + 3]))
    bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new("cheese", me)
    link(ob, R)
    set_mat(ob, M("cheese", "#F6C445", 0.45, sss=0.1))
    bev = ob.modifiers.new("b", "BEVEL"); bev.width = 0.04; bev.segments = 3
    hole = M("cheese_h", "#D9A22E", 0.6)
    for (x, y, z, r) in ((0.15, -0.12, 0.45, 0.07), (0.25, 0.1, 0.45, 0.05), (0.0, 0.0, 0.45, 0.04), (0.2, -0.2, 0.25, 0.06)):
        sphere("hole", r, hole, (x, y, z), (1, 1, 0.3), parent=R)

def carrot_juice(R):
    box("pack", (0.42, 0.32, 0.7), M("cj", "#F2994A", 0.45), (0, 0, 0.35), parent=R, bevel=0.03)
    box("lbl", (0.43, 0.02, 0.3), M("cj_l", "#FFF3E2", 0.5), (0, -0.16, 0.35), parent=R)
    cone("carrot", 0.07, 0.25, M("carrot", "#E8742A", 0.5), (0, -0.18, 0.37), (math.radians(90), 0, 0), R)
    cyl("straw", 0.03, 0.4, M("straw", "#6CCB5F", 0.4), (0.1, 0, 0.85), (0, math.radians(15), 0), R)

def nut_mix(R):
    for i, (x, y) in enumerate(((-0.2, 0), (0.15, 0.1), (0.0, -0.18), (0.2, -0.15))):
        sphere("nut%d" % i, 0.18, M("nut", "#9B6A3C", 0.6), (x, y, 0.12), (1.0, 0.8, 0.7), parent=R)
        sphere("cap%d" % i, 0.16, M("nutcap", "#6B4428", 0.8), (x, y, 0.22), (1.0, 0.85, 0.35), parent=R)

ITEMS = {
    "canned_food": canned_food, "kibble": kibble, "churu": churu, "energy_drink": energy_drink,
    "bandage": bandage, "medkit": medkit, "screws": screws, "pipe": pipe, "rope": rope,
    "spring": spring, "duct_tape": duct_tape, "battery": battery, "circuit": circuit,
    "toy_mouse": toy_mouse, "catnip": catnip, "silver_bell": silver_bell, "lucky_coin": lucky_coin,
    "old_camera": old_camera, "gold_collar": gold_collar,
    "ammo_pistol": lambda R: _bullets(R, "#D9A63A"),
    "ammo_shell": lambda R: _bullets(R, "#D64545", shell=True),
    "ammo_bolt": lambda R: _bullets(R, "#C9A27A", bolt=True),
    "sunflower_seed": sunflower_seed, "cheese": cheese, "carrot_juice": carrot_juice, "nut_mix": nut_mix,
}

DIMS = {"kibble": (1, 2), "pipe": (1, 3), "circuit": (1, 2), "catnip": (2, 1), "medkit": (2, 2), "old_camera": (2, 2)}

def build_all(only=None):
    outdir = os.path.join(OUT, "items")
    os.makedirs(outdir, exist_ok=True)
    for name, fn in ITEMS.items():
        if only and name not in only:
            continue
        try:
            new_scene("MN_i_" + name)
            three_point((0, 0, 0.4), 0.7)
            R = empty("item_" + name)
            fn(R)
            objs = all_children(R)
            w, h = DIMS.get(name, (1, 1))
            cam = ortho_cam("CamI", (0, 0, 0.4), elev=35, azim=25, scale=2.0, res=(160 * w, 160 * h))
            fit_cam(cam, objs, 1.12)
            render(os.path.join(outdir, name + ".png"))
            log("OK item", name)
        except Exception:
            log("FAIL item", name, traceback.format_exc())
