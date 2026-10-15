# 캐릭터 디자인 반복용 미리보기: 4종을 나란히 놓고 게임 시점(55°)과 클로즈업(20°)을 렌더
import bpy, math, os, importlib
import mn_lib
from mn_lib import *

CHAR_ELEV = 38
KINDS = ["hamster", "cat_tabby", "cat_black", "cat_white"]

def run(tag="p", mode="idle", t=0.0, dirs=(2, 1)):
    importlib.reload(mn_lib)
    import mn_chars
    importlib.reload(mn_chars)
    outs = []
    for view, elev, res, sc in (("close", 15, (1600, 560), 8.6), ("game", CHAR_ELEV, (1600, 560), 8.6)):
        new_scene("MN_preview")
        three_point((0, 0, 0.8), 1.25)
        chars = []
        for i, k in enumerate(KINDS):
            c = mn_chars.build(k)
            mn_chars.pose(c, mode, t)
            d = dirs[0] if view == "close" else dirs[1]
            c.root.rotation_euler = (0, 0, math.radians(90 - 45 * d))
            c.root.location = ((i - 1.5) * 2.05, 0, 0)
            chars.append(c)
        ortho_cam("Cam", (0, 0, 0.95), elev=elev, scale=sc, res=res)
        p = os.path.join(OUT, "preview", "%s_%s.png" % (tag, view))
        os.makedirs(os.path.dirname(p), exist_ok=True)
        render(p)
        outs.append(p)
    print(outs)
    return outs
