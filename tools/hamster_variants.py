# 햄스터 8명(품종) 털색 변형 스트립 생성: chars/hamster.png 의 주황 털만 골라 색을 바꾼다.
import json, os, re
import numpy as np
from PIL import Image
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
D = os.path.join(ROOT, "assets", "sprites")
DB = open(os.path.join(ROOT, "scripts", "data", "db.gd"), encoding="utf-8").read()
FUR = dict(re.findall(r'"(\w+)": \{"name": "[^"]+", "breed": "[^"]+", "role": "[^"]+", "fur": "#(\w{6})"', DB))

def hsv(rgb):
    mx = rgb.max(-1); mn = rgb.min(-1); d = mx - mn + 1e-6
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    h = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) / 6
    return h, d / (mx + 1e-6) * (mx > 0), mx

def rgb_from(h, s, v):
    i = np.floor(h * 6) % 6; f = h * 6 - np.floor(h * 6)
    p = v * (1 - s); q = v * (1 - f * s); t = v * (1 - (1 - f) * s)
    out = np.zeros(h.shape + (3,))
    for k, (a, b, c) in enumerate([(v, t, p), (q, v, p), (p, v, t), (p, q, v), (t, p, v), (v, p, q)]):
        m = i == k
        out[m] = np.stack([a[m], b[m], c[m]], -1)
    return out

def recolor(img, hexc):
    A = np.asarray(img.convert("RGBA")).astype(np.float64) / 255
    rgb = A[..., :3]
    h, s, v = hsv(rgb)
    hd = h * 360
    w = np.clip((hd - 8) / 6, 0, 1) * np.clip((42 - hd) / 6, 0, 1) * np.clip((s - 0.32) / 0.15, 0, 1) * np.clip((v - 0.70) / 0.12, 0, 1)
    t = np.array([int(hexc[i:i + 2], 16) / 255 for i in (0, 2, 4)])
    th, ts, tv = hsv(t[None, None, :])
    th, ts, tv = th[0, 0], ts[0, 0], tv[0, 0]
    ref_s, ref_v = 0.62, 0.95
    ns = np.clip(s * ts / ref_s, 0, 1)
    nv = np.clip(v * tv / ref_v, 0, 1)
    new = rgb_from(np.full_like(h, th), ns, nv)
    out = rgb * (1 - w[..., None]) + new * w[..., None]
    return Image.fromarray((np.dstack([out, A[..., 3]]) * 255).astype(np.uint8), "RGBA")

def main():
    data = json.load(open(os.path.join(D, "sprites.json"), encoding="utf-8"))
    base = Image.open(os.path.join(D, "chars", "hamster.png"))
    for hid, col in FUR.items():
        name = "hamster_" + hid
        recolor(base, col).save(os.path.join(D, "chars", name + ".png"), optimize=True)
        data["chars"][name] = dict(data["chars"]["hamster"])
    json.dump(data, open(os.path.join(D, "sprites.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print("variants", list(FUR))

if __name__ == "__main__":
    main()
