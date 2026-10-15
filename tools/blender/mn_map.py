# 맵 전체를 3D로 만들어 한 장의 배경으로 렌더 (바닥·벽·조명·그림자 베이크)
# 1 블렌더 단위 = 1 타일. 지도 열 x → X = x, 행 y → Y = -y
import bpy, bmesh, math, os, re, json
from mathutils import Vector
from mn_lib import *
from mn_lib import _set
import mn_lib

ELEV = 55.0
WALL_H = 1.8   # 햄스터 눈높이에서 본 인간 세계의 벽 (2.5D 가림용으로 높게)
SOLID = "#SsFQCRBTVPKMLGoXDHf"

def read_map():
    p = os.path.join(ROOT, "scripts", "raid", "level_data.gd")
    txt = open(p, encoding="utf-8").read()
    block = txt[txt.index("const MAP := ["):txt.index("]", txt.index("const MAP := ["))]
    return re.findall(r'"([^"]*)"', block)

MAP = []

def code(x, y):
    if y < 0 or y >= len(MAP) or x < 0 or x >= len(MAP[0]):
        return "#"
    return MAP[y][x]

FLOOR_UNDER = {"S": "_", "s": "_", "F": "_", "Q": "_", "C": "_", "R": "_", "M": "_", "L": "_", "V": "_",
               "B": "", "T": "", "D": "", "P": "", "K": "", "o": "", "X": ".", "f": "", "G": "=", "H": ",",
               "p": "g", "h": ".", "b": "", "c": "", "1": ".", "2": ","}

def floor_code(x, y):
    c = code(x, y)
    if c in FLOOR_UNDER:
        u = FLOOR_UNDER[c]
        if u:
            return u
        for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1), (-1, -1), (1, 1)):
            n = code(x + dx, y + dy)
            if n in ".,_=gm":
                return n
            if n in "w-":
                return "."
        return ","
    return c

def wall_style(x, y):
    for dx, dy in ((0, 1), (0, -1), (1, 0), (-1, 0)):
        n = code(x + dx, y + dy)
        if n == "_" or n in "SsFQCRMLV":
            return "store"
        if n in "=GK":
            return "storage"
    return "concrete"

# ── 재질 ───────────────────────────────────────────
def node_mat(name, build):
    m = bpy.data.materials.new(name)
    try:
        m.use_nodes = True
    except Exception:
        pass
    nt = m.node_tree
    b = nt.nodes.get("Principled BSDF")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    build(nt, b, tc.outputs["Object"])
    return m

def brick(nt, vec, c1, c2, mortar, w, h, mortar_size=0.02, offset=0.5, scale=1.0):
    br = nt.nodes.new("ShaderNodeTexBrick")
    br.offset = offset
    br.inputs["Color1"].default_value = hex_lin(c1) + [1]
    br.inputs["Color2"].default_value = hex_lin(c2) + [1]
    br.inputs["Mortar"].default_value = hex_lin(mortar) + [1]
    br.inputs["Scale"].default_value = scale
    br.inputs["Mortar Size"].default_value = mortar_size
    br.inputs["Brick Width"].default_value = w
    br.inputs["Row Height"].default_value = h
    if "Mortar Smooth" in br.inputs:
        br.inputs["Mortar Smooth"].default_value = 0.2
    nt.links.new(vec, br.inputs["Vector"])
    return br

def noise_mix(nt, vec, base, var, scale=3.0, amt=0.5):
    nz = nt.nodes.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = scale
    nt.links.new(vec, nz.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = hex_lin(base) + [1]
    ramp.color_ramp.elements[1].color = hex_lin(var) + [1]
    ramp.color_ramp.elements[0].position = 0.5 - amt * 0.5
    ramp.color_ramp.elements[1].position = 0.5 + amt * 0.5
    nt.links.new(nz.outputs["Fac"], ramp.inputs["Fac"])
    return ramp

def materials():
    M = {}
    def asphalt(nt, b, v):
        r = noise_mix(nt, v, "#2B2F37", "#40454F", 3.5, 0.5)
        nt.links.new(r.outputs["Color"], b.inputs["Base Color"])
        b.inputs["Roughness"].default_value = 0.85
    M["."] = node_mat("map_asphalt", asphalt)
    def side(nt, b, v):
        br = brick(nt, v, "#5E636D", "#676C76", "#3E424A", 0.5, 0.5, 0.025, 0.5)
        nt.links.new(br.outputs["Color"], b.inputs["Base Color"])
        b.inputs["Roughness"].default_value = 0.8
    M[","] = node_mat("map_sidewalk", side)
    def store(nt, b, v):
        br = brick(nt, v, "#C49A72", "#B48A64", "#7A5A42", 0.5, 0.5, 0.025, 0.0)
        nt.links.new(br.outputs["Color"], b.inputs["Base Color"])
        b.inputs["Roughness"].default_value = 0.38
        _set(b, ["Coat Weight"], 0.25)
    M["_"] = node_mat("map_store", store)
    def wood(nt, b, v):
        br = brick(nt, v, "#6E5641", "#5E4936", "#3A2C20", 1.0, 0.25, 0.015, 0.35)
        nt.links.new(br.outputs["Color"], b.inputs["Base Color"])
        b.inputs["Roughness"].default_value = 0.6
    M["="] = node_mat("map_wood", wood)
    def grass(nt, b, v):
        r = noise_mix(nt, v, "#3F6B34", "#5C8A45", 6.0, 0.7)
        nt.links.new(r.outputs["Color"], b.inputs["Base Color"])
        b.inputs["Roughness"].default_value = 0.9
    M["g"] = node_mat("map_grass", grass)
    def mud(nt, b, v):
        r = noise_mix(nt, v, "#33271C", "#6A5238", 1.6, 0.35)
        r2 = noise_mix(nt, v, "#000000", "#FFFFFF", 9.0, 0.5)
        mix = nt.nodes.new("ShaderNodeMix"); mix.data_type = "RGBA"; mix.blend_type = "OVERLAY"
        mix.inputs[0].default_value = 0.35
        nt.links.new(r.outputs["Color"], mix.inputs[6]); nt.links.new(r2.outputs["Color"], mix.inputs[7])
        nt.links.new(mix.outputs[2], b.inputs["Base Color"])
        b.inputs["Roughness"].default_value = 0.45
        _set(b, ["Coat Weight"], 0.15)
    M["m"] = node_mat("map_mud", mud)
    # 벽 옆면: (X+Y, Z) 좌표로 무늬를 세우고, 바닥쪽은 어둡게·윗단은 밝은 몰딩으로 높이감을 준다
    def wall_side(kind):
        def build(nt, b, v):
            sep = nt.nodes.new("ShaderNodeSeparateXYZ"); nt.links.new(v, sep.inputs[0])
            add = nt.nodes.new("ShaderNodeMath"); add.operation = "ADD"
            nt.links.new(sep.outputs[0], add.inputs[0]); nt.links.new(sep.outputs[1], add.inputs[1])
            cmb = nt.nodes.new("ShaderNodeCombineXYZ")
            nt.links.new(add.outputs[0], cmb.inputs[0]); nt.links.new(sep.outputs[2], cmb.inputs[1])
            vec = cmb.outputs[0]
            if kind == "store":
                pat = brick(nt, vec, "#E3D6BF", "#D8CAB0", "#A8987E", 0.5, 0.18, 0.012, 0.5)
                base, cap = "#8A3B2E", "#F2994A"
            elif kind == "storage":
                wv = nt.nodes.new("ShaderNodeTexWave"); wv.inputs["Scale"].default_value = 3.0
                nt.links.new(vec, wv.inputs["Vector"])
                pat = nt.nodes.new("ShaderNodeValToRGB")
                pat.color_ramp.elements[0].color = hex_lin("#4A5A70") + [1]
                pat.color_ramp.elements[1].color = hex_lin("#7486A0") + [1]
                nt.links.new(wv.outputs["Fac"], pat.inputs["Fac"])
                base, cap = "#2E3540", "#F2C14E"
            else:
                pat = brick(nt, vec, "#6B7280", "#636A77", "#4A505B", 1.2, 0.6, 0.02, 0.5)
                base, cap = "#2B2F37", "#8A919E"
            col = pat.outputs["Color"]
            # 얼룩
            gr = noise_mix(nt, v, "#FFFFFF", "#9A9088", 2.2, 0.6)
            m1 = nt.nodes.new("ShaderNodeMix"); m1.data_type = "RGBA"; m1.blend_type = "MULTIPLY"
            m1.inputs[0].default_value = 0.35
            nt.links.new(col, m1.inputs[6]); nt.links.new(gr.outputs["Color"], m1.inputs[7])
            col = m1.outputs[2]
            # 걸레받이 (z < 0.14)
            lt = nt.nodes.new("ShaderNodeMath"); lt.operation = "LESS_THAN"; lt.inputs[1].default_value = 0.14
            nt.links.new(sep.outputs[2], lt.inputs[0])
            m2 = nt.nodes.new("ShaderNodeMix"); m2.data_type = "RGBA"
            nt.links.new(lt.outputs[0], m2.inputs[0]); nt.links.new(col, m2.inputs[6]); m2.inputs[7].default_value = hex_lin(base) + [1]
            col = m2.outputs[2]
            # 윗단 몰딩 (z > WALL_H - 0.08)
            gt = nt.nodes.new("ShaderNodeMath"); gt.operation = "GREATER_THAN"; gt.inputs[1].default_value = WALL_H - 0.08
            nt.links.new(sep.outputs[2], gt.inputs[0])
            m3 = nt.nodes.new("ShaderNodeMix"); m3.data_type = "RGBA"
            nt.links.new(gt.outputs[0], m3.inputs[0]); nt.links.new(col, m3.inputs[6]); m3.inputs[7].default_value = hex_lin(cap) + [1]
            col = m3.outputs[2]
            # 바닥 접지 그림자: 아래로 갈수록 어둡게
            mr = nt.nodes.new("ShaderNodeMapRange")
            mr.inputs[1].default_value = 0.0; mr.inputs[2].default_value = 0.9
            mr.inputs[3].default_value = 0.55; mr.inputs[4].default_value = 1.0
            nt.links.new(sep.outputs[2], mr.inputs[0])
            m4 = nt.nodes.new("ShaderNodeMix"); m4.data_type = "RGBA"; m4.blend_type = "MULTIPLY"
            m4.inputs[0].default_value = 1.0
            cr = nt.nodes.new("ShaderNodeCombineXYZ")
            for k in range(3):
                nt.links.new(mr.outputs[0], cr.inputs[k])
            nt.links.new(col, m4.inputs[6]); nt.links.new(cr.outputs[0], m4.inputs[7])
            nt.links.new(m4.outputs[2], b.inputs["Base Color"])
            b.inputs["Roughness"].default_value = 0.75
        return build
    def wall_top(c1, c2):
        def build(nt, b, v):
            r = noise_mix(nt, v, c1, c2, 4.0, 0.6)
            nt.links.new(r.outputs["Color"], b.inputs["Base Color"])
            b.inputs["Roughness"].default_value = 0.8
        return build
    M["wall_store_top"] = node_mat("wall_store_top", wall_top("#EDE3D0", "#D2C6B0"))
    M["wall_store"] = node_mat("wall_store", wall_side("store"))
    M["wall_storage_top"] = node_mat("wall_storage_top", wall_top("#8794A8", "#6F7C90"))
    M["wall_storage"] = node_mat("wall_storage", wall_side("storage"))
    M["wall_concrete_top"] = node_mat("wall_concrete_top", wall_top("#7A818D", "#636A76"))
    M["wall_concrete"] = node_mat("wall_concrete", wall_side("concrete"))
    def roof(nt, b, v):
        br = brick(nt, v, "#8E939C", "#858A94", "#5E636C", 2.0, 2.0, 0.03, 0.0)
        nt.links.new(br.outputs["Color"], b.inputs["Base Color"])
        b.inputs["Roughness"].default_value = 0.9
    M["roof"] = node_mat("map_roof", roof)
    M["puddle"] = mat("puddle", "#2E3A4C", 0.02, coat=1.0, emit=0.05)
    M["lane"] = mat("lane", "#C9A43A", 0.6)
    M["white_line"] = mat("white_line", "#C8CCD2", 0.6)
    M["glass"] = mat("window_glass", "#8FB8D8", 0.05, coat=1.0, emit=0.25)
    M["trim"] = mat("trim_orange", "#F2994A", 0.5)
    return M

# ── 지오메트리 ─────────────────────────────────────
def build_floor(M):
    W, H = len(MAP[0]), len(MAP)
    keys = [".", ",", "_", "=", "g", "m"]
    bm = bmesh.new()
    for y in range(H):
        for x in range(W):
            c = code(x, y)
            if c == "#":
                continue
            fc = floor_code(x, y)
            if fc in "w-1":
                fc = "."
                if c == "w" and sum(code(x + dx, y + dy) == "m" for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))) >= 2:
                    fc = "m"
            if fc not in keys:
                fc = ","
            vs = [bm.verts.new((x, -y - 1, 0)), bm.verts.new((x + 1, -y - 1, 0)), bm.verts.new((x + 1, -y, 0)), bm.verts.new((x, -y, 0))]
            f = bm.faces.new(vs)
            f.material_index = keys.index(fc)
    me = bpy.data.meshes.new("floor")
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("floor", me)
    link(ob)
    for k in keys:
        me.materials.append(M[k])
    # 물웅덩이·차선·횡단보도·주차선
    for y in range(H):
        for x in range(W):
            c = code(x, y)
            if c == "w":
                o = sphere("puddle", 0.42, M["puddle"], (x + 0.5, -y - 0.5, 0.0), (1.1, 0.8, 0.02))
            elif c == "-":
                box("lane", (0.7, 0.12, 0.01), M["lane"], (x + 0.5, -y - 0.5, 0.005))
    # 화단 연석 (잔디 칸 가장자리)
    curb = mat("curb", "#9A9EA6", 0.7)
    for y in range(H):
        for x in range(W):
            if code(x, y) == "#" or floor_code(x, y) != "g":
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if code(nx, ny) != "#" and floor_code(nx, ny) != "g":
                    if dx:
                        box("curb", (0.1, 1.0, 0.12), curb, (x + 0.5 + dx * 0.47, -y - 0.5, 0.06))
                    else:
                        box("curb", (1.0, 0.1, 0.12), curb, (x + 0.5, -y - 0.5 - dy * 0.47, 0.06))
    for i in range(6):
        box("cross", (1.6, 0.42, 0.01), M["white_line"], (29.0, -(20 + i) - 0.5, 0.005))
    for i in range(6):
        box("park", (0.06, 2.6, 0.01), M["white_line"], (39 + i * 3, -14.3, 0.005))

def build_walls(M):
    W, H = len(MAP[0]), len(MAP)
    groups = {}
    for y in range(H):
        for x in range(W):
            if code(x, y) != "#":
                continue
            all_wall = all(code(x + dx, y + dy) == "#" for dx in (-1, 0, 1) for dy in (-1, 0, 1))
            style = "roof" if all_wall else wall_style(x, y)
            h = WALL_H
            # 편의점 정면 유리창 (16행)
            if style == "store" and y == 16 and 9 <= x <= 36 and x != 30:
                h = 0.32
                box("glass", (1.0, 0.12, WALL_H - 0.36), M["glass"], (x + 0.5, -y - 0.5, 0.32 + (WALL_H - 0.36) / 2))
                box("mullion", (0.06, 0.16, WALL_H - 0.3), M["wall_store"], (x + 0.03, -y - 0.5, 0.32 + (WALL_H - 0.3) / 2))
            groups.setdefault(style, []).append((x, y, h))
    for style, cells in groups.items():
        bm = bmesh.new()
        for (x, y, h) in cells:
            r = bmesh.ops.create_cube(bm, size=1.0)
            for v in r["verts"]:
                v.co = Vector((x + 0.5 + v.co.x, -y - 0.5 + v.co.y, (v.co.z + 0.5) * h))
        for f in bm.faces:
            f.material_index = 0 if f.normal.z > 0.5 else 1
        me = bpy.data.meshes.new("walls_" + style)
        bm.to_mesh(me)
        bm.free()
        ob = bpy.data.objects.new("walls_" + style, me)
        link(ob)
        if style == "roof":
            me.materials.append(M["roof"])
            me.materials.append(M["wall_concrete"])
        else:
            me.materials.append(M["wall_%s_top" % style])
            me.materials.append(M["wall_%s" % style])
    # 편의점 외벽 주황 띠
    for x in range(8, 38):
        if code(x, 16) == "#" and code(x, 17) != "#":
            box("trim", (1.0, 0.02, 0.06), M["trim"], (x + 0.5, -16 - 1.01, 0.22))

def build_dressing(M):
    # 가로등은 게임에서 시트 스프라이트로 배치 (여기선 생략)
    # 옥상 실외기·환풍구 (지붕 디테일)
    W, H = len(MAP[0]), len(MAP)
    ac = mat("ac_unit", "#C9CED6", 0.5)
    acd = mat("ac_dark", "#3A3F48", 0.6)
    import random
    rnd = random.Random(7)
    for y in range(H):
        for x in range(W):
            if code(x, y) == "#" and all(code(x + dx, y + dy) == "#" for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
                r = rnd.random()
                if r < 0.06 and x % 2 == 0:
                    box("walls_ac", (1.3, 0.8, 0.4), ac, (x + 1.0, -y - 0.5, WALL_H + 0.2), bevel=0.05)
                    cyl("walls_fan", 0.28, 0.03, acd, (x + 0.75, -y - 0.5, WALL_H + 0.41))
                    box("walls_grille", (0.4, 0.6, 0.02), acd, (x + 1.35, -y - 0.5, WALL_H + 0.41))
    # 맨홀 (탈출구 A)
    cyl("manhole", 0.75, 0.03, mat("manhole", "#4A505E", 0.35, 0.7), (54.0, -36.0, 0.015))
    for i in range(5):
        box("grate", (1.1, 0.06, 0.04), mat("manhole_d", "#2A2F3A", 0.5, 0.5), (54.0, -35.6 - i * 0.2, 0.03))
    # 하역장 트럭 (탈출구 B)
    truck = mat("truck", "#D8DEE6", 0.4)
    box("cargo", (2.2, 1.6, 1.3), truck, (54.4, -6.0, 0.8), bevel=0.06)
    box("cab", (1.0, 1.5, 1.0), mat("truck_cab", "#3E5C8A", 0.35, coat=0.4), (54.4, -8.0, 0.65), bevel=0.1)
    box("cabwin", (0.9, 0.02, 0.4), mat("truck_win", "#2B3A4A", 0.1, coat=1.0), (54.4, -8.76, 0.85))
    for yy in (-5.2, -6.8, -7.8):
        for xx in (53.6, 55.2):
            cyl("wheel", 0.22, 0.18, mat("tire2", "#1B1D22", 0.8), (xx, yy, 0.22), (0, math.radians(90), 0))
    # 네온 간판
    try:
        fnt = bpy.data.fonts.load(r"C:\Windows\Fonts\malgunbd.ttf", check_existing=True)
    except Exception:
        fnt = None
    box("signboard", (6.4, 0.12, 0.52), mat("signboard", "#2A2238", 0.5), (22.0, -17.08, 0.42))
    box("signrim", (6.6, 0.1, 0.6), mat("neon_rim", "#FF7FB0", 0.3, emit=3.0), (22.0, -17.03, 0.42))
    cu = bpy.data.curves.new("sign", "FONT")
    cu.body = "멍냥마트 24"
    if fnt:
        cu.font = fnt
    cu.size = 0.4
    cu.align_x = "CENTER"
    cu.extrude = 0.01
    ob = bpy.data.objects.new("sign", cu)
    link(ob)
    ob.location = (22.0, -17.16, 0.3)
    ob.rotation_euler = (math.radians(90), 0, 0)
    cu.materials.append(mat("neon_pink", "#FF7FB0", 0.3, emit=8.0))

def build_lights():
    def pl(name, loc, energy, color, radius=0.3):
        ld = bpy.data.lights.new(name, "POINT")
        ld.energy = energy
        ld.color = color
        ld.shadow_soft_size = radius
        ob = bpy.data.objects.new(name, ld)
        link(ob)
        ob.location = loc
    def al(name, loc, energy, color, size):
        ld = bpy.data.lights.new(name, "AREA")
        ld.energy = energy
        ld.color = color
        ld.size = size
        ob = bpy.data.objects.new(name, ld)
        link(ob)
        ob.location = loc
    # 달빛
    sd = bpy.data.lights.new("moon", "SUN")
    sd.energy = 3.6
    sd.color = (1.0, 0.93, 0.82)
    sd.angle = math.radians(3)
    so = bpy.data.objects.new("moon", sd)
    link(so)
    so.rotation_euler = (math.radians(38), math.radians(-28), math.radians(-30))
    # 편의점 실내 (따뜻한 형광등)
    for cx in (12, 18, 24, 30, 35):
        for cy in (6, 12):
            al("store_light", (cx, -cy, 3.2), 90, (1.0, 0.84, 0.64), 6.0)
    # 창고 (차가운 빛)
    for cx in (41, 47):
        al("storage_light", (cx, -7, 3.0), 90, (0.75, 0.82, 1.0), 5.0)
    # 가로등
    for lx in (6, 17, 33, 45, 54):
        pass
    pl("neon", (22.0, -17.6, 1.2), 60, (1.0, 0.45, 0.7), 1.0)
    pl("exitA", (54.0, -36.0, 1.0), 40, (0.5, 1.0, 0.55), 0.5)
    pl("exitB", (54.0, -6.0, 2.0), 40, (1.0, 0.5, 0.45), 0.5)
    pl("alley", (20, -33, 1.4), 45, (1.0, 0.7, 0.45), 0.3)
    pl("alley2", (42, -33, 1.4), 40, (0.7, 0.8, 1.0), 0.3)

def build(px_per_tile=96):
    global MAP
    MAP = read_map()
    W, H = len(MAP[0]), len(MAP)
    new_scene("MN_map")
    mn_lib.SCN.world.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.65, 0.85, 1)
    mn_lib.SCN.world.node_tree.nodes["Background"].inputs[1].default_value = 0.7
    try:
        mn_lib.SCN.eevee.taa_render_samples = 32
        mn_lib.SCN.eevee.use_shadows = True
        mn_lib.SCN.eevee.shadow_ray_count = 2
    except Exception:
        pass
    M = materials()
    build_floor(M)
    build_walls(M)
    build_dressing(M)
    build_lights()
    cam = ortho_cam("CamMap", (W / 2, -H / 2, 0), elev=ELEV, scale=W, res=(W * px_per_tile, 100))
    objs = [o for o in mn_lib.SCN.collection.all_objects if o.type in ("MESH",)]
    fit_cam(cam, objs, 1.0, px_per_unit=px_per_tile)
    out = os.path.join(OUT, "map")
    os.makedirs(out, exist_ok=True)
    render(os.path.join(out, "map.png"))
    # 가림 레이어: 벽만 남기고(바닥·장식은 홀드아웃) 투명 배경으로 한 번 더
    keep = ("walls_", "glass", "mullion", "trim")
    for ob in mn_lib.SCN.collection.all_objects:
        if ob.type == "MESH" and not ob.name.startswith(keep):
            ob.is_holdout = True
    mn_lib.SCN.render.film_transparent = True
    mn_lib.SCN.render.image_settings.color_mode = "RGBA"
    render(os.path.join(out, "walls.png"))
    mn_lib.SCN.render.film_transparent = False
    meta = load_meta()
    meta["map"] = {
        "size": [mn_lib.SCN.render.resolution_x, mn_lib.SCN.render.resolution_y],
        "tl": project(cam, (0, 0, 0)), "tr": project(cam, (W, 0, 0)),
        "bl": project(cam, (0, -H, 0)), "br": project(cam, (W, -H, 0)),
        "tiles": [W, H], "elev": ELEV, "wall_h": WALL_H,
    }
    save_meta(meta)
    log("OK map", meta["map"]["size"])

def build_floor_top(px_per_tile=64):
    """3D 게임용: 벽 없이 바닥만 정수리 시점(90°)으로 렌더 → floor.png (타일 격자와 1:1)"""
    global MAP
    MAP = read_map()
    W, H = len(MAP[0]), len(MAP)
    new_scene("MN_floor")
    mn_lib.SCN.world.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.65, 0.85, 1)
    mn_lib.SCN.world.node_tree.nodes["Background"].inputs[1].default_value = 0.9
    try:
        mn_lib.SCN.eevee.taa_render_samples = 16
    except Exception:
        pass
    M = materials()
    build_floor(M)
    build_dressing(M)
    for ob in list(mn_lib.SCN.collection.all_objects):
        if ob.name.startswith("walls_"):
            bpy.data.objects.remove(ob, do_unlink=True)
    # 평평하고 고른 조명 (그림자는 게임 3D 조명이 만든다)
    sd = bpy.data.lights.new("flat_sun", "SUN")
    sd.energy = 2.2
    so = bpy.data.objects.new("flat_sun", sd)
    so.rotation_euler = (math.radians(38), 0.0, math.radians(25))  # 비스듬히: 바닥 광택이 카메라로 반사되지 않게
    link(so)
    cam = ortho_cam("CamTop", (W / 2, -H / 2, 0), elev=90.0, scale=W, res=(W * px_per_tile, H * px_per_tile))
    cam.location = Vector((W / 2, -H / 2, 30))
    cam.rotation_mode = "XYZ"
    cam.rotation_euler = (0, 0, 0)
    cam.data.ortho_scale = W
    out = os.path.join(OUT, "map")
    os.makedirs(out, exist_ok=True)
    render(os.path.join(out, "floor.png"))
    log("OK floor_top", W, H)

def build_wall_tex(h=2.6, ppu=128):
    """3D 게임용 벽 텍스처: 스타일별 벽 옆면(폭 2 x 높이 h)과 윗면/옥상(2x2)을 정면에서 평평한 조명으로 렌더"""
    global WALL_H
    old = WALL_H
    WALL_H = h
    out = os.path.join(OUT, "tex")
    os.makedirs(out, exist_ok=True)
    jobs = [("wall_store", "side"), ("wall_storage", "side"), ("wall_concrete", "side"),
            ("wall_store_top", "top"), ("wall_storage_top", "top"), ("wall_concrete_top", "top"), ("roof", "top")]
    for name, kind in jobs:
        new_scene("MN_tex")
        wd = mn_lib.SCN.world.node_tree.nodes["Background"]
        wd.inputs[0].default_value = (1, 1, 1, 1)
        wd.inputs[1].default_value = 1.0
        try:
            mn_lib.SCN.view_settings.view_transform = "Standard"
            mn_lib.SCN.view_settings.look = "None"
            mn_lib.SCN.eevee.taa_render_samples = 8
        except Exception:
            pass
        M = materials()
        bm = bmesh.new()
        if kind == "side":
            vs = [bm.verts.new(v) for v in ((0, 0, 0), (2, 0, 0), (2, 0, h), (0, 0, h))]
        else:
            vs = [bm.verts.new(v) for v in ((0, 0, 0), (2, 0, 0), (2, 2, 0), (0, 2, 0))]
        f = bm.faces.new(vs)
        if kind == "side":
            f.normal_flip() if f.normal.y > 0 else None
        me = bpy.data.meshes.new("texplane")
        bm.to_mesh(me)
        bm.free()
        ob = bpy.data.objects.new("texplane", me)
        link(ob)
        me.materials.append(M[name])
        if kind == "side":
            cam = ortho_cam("CamTex", (1, 0, h / 2), elev=0.0, scale=max(2.0, h), res=(int(ppu * 2), int(ppu * h)))
        else:
            cam = ortho_cam("CamTex", (1, 1, 0), elev=90.0, scale=2.0, res=(int(ppu * 2), int(ppu * 2)))
            cam.location = Vector((1, 1, 30))
            cam.rotation_mode = "XYZ"
            cam.rotation_euler = (0, 0, 0)
        render(os.path.join(out, name + ".png"))
    WALL_H = old
    log("OK wall_tex")
