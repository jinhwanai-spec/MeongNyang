# 맵 소품: 1 블렌더 단위 = 1 타일. 원점 = 바닥 중앙(앵커)
import math, os, random
from mathutils import Vector
from mn_lib import *
import mn_lib

PXP = 160  # px per tile (게임에서 0.3배 → 48px)

def M(name, hexc, rough=0.55, metal=0.0, **kw):
    return mat("p_" + name, hexc, rough, metal, **kw)

def goods(parent, x0, x1, y, z, depth=0.25, seed=0, dense=1.0):
    rnd = random.Random(seed)
    cols = ["#D64545", "#F2C14E", "#3FC1C9", "#5F8F4E", "#F29BB0", "#4A90E2", "#F2994A", "#EDE6D6"]
    x = x0
    while x < x1 - 0.06:
        w = rnd.uniform(0.07, 0.14)
        if rnd.random() < dense:
            h = rnd.uniform(0.1, 0.2)
            kind = rnd.random()
            c = M("g%d" % rnd.randint(0, 7), cols[rnd.randint(0, 7)], 0.5)
            if kind < 0.4:
                cyl("can", w * 0.45, h, c, (x + w / 2, y, z + h / 2), parent=parent, seg=16)
            else:
                box("pkg", (w * 0.9, depth * rnd.uniform(0.5, 0.9), h), c, (x + w / 2, y, z + h / 2), parent=parent, bevel=0.01)
        x += w + 0.015

def shelf(full=True, seed=1):
    root = empty("shelf")
    steel = M("shelf", "#9AA3B2", 0.35, 0.6)
    dark = M("shelf_d", "#5A616E", 0.4, 0.5)
    W, D, H = 0.94, 0.55, 1.15
    box("back", (W, 0.05, H), dark, (0, D / 2 - 0.03, H / 2), parent=root, bevel=0.01)
    for sx in (-1, 1):
        box("side", (0.05, D, H), steel, (sx * (W / 2 - 0.025), 0, H / 2), parent=root, bevel=0.015)
    for i, z in enumerate((0.08, 0.45, 0.82, H - 0.02)):
        box("plank", (W, D, 0.04), steel, (0, 0, z), parent=root, bevel=0.01)
        box("lip", (W, 0.03, 0.06), M("shelf_lip", "#F2994A", 0.5), (0, -D / 2 + 0.01, z + 0.02), parent=root, bevel=0.005)
        if z < H - 0.1:
            goods(root, -W / 2 + 0.06, W / 2 - 0.06, -0.02, z + 0.02, 0.32, seed * 10 + i, 0.95 if full else 0.25)
    return root

def fridge(lit=True):
    root = empty("fridge")
    W, D, H = 0.94, 0.66, 1.42
    frame = M("fridge", "#E8ECF0", 0.35)
    box("back", (W, 0.1, H), frame, (0, D / 2 - 0.05, H / 2), parent=root, bevel=0.02)
    for sx in (-1, 1):
        box("side", (0.08, D, H), frame, (sx * (W / 2 - 0.04), 0, H / 2), parent=root, bevel=0.02)
    box("top", (W, D, 0.18), M("fridge_sign", "#3E5C8A", 0.4), (0, 0, H - 0.09), parent=root, bevel=0.02)
    box("bottom", (W, D, 0.16), frame, (0, 0, 0.08), parent=root, bevel=0.02)
    inner = M("fridge_in", "#DDEEFF" if lit else "#2A3340", 0.4, emit=0.8 if lit else 0.0)
    box("inner", (W - 0.16, 0.04, H - 0.36), inner, (0, D / 2 - 0.12, H / 2), parent=root)
    rack = M("rack", "#9AA3B2", 0.3, 0.6)
    for z in (0.17, 0.5, 0.85):
        box("rack", (W - 0.16, D - 0.14, 0.02), rack, (0, 0, z), parent=root)
        if lit:
            goods(root, -W / 2 + 0.1, W / 2 - 0.1, -0.05, z + 0.01, 0.3, int(z * 10), 1.0)
    box("handle", (0.03, 0.04, 0.5), M("chrome", "#C9D1DA", 0.3, 0.7), (W / 2 - 0.06, -D / 2 - 0.02, H / 2), parent=root, bevel=0.01)
    return root

def counter(register=False):
    root = empty("counter")
    wood = M("counter", "#8A5A3B", 0.55)
    top = M("counter_top", "#C8B49A", 0.45)
    box("body", (1.0, 0.78, 0.62), wood, (0, 0, 0.31), parent=root, bevel=0.02)
    box("top", (1.04, 0.82, 0.06), top, (0, 0, 0.64), parent=root, bevel=0.015)
    box("stripe", (1.0, 0.02, 0.08), M("stripe_o", "#F2994A", 0.5), (0, -0.4, 0.45), parent=root)
    if register:
        reg = M("register", "#3B4252", 0.4, 0.3)
        box("reg", (0.5, 0.42, 0.22), reg, (0.05, 0.05, 0.78), parent=root, bevel=0.04)
        box("screen", (0.36, 0.06, 0.2), reg, (0.05, 0.15, 0.98), (math.radians(-20), 0, 0), root, bevel=0.02)
        box("lcd", (0.3, 0.01, 0.13), M("lcd", "#6CCB5F", 0.3, emit=1.5), (0.05, 0.115, 0.99), (math.radians(-20), 0, 0), root)
        for i in range(3):
            for j in range(3):
                box("key", (0.06, 0.06, 0.02), M("key", "#D8DEE6", 0.4), (-0.06 + i * 0.08, -0.08 + j * 0.07, 0.9), parent=root, bevel=0.01)
        box("drawer", (0.46, 0.06, 0.1), reg, (0.05, -0.2, 0.7), parent=root, bevel=0.015)
    return root

def cardboard(opened=False, seed=0):
    root = empty("box")
    c = M("cardboard", "#C8955E", 0.75)
    cd = M("cardboard_d", "#A87A48", 0.8)
    s = 0.62
    box("body", (s, s * 0.9, s * 0.78), c, (0, 0, s * 0.39), parent=root, bevel=0.015)
    tape = M("tape", "#E8D9B0", 0.5)
    if not opened:
        box("tape", (0.1, s * 0.92, 0.01), tape, (0, 0, s * 0.78 + 0.005), parent=root)
        box("tapeF", (0.1, 0.01, 0.16), tape, (0, -s * 0.45 - 0.005, s * 0.7), parent=root)
    else:
        box("hole", (s - 0.06, s * 0.9 - 0.06, 0.02), M("box_in", "#4A3420", 0.9), (0, 0, s * 0.78 - 0.005), parent=root)
        for sx in (-1, 1):
            box("flap", (s / 2, s * 0.86, 0.015), cd, (sx * (s / 2 + 0.12), 0, s * 0.78 + 0.08), (0, sx * math.radians(-55), 0), root)
    box("label", (0.18, 0.005, 0.12), M("label", "#EDE6D6", 0.6), (-0.12, -s * 0.45 - 0.004, s * 0.35), parent=root)
    return root

def crate_stack():
    root = empty("crates")
    w = M("crate", "#A8743F", 0.7)
    wd = M("crate_d", "#7E5530", 0.75)
    def crate(loc, s, rz=0):
        g = empty("crate", loc, root)
        g.rotation_euler = (0, 0, rz)
        box("c", (s, s, s), w, (0, 0, s / 2), parent=g, bevel=0.015)
        for sx in (-1, 1):
            box("plankV", (0.06, s + 0.01, s + 0.01), wd, (sx * (s / 2 - 0.03), 0, s / 2), parent=g)
            box("plankH", (s + 0.01, s + 0.01, 0.06), wd, (0, 0, s / 2 + sx * (s / 2 - 0.03)), parent=g)
        box("diag", (s * 1.2, 0.012, 0.06), wd, (0, -s / 2 - 0.006, s / 2), (0, math.radians(45), 0), g)
    crate((-0.17, 0.05, 0), 0.55, 0.1)
    crate((0.22, -0.08, 0), 0.48, -0.15)
    crate((0.0, 0.05, 0.55), 0.46, 0.2)
    return root

def trashcan(opened=False):
    root = empty("trash")
    g = M("trash", "#4E8A47", 0.5)
    gd = M("trash_d", "#3B6B36", 0.5)
    cyl("can", 0.3, 0.72, g, (0, 0, 0.36), parent=root, r2=0.34, bevel=0.01)
    for i in range(6):
        a = i / 6 * math.tau
        box("rib", (0.04, 0.04, 0.6), gd, (math.cos(a) * 0.32, math.sin(a) * 0.32, 0.36), (0, 0, a), root)
    if opened:
        lid = cyl("lid", 0.36, 0.06, gd, (0.32, -0.05, 0.62), (0, math.radians(75), 0), root, bevel=0.01)
        cyl("dark", 0.31, 0.01, M("trash_in", "#1E2A1C", 0.9), (0, 0, 0.72), parent=root)
    else:
        cyl("lid", 0.37, 0.07, gd, (0, 0, 0.76), parent=root, bevel=0.015)
        box("handle", (0.16, 0.04, 0.05), gd, (0, 0, 0.82), parent=root, bevel=0.015)
    return root

def dumpster(opened=False):
    root = empty("dumpster")
    g = M("dumpster", "#3E7A62", 0.45, 0.3)
    gd = M("dumpster_d", "#2C5A48", 0.45, 0.3)
    W, D, H = 1.9, 0.9, 0.95
    box("body", (W, D, H), g, (0.5, 0, H / 2 + 0.06), parent=root, bevel=0.03)
    for i in range(5):
        box("rib", (0.05, 0.04, H - 0.2), gd, (0.5 - W / 2 + 0.25 + i * 0.36, -D / 2 - 0.01, H / 2 + 0.05), parent=root)
    for x in (-0.3, 1.3):
        for y in (-0.3, 0.3):
            cyl("wheel", 0.06, 0.05, M("rubber", "#1B1D22", 0.8), (x, y, 0.06), (math.radians(90), 0, 0), root)
    if opened:
        box("lid", (W, 0.06, D * 0.9), gd, (0.5, D / 2 + 0.05, H + 0.45), (math.radians(-10), 0, 0), root, bevel=0.02)
        box("inside", (W - 0.1, D - 0.1, 0.02), M("dump_in", "#20262A", 0.9), (0.5, 0, H + 0.05), parent=root)
    else:
        box("lid", (W + 0.04, D + 0.04, 0.06), gd, (0.5, 0, H + 0.09), (math.radians(4), 0, 0), root, bevel=0.02)
    box("sticker", (0.5, 0.01, 0.2), M("recycle", "#F2C14E", 0.5), (0.5, -D / 2 - 0.02, H * 0.6), parent=root)
    return root

def vending(lit=True):
    root = empty("vending")
    red = M("vend", "#C0392B", 0.4)
    box("body", (0.92, 0.72, 1.5), red, (0, 0, 0.75), parent=root, bevel=0.04)
    win = M("vend_win", "#1A2030", 0.15, coat=1.0)
    box("win", (0.56, 0.04, 0.95), win, (-0.12, -0.36, 0.88), parent=root, bevel=0.01)
    if lit:
        for i in range(4):
            for j in range(3):
                c = ["#3FC1C9", "#F2C14E", "#EDE6D6", "#6CCB5F"][(i + j) % 4]
                cyl("bottle", 0.05, 0.16, M("b" + c, c, 0.3, emit=0.4), (-0.3 + j * 0.18, -0.33, 0.5 + i * 0.22), parent=root, seg=12)
    box("panel", (0.18, 0.04, 0.5), M("vend_panel", "#2B303A", 0.4), (0.32, -0.36, 1.0), parent=root, bevel=0.01)
    box("coin", (0.08, 0.02, 0.1), M("coin_slot", "#F2C14E", 0.3, 0.8), (0.32, -0.385, 0.95), parent=root)
    box("tray", (0.56, 0.06, 0.16), M("vend_tray", "#111318", 0.6), (-0.12, -0.36, 0.2), parent=root, bevel=0.01)
    box("sign", (0.86, 0.05, 0.16), M("vend_sign", "#FFF3E2", 0.4, emit=1.5 if lit else 0.0), (0, -0.36, 1.42), parent=root, bevel=0.01)
    return root

def plant():
    root = empty("plant")
    cyl("pot", 0.24, 0.36, M("pot", "#B5654A", 0.6), (0, 0, 0.18), parent=root, r2=0.3, bevel=0.01)
    cyl("soil", 0.27, 0.03, M("soil", "#3A2A1E", 0.9), (0, 0, 0.35), parent=root)
    leaf = M("leaf", "#4F8F3E", 0.5, sss=0.1)
    leaf2 = M("leaf2", "#6DB25A", 0.5, sss=0.1)
    rnd = random.Random(3)
    for i in range(9):
        a = i / 9 * math.tau + rnd.uniform(-0.2, 0.2)
        tilt = rnd.uniform(0.5, 0.9)
        L = rnd.uniform(0.3, 0.45)
        ob = sphere("leaf", 1.0, leaf if i % 2 else leaf2, (math.cos(a) * L * 0.5, math.sin(a) * L * 0.5, 0.38 + L * 0.55), (0.1, L * 0.45, 0.04), (tilt, 0, a + math.pi / 2), root, 16, 10)
    sphere("flower", 0.05, M("flower", "#F29BB0", 0.5), (0.08, -0.1, 0.78), parent=root)
    return root

def toolbox(opened=False):
    root = empty("toolbox")
    box("stand", (0.7, 0.5, 0.3), M("stand", "#5A616E", 0.4, 0.5), (0, 0, 0.15), parent=root, bevel=0.02)
    red = M("toolbox", "#D64545", 0.35, 0.3)
    box("box", (0.62, 0.34, 0.26), red, (0, 0, 0.43), parent=root, bevel=0.03)
    if opened:
        box("lid", (0.62, 0.04, 0.3), red, (0, 0.2, 0.68), (math.radians(-20), 0, 0), root, bevel=0.02)
        for i in range(3):
            box("tool", (0.4, 0.04, 0.04), M("tool", "#9AA3B2", 0.3, 0.9), (0, -0.05 + i * 0.06, 0.58), (0, 0, 0.3 * i), root)
    else:
        box("lid", (0.64, 0.36, 0.06), red, (0, 0, 0.58), parent=root, bevel=0.02)
        torus("handle", 0.12, 0.02, M("tb_handle", "#2B303A", 0.5), (0, 0, 0.62), (math.radians(90), 0, 0), root, arc=0.5)
    box("latch", (0.06, 0.02, 0.06), M("latch", "#C9D1DA", 0.3, 1.0), (0, -0.18, 0.5), parent=root)
    return root

def medcab(opened=False):
    root = empty("medcab")
    white = M("medcab", "#F3EEE6", 0.4)
    box("body", (0.82, 0.5, 1.2), white, (0, 0, 0.6), parent=root, bevel=0.03)
    redm = M("cross", "#D64545", 0.4)
    if opened:
        box("door", (0.4, 0.04, 1.0), white, (0.62, -0.3, 0.62), (0, 0, math.radians(-60)), root, bevel=0.02)
        box("in", (0.72, 0.02, 1.04), M("medcab_in", "#C9D1DA", 0.6), (0, -0.25, 0.62), parent=root)
    else:
        box("crossV", (0.1, 0.02, 0.32), redm, (0, -0.255, 0.75), parent=root)
        box("crossH", (0.32, 0.02, 0.1), redm, (0, -0.255, 0.75), parent=root)
        box("seam", (0.01, 0.02, 1.0), M("seam", "#C9D1DA", 0.5), (0, -0.252, 0.62), parent=root)
    return root

def locker(opened=False):
    root = empty("locker")
    bl = M("locker", "#6E7C93", 0.4, 0.4)
    bd = M("locker_d", "#4C586B", 0.4, 0.4)
    box("body", (0.86, 0.56, 1.55), bl, (0, 0, 0.78), parent=root, bevel=0.02)
    for sx in (-1, 1):
        if opened and sx == 1:
            box("door", (0.42, 0.03, 1.4), bl, (0.62, -0.38, 0.78), (0, 0, math.radians(-70)), root, bevel=0.01)
            box("dark", (0.38, 0.01, 1.4), M("locker_in", "#1E232C", 0.9), (0.21, -0.28, 0.78), parent=root)
            continue
        box("door", (0.4, 0.02, 1.42), bl, (sx * 0.21, -0.285, 0.78), parent=root, bevel=0.01)
        for k in range(4):
            box("vent", (0.22, 0.015, 0.025), bd, (sx * 0.21, -0.3, 1.3 + k * 0.05), parent=root)
        box("knob", (0.04, 0.03, 0.08), M("knob", "#F2C14E", 0.3, 0.8), (sx * 0.05, -0.3, 0.8), parent=root)
    return root

def generator():
    root = empty("generator")
    y = M("gen", "#F2C14E", 0.4, 0.2)
    box("frame", (0.86, 0.66, 0.06), M("gen_frame", "#2B303A", 0.4, 0.6), (0, 0, 0.03), parent=root)
    box("body", (0.8, 0.6, 0.62), y, (0, 0, 0.38), parent=root, bevel=0.06)
    box("grill", (0.5, 0.02, 0.3), M("grill", "#2B303A", 0.5), (-0.1, -0.31, 0.38), parent=root)
    cyl("tank", 0.14, 0.5, M("tank", "#D64545", 0.35), (0.0, 0.12, 0.78), (0, math.radians(90), 0), root)
    cyl("muffler", 0.05, 0.3, M("muffler", "#5A606B", 0.4, 0.8), (0.32, 0.2, 0.75), parent=root)
    box("panelG", (0.18, 0.02, 0.14), M("gen_panel", "#1B1D22", 0.4), (0.25, -0.31, 0.5), parent=root)
    sphere("lamp", 0.03, M("gen_lamp", "#D64545", 0.3, emit=2.0), (0.25, -0.33, 0.5), parent=root)
    return root

def car(seed=0):
    root = empty("car")
    col = ["#B5523B", "#3E5C8A", "#7A8A6A"][seed % 3]
    body = M("car%d" % seed, col, 0.35, 0.2, coat=0.5)
    glass = M("car_glass", "#2B3A4A", 0.1, coat=1.0)
    box("body", (1.85, 0.85, 0.45), body, (0.5, 0, 0.42), parent=root, bevel=0.14, sub=1)
    box("cabin", (1.05, 0.78, 0.42), body, (0.42, 0.0, 0.8), parent=root, bevel=0.14, sub=1)
    box("winF", (0.02, 0.66, 0.3), glass, (0.95, 0, 0.8), (0, math.radians(-25), 0), root)
    box("winS", (0.85, 0.02, 0.26), glass, (0.42, -0.4, 0.82), parent=root, bevel=0.03)
    for x in (-0.05, 1.05):
        for y in (-0.38, 0.38):
            cyl("tire", 0.2, 0.16, M("tire", "#1B1D22", 0.8), (x, y, 0.2), (math.radians(90), 0, 0), root, bevel=0.03)
    sphere("lightF", 0.06, M("headlight", "#FFF3C4", 0.2, emit=0.5), (1.42, -0.25, 0.45), parent=root)
    sphere("rust", 0.18, M("rust", "#8A5A3B", 0.9), (0.0, -0.36, 0.5), (1.4, 0.3, 0.8), parent=root)
    sphere("moss", 0.16, M("moss", "#5F8F4E", 0.9), (1.2, -0.36, 0.3), (1.4, 0.3, 0.6), parent=root)
    return root

def fence():
    root = empty("fence")
    post = M("post", "#5A606B", 0.4, 0.8)
    for x in (-0.5, 0.5):
        cyl("post", 0.04, 1.2, post, (x, 0, 0.6), parent=root)
    cyl("rail", 0.025, 1.0, post, (0, 0, 1.15), (0, math.radians(90), 0), root)
    wire = M("wire", "#9AA3B2", 0.35, 0.9)
    for i in range(-5, 6):
        x = i * 0.1
        tube("w1", [(x - 0.25, 0, 0.05), (x + 0.25, 0, 1.12)], 0.006, wire, root, smooth_curve=False)
        tube("w2", [(x + 0.25, 0, 0.05), (x - 0.25, 0, 1.12)], 0.006, wire, root, smooth_curve=False)
    return root

def barrel(color="#C0392B"):
    root = empty("barrel")
    m = M("barrel" + color, color, 0.4, 0.3)
    cyl("b", 0.3, 0.86, m, (0, 0, 0.43), parent=root, bevel=0.02)
    for z in (0.2, 0.66):
        torus("ring", 0.305, 0.02, m, (0, 0, z), parent=root)
    cyl("cap", 0.06, 0.02, M("cap", "#2B303A", 0.4), (0.12, 0.05, 0.87), parent=root)
    return root

def sandbags():
    root = empty("sandbags")
    m = M("sand", "#B8A27A", 0.85)
    for row in range(2):
        for i in range(3 - row):
            x = -0.42 + i * 0.42 + row * 0.21
            box("bag", (0.42, 0.34, 0.2), m, (x, 0, 0.11 + row * 0.19), parent=root, bevel=0.08, sub=1)
    return root

def cone_prop():
    root = empty("cone")
    o = M("cone", "#F2994A", 0.45)
    box("base", (0.4, 0.4, 0.04), o, (0, 0, 0.02), parent=root, bevel=0.02)
    cone("c", 0.16, 0.6, o, (0, 0, 0.34), parent=root, r2=0.03)
    cyl("stripe", 0.115, 0.08, M("cone_w", "#F3EEE6", 0.4), (0, 0, 0.36), parent=root, r2=0.095)
    return root

PROPS = {
    "shelf": lambda: shelf(True, 1), "shelf_empty": lambda: shelf(False, 2),
    "fridge": lambda: fridge(True), "fridge_off": lambda: fridge(False),
    "counter": lambda: counter(False), "register": lambda: counter(True),
    "box": lambda: cardboard(False), "box_open": lambda: cardboard(True),
    "crates": crate_stack,
    "trash": lambda: trashcan(False), "trash_open": lambda: trashcan(True),
    "dumpster": lambda: dumpster(False), "dumpster_open": lambda: dumpster(True),
    "vending": lambda: vending(True), "vending_off": lambda: vending(False),
    "plant": plant,
    "toolbox": lambda: toolbox(False), "toolbox_open": lambda: toolbox(True),
    "medcab": lambda: medcab(False), "medcab_open": lambda: medcab(True),
    "locker": lambda: locker(False), "locker_open": lambda: locker(True),
    "generator": generator,
    "car0": lambda: car(0), "car1": lambda: car(1), "car2": lambda: car(2),
    "fence": fence,
    "barrel_red": lambda: barrel("#C0392B"), "barrel_blue": lambda: barrel("#3E6FB0"),
    "sandbags": sandbags, "cone": cone_prop,
}

def build_all(only=None):
    meta = load_meta()
    outdir = os.path.join(OUT, "props")
    os.makedirs(outdir, exist_ok=True)
    for name, fn in PROPS.items():
        if only and name not in only:
            continue
        try:
            new_scene("MN_p_" + name)
            three_point((0, 0, 0.5), 0.8)
            root = fn()
            objs = all_children(root)
            cam = ortho_cam("CamP", (0, 0, 0.5), elev=55, scale=2.0, res=(256, 256))
            fit_cam(cam, objs, 1.06, px_per_unit=PXP)
            render(os.path.join(outdir, name + ".png"))
            meta["prop_" + name] = {"anchor": project(cam, (0, 0, 0)), "size": [mn_lib.SCN.render.resolution_x, mn_lib.SCN.render.resolution_y], "px": PXP, "elev": 55}
            save_source("prop_" + name, objs)
            log("OK prop", name)
        except Exception:
            log("FAIL prop", name, traceback.format_exc())
    save_meta(meta)
