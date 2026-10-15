# 은신처 방 배경 (3D 렌더) — assets/_render/hideout.png
import bpy, math, os
from mathutils import Vector
import mn_lib
from mn_lib import *
from mn_lib import _set

def build():
    new_scene("MN_hideout")
    w = mn_lib.SCN.world.node_tree.nodes["Background"]
    w.inputs[0].default_value = (0.25, 0.22, 0.2, 1)
    w.inputs[1].default_value = 0.4
    wood = mat("h_wood", "#7A5638", 0.6)
    wood2 = mat("h_wood2", "#5E4129", 0.65)
    wall = mat("h_wall", "#8A6A52", 0.85)
    wall_dark = mat("h_wall_d", "#6B4E3A", 0.85)
    rug = mat("h_rug", "#9C4E4E", 0.95)
    rug2 = mat("h_rug2", "#C9A27A", 0.95)
    blue = mat("h_cush", "#4A6A9C", 0.9)
    metal = mat("h_metal", "#5A606B", 0.4, 0.6)
    # 바닥 판자
    for i in range(18):
        box("plank", (14, 0.98, 0.1), wood if i % 2 else wood2, (0, -i + 4.5, -0.05))
    # 뒷벽 + 옆벽
    box("wallB", (14, 0.3, 10), wall, (0, 5.15, 5.0))
    box("wallL", (0.3, 10, 10), wall_dark, (-6.95, 0, 5.0))
    for i in range(14):
        box("wainscot", (0.96, 0.08, 1.2), wood2, (-6.5 + i, 4.98, 0.6), bevel=0.02)
    box("rail", (14, 0.12, 0.1), wood, (0, 4.95, 1.25))
    # 창문
    box("winframe", (2.2, 0.15, 1.6), wood2, (-3.2, 4.95, 3.0), bevel=0.04)
    box("winglass", (1.9, 0.05, 1.3), mat("h_night", "#1B2440", 0.1, emit=0.6), (-3.2, 4.9, 3.0))
    box("winbarV", (0.08, 0.06, 1.3), wood2, (-3.2, 4.86, 3.0))
    box("winbarH", (1.9, 0.06, 0.08), wood2, (-3.2, 4.86, 3.0))
    sphere("moon", 0.18, mat("h_moon", "#F3EEE6", 0.5, emit=3.0), (-2.6, 4.85, 3.35), (1, 0.2, 1))
    # 러그
    cyl("rug", 2.6, 0.03, rug, (0.4, 0.6, 0.02))
    cyl("rug_in", 2.1, 0.035, rug2, (0.4, 0.6, 0.025))
    cyl("rug_in2", 1.7, 0.04, rug, (0.4, 0.6, 0.03))
    for o in bpy.data.objects:
        if o.name.startswith("rug"):
            o.scale = (1.35, 0.75, 1)
    # 방석(잠자리)
    cyl("cushion", 1.0, 0.25, blue, (-3.6, 0.8, 0.13), bevel=0.1)
    cyl("cushion_top", 0.8, 0.1, mat("h_cush2", "#6A8AC0", 0.9), (-3.6, 0.8, 0.28), bevel=0.05)
    for o in bpy.data.objects:
        if o.name.startswith("cushion"):
            o.scale = (1.3, 0.9, 1)
    # 작업대 + 공구
    box("bench", (3.2, 1.0, 0.15), wood, (2.8, 3.7, 1.2), bevel=0.03)
    for sx in (-1.4, 1.4):
        box("leg", (0.15, 0.15, 1.2), wood2, (2.8 + sx, 3.7, 0.6))
    box("radio", (0.8, 0.4, 0.5), mat("h_radio", "#3B4252", 0.5), (3.6, 3.8, 1.53), bevel=0.05)
    box("radioscr", (0.45, 0.02, 0.22), mat("h_scr", "#6CCB5F", 0.3, emit=2.0), (3.5, 3.59, 1.56))
    cyl("antenna", 0.02, 0.9, metal, (3.9, 3.8, 2.1), (0, math.radians(20), 0))
    box("toolbox", (0.7, 0.4, 0.35), mat("h_tool", "#D64545", 0.5), (1.9, 3.7, 1.45), bevel=0.04)
    # 벽 공구걸이
    box("pegboard", (2.6, 0.06, 1.2), mat("h_peg", "#C9A27A", 0.8), (2.8, 5.0, 2.6))
    for i in range(4):
        cyl("tool", 0.04, 0.7, metal, (1.9 + i * 0.6, 4.95, 2.6))
    # 선반 + 상자
    box("shelf1", (2.4, 0.5, 0.08), wood, (-0.4, 4.75, 2.8))
    box("shelf2", (2.4, 0.5, 0.08), wood, (-0.4, 4.75, 3.6))
    for i, c in enumerate(("#E8B04A", "#4A8A5C", "#C96A4A")):
        box("jar%d" % i, (0.4, 0.35, 0.45), mat("h_jar%d" % i, c, 0.4), (-1.2 + i * 0.8, 4.7, 3.07), bevel=0.06)
    # 포스터 프레임
    box("poster", (1.1, 0.04, 1.4), mat("h_poster", "#F2C14E", 0.6), (0.9, 4.98, 3.4))
    # 전구 (따뜻한 빛)
    cyl("cord", 0.015, 4.0, mat("h_cord", "#1B1A22", 0.6), (0.4, 1.5, 6.0))
    sphere("bulb", 0.16, mat("h_bulb", "#FFE3A3", 0.3, emit=12.0), (0.4, 1.5, 3.95))
    ld = bpy.data.lights.new("bulb", "POINT")
    ld.energy = 900
    ld.color = (1.0, 0.78, 0.5)
    ld.shadow_soft_size = 0.3
    ob = bpy.data.objects.new("bulbL", ld)
    link(ob)
    ob.location = (0.4, 1.5, 3.7)
    ld2 = bpy.data.lights.new("fill", "AREA")
    ld2.energy = 120
    ld2.size = 8
    ld2.color = (0.7, 0.75, 1.0)
    ob2 = bpy.data.objects.new("fillL", ld2)
    link(ob2)
    ob2.location = (-2, -4, 6)
    ob2.rotation_euler = (math.radians(35), 0, 0)
    cam = ortho_cam("CamH", (0, 1.6, 1.2), elev=24, scale=11.2, res=(1176, 1190))
    out = os.path.join(OUT, "hideout.png")
    mn_lib.SCN.render.film_transparent = False
    render(out)
    meta = load_meta()
    meta["hideout"] = {"size": [1176, 1190], "floor_y": project(cam, (0, 0.8, 0))[1], "cushion": project(cam, (-3.6, 0.8, 0.3)), "rug": project(cam, (0.4, 0.6, 0.05))}
    save_meta(meta)
    print("hideout", meta["hideout"])
