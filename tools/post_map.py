# 블렌더 맵 렌더(55° 직교) → 게임 격자에 맞게 세로로 펴서 저장 (바닥면이 타일 격자와 정확히 겹침)
import json, os, sys
from PIL import Image
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "assets", "_render_in")
PX = 64
m = json.load(open(os.path.join(SRC, "meta.json"), encoding="utf-8"))["map"]
W, H = m["tiles"]
x0, y0 = m["tl"]; x1, y1 = m["br"]
DST = os.path.join(ROOT, "assets", "sprites", "map")
os.makedirs(DST, exist_ok=True)
MD = os.path.join(SRC, "map") if os.path.isdir(os.path.join(SRC, "map")) else SRC
# map.png: 전체 / walls.png: 벽만(투명) — 같은 변환으로 바닥면을 타일 격자에 맞춘다
for name, mode in (("map.png", "RGB"), ("walls.png", "RGBA")):
    fp = os.path.join(MD, name)
    if not os.path.exists(fp):
        continue
    im = Image.open(fp).convert(mode)
    out = im.crop((round(x0), 0, round(x1), round(y1))).resize((W * PX, round(y1 * (H * PX) / (y1 - y0))), Image.LANCZOS)
    top = out.height - H * PX
    out = out.crop((0, top, W * PX, out.height))
    out.save(os.path.join(DST, name), optimize=True)
    print(name, out.size, "px/tile", PX)
# 벽 윗면이 바닥 발자리에서 위로 몇 타일 떠 보이는지 (게임 가림 처리용)
import math
hoff = m.get("wall_h", 0.7) / math.tan(math.radians(m.get("elev", 55.0)))
json.dump({"hoff": hoff, "wall_h": m.get("wall_h", 0.7), "elev": m.get("elev", 55.0)}, open(os.path.join(DST, "map_meta.json"), "w"))
print("hoff", hoff)
