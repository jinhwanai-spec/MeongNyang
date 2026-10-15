"""렌더 결과(assets/_render) → 게임용 스프라이트(assets/sprites) 변환
- 캐릭터: 프레임 공통 영역으로 자르고 가로 스트립으로 합침
- 외곽선·채도 보정, 축소(LANCZOS), 앵커 좌표 계산 → sprites.json
"""
import json, os, sys
from PIL import Image, ImageFilter, ImageEnhance, ImageChops

SRC = sys.argv[1] if len(sys.argv) > 1 else "assets/_render"
DST = sys.argv[2] if len(sys.argv) > 2 else "assets/sprites"
CHAR_S = 0.6
PROP_S = 0.6
OUTLINE = (24, 20, 28)

def enhance(im, sat=1.18, con=1.05):
    a = im.getchannel("A")
    rgb = im.convert("RGB")
    rgb = ImageEnhance.Color(rgb).enhance(sat)
    rgb = ImageEnhance.Contrast(rgb).enhance(con)
    out = rgb.convert("RGBA")
    out.putalpha(a)
    return out

def outline(im, r, alpha=220):
    a = im.getchannel("A").point(lambda v: 255 if v > 40 else 0)
    grown = a.filter(ImageFilter.MaxFilter(r * 2 + 1)).filter(ImageFilter.GaussianBlur(0.6))
    base = Image.new("RGBA", im.size, OUTLINE + (0,))
    base.putalpha(grown.point(lambda v: int(v * alpha / 255)))
    base.alpha_composite(im)
    return base

def pad(im, p):
    out = Image.new("RGBA", (im.width + p * 2, im.height + p * 2), (0, 0, 0, 0))
    out.paste(im, (p, p))
    return out

def bbox_union(ims):
    bb = None
    for im in ims:
        b = im.getchannel("A").point(lambda v: 255 if v > 4 else 0).getbbox()
        if b is None:
            continue
        bb = b if bb is None else (min(bb[0], b[0]), min(bb[1], b[1]), max(bb[2], b[2]), max(bb[3], b[3]))
    return bb

def process(ims, anchor, scale, outline_r):
    bb = bbox_union(ims)
    P = outline_r + 2
    res = []
    for im in ims:
        c = im.crop(bb)
        c = enhance(c)
        c = pad(c, P)
        c = outline(c, outline_r)
        if scale != 1.0:
            c = c.resize((max(1, round(c.width * scale)), max(1, round(c.height * scale))), Image.LANCZOS)
        res.append(c)
    ax = (anchor[0] - bb[0] + P) * scale
    ay = (anchor[1] - bb[1] + P) * scale
    return res, [round(ax, 2), round(ay, 2)]

meta = json.load(open(os.path.join(SRC, "meta.json"), encoding="utf-8"))
out = {"chars": {}, "weapons": {}, "props": {}, "items": {}}
os.makedirs(os.path.join(DST, "chars"), exist_ok=True)
os.makedirs(os.path.join(DST, "weapons"), exist_ok=True)
os.makedirs(os.path.join(DST, "props"), exist_ok=True)
os.makedirs(os.path.join(DST, "items"), exist_ok=True)

# 캐릭터
for key, m in meta.items():
    if not key.startswith("char_"):
        continue
    kind = key[5:]
    order = []
    for mode, n in m["frames"].items():
        for i in range(n):
            order.append((mode, i))
    ims = [Image.open(os.path.join(SRC, "chars", kind, "%s_%d.png" % fr)).convert("RGBA") for fr in order]
    frames, anc = process(ims, m["anchor"], CHAR_S, 7)
    fw, fh = frames[0].size
    strip = Image.new("RGBA", (fw * len(frames), fh), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        strip.paste(f, (i * fw, 0))
    strip.save(os.path.join(DST, "chars", kind + ".png"), optimize=True)
    anim = {}
    idx = 0
    for mode, n in m["frames"].items():
        anim[mode] = [idx, n]
        idx += n
    out["chars"][kind] = {"frame": [fw, fh], "count": len(frames), "anchor": anc, "anims": anim, "px_per_unit": m["px"] * CHAR_S}
    print("char", kind, fw, fh, anc)

# 무기
for key, m in meta.items():
    if not key.startswith("weapon_"):
        continue
    name = key[7:]
    im = Image.open(os.path.join(SRC, "weapons", name + ".png")).convert("RGBA")
    (f,), anc = process([im], m["anchor"], CHAR_S, 6)
    f.save(os.path.join(DST, "weapons", name + ".png"), optimize=True)
    out["weapons"][name] = {"anchor": anc, "size": list(f.size)}

# 소품
for key, m in meta.items():
    if not key.startswith("prop_"):
        continue
    name = key[5:]
    im = Image.open(os.path.join(SRC, "props", name + ".png")).convert("RGBA")
    (f,), anc = process([im], m["anchor"], PROP_S, 5)
    f.save(os.path.join(DST, "props", name + ".png"), optimize=True)
    out["props"][name] = {"anchor": anc, "size": list(f.size), "px_per_tile": m["px"] * PROP_S}

# 아이템 아이콘
for fn in sorted(os.listdir(os.path.join(SRC, "items"))):
    if not fn.endswith(".png"):
        continue
    im = Image.open(os.path.join(SRC, "items", fn)).convert("RGBA")
    bb = im.getchannel("A").getbbox()
    c = enhance(im.crop(bb), 1.2)
    c = outline(pad(c, 6), 4)
    c.thumbnail((256, 256), Image.LANCZOS)
    c.save(os.path.join(DST, "items", fn), optimize=True)
    out["items"][fn[:-4]] = list(c.size)

json.dump(out, open(os.path.join(DST, "sprites.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print("done")

# Godot에서 바로 쓰는 데이터 스크립트 (내보내기에 JSON 포함 설정이 필요 없도록)
def to_gd(v):
    if isinstance(v, dict):
        return "{" + ", ".join('"%s": %s' % (k, to_gd(x)) for k, x in v.items()) + "}"
    if isinstance(v, list):
        return "[" + ", ".join(to_gd(x) for x in v) + "]"
    if isinstance(v, float):
        return repr(round(v, 3))
    return str(v)
with open(os.path.join(DST, "sprite_data.gd"), "w", encoding="utf-8") as f:
    f.write("# 자동 생성 (tools/post_sprites.py) — 직접 수정하지 마세요\nclass_name SpriteData\nextends RefCounted\n\nconst DATA := " + to_gd(out) + "\n")
print("gd written")
