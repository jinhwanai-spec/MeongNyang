# 멍냥서바이벌 에셋 빌드 진입점
# Blender 파이썬 콘솔에서:  import mn_build; mn_build.run("chars")
import bpy, math, os, time, traceback, importlib
import mn_lib
from mn_lib import *

PX = 110  # 1 블렌더 단위 = 110px (캐릭터·무기 공통 배율)

CHAR_WEAPONS = {
    "hamster": ["pistol", "shotgun", "crossbow", "bat", "rifle"],
    "cat_tabby": ["knife"],
    "cat_black": ["hammer"],
    "cat_white": ["sniper"],
}

def build_chars(only=None):
    import mn_chars
    importlib.reload(mn_chars)
    meta = load_meta()
    for kind in mn_chars.SPECS:
        if only and kind not in only:
            continue
        t0 = time.time()
        try:
            new_scene("MN_" + kind)
            three_point((0, 0, 1.0))
            c = mn_chars.build(kind)
            cam = ortho_cam("Cam", (0, 0, 0.9), elev=55, scale=3.0, res=(320, 320))
            outdir = os.path.join(OUT, "chars", kind)
            os.makedirs(outdir, exist_ok=True)
            frames = {"idle": 4, "walk": 8, "hurt": 1}
            if kind == "hamster":
                frames["happy"] = 1
            for d in range(8):
                # d: 화면 기준 0=오른쪽, 2=아래(카메라 쪽), 4=왼쪽, 6=위
                c.root.rotation_euler = (0, 0, math.radians(90 - 45 * d))
                for mode, n in frames.items():
                    for i in range(n):
                        mn_chars.pose(c, mode, i / n)
                        render(os.path.join(outdir, "d%d_%s_%d.png" % (d, mode, i)))
            anchor = project(cam, (0, 0, 0))
            meta["char_" + kind] = {"anchor": anchor, "frames": frames, "dirs": 8, "size": [320, 320], "px": 320 / 3.0}
            save_source("char_" + kind, all_children(c.root))
            # 무기 + 앞발
            paw = mn_chars.SPECS[kind]["feet"] if kind != "hamster" else "#F2B98A"
            if kind == "cat_tabby":
                paw = "#A3A3A6"
            for wk in CHAR_WEAPONS[kind]:
                new_scene("MN_w_" + wk)
                three_point((0.3, 0, 0))
                root, parts = mn_chars.weapon(wk, paw)
                cam = ortho_cam("CamW", (0.3, 0, 0), elev=6, scale=2.0, res=(256, 128))
                fit_cam(cam, parts, 1.15, px_per_unit=320 / 3.0)
                wdir = os.path.join(OUT, "weapons")
                os.makedirs(wdir, exist_ok=True)
                render(os.path.join(wdir, "%s__%s.png" % (kind, wk)))
                meta["weapon_%s__%s" % (kind, wk)] = {"anchor": project(cam, (0, 0, 0)), "size": [mn_lib.SCN.render.resolution_x, mn_lib.SCN.render.resolution_y]}
                save_source("weapon_" + wk, parts)
            log("OK", kind, "%.1fs" % (time.time() - t0))
        except Exception:
            log("FAIL", kind, traceback.format_exc())
        save_meta(meta)

def build_map():
    import mn_map
    importlib.reload(mn_map)
    mn_map.build()

def build_props(only=None):
    import mn_props
    importlib.reload(mn_props)
    mn_props.build_all(only)

def build_items(only=None):
    import mn_items
    importlib.reload(mn_items)
    mn_items.build_all(only)

def run(what="all", only=None):
    importlib.reload(mn_lib)
    open(LOG, "a", encoding="utf-8").write("\n=== run %s %s ===\n" % (what, time.strftime("%H:%M:%S")))
    prev = bpy.context.window.scene if bpy.context.window else None
    try:
        if what in ("chars", "all"):
            build_chars(only)
        if what in ("map", "all"):
            build_map()
        if what in ("props", "all"):
            build_props(only)
        if what in ("items", "all"):
            build_items(only)
    except Exception:
        log("FATAL", traceback.format_exc())
    finally:
        try:
            if prev:
                bpy.context.window.scene = prev
        except Exception:
            pass
    log("DONE", what)
