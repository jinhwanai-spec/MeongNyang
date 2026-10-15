# sprites.json → sprite_data.gd 재생성 (아이템 크기 갱신 포함)
import json, os
from PIL import Image
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
D = os.path.join(ROOT, "assets", "sprites")
d = json.load(open(os.path.join(D, "sprites.json"), encoding="utf-8"))
for fn in os.listdir(os.path.join(D, "items")):
    if fn.endswith(".png"):
        d["items"][fn[:-4]] = list(Image.open(os.path.join(D, "items", fn)).size)
json.dump(d, open(os.path.join(D, "sprites.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
def to_gd(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, dict):
        return "{" + ", ".join('"%s": %s' % (k, to_gd(x)) for k, x in v.items()) + "}"
    if isinstance(v, (list, tuple)):
        return "[" + ", ".join(to_gd(x) for x in v) + "]"
    if isinstance(v, float):
        return repr(round(v, 4))
    if isinstance(v, str):
        return '"%s"' % v
    return str(v)
open(os.path.join(D, "sprite_data.gd"), "w", encoding="utf-8").write("# 자동 생성 (tools/*.py) — 직접 수정하지 마세요\nclass_name SpriteData\nextends RefCounted\n\nconst DATA := " + to_gd(d) + "\n")
print("ok", len(d["items"]))
