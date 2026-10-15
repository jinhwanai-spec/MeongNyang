# 레퍼런스 시트(assets/_sheet/sheetA.png)에서 스프라이트를 잘라 게임 에셋으로 만든다.
# - 체크무늬 배경 제거 → 박스별 잘라내기 → 캐릭터는 발 기준 정렬 스트립
# - sprites.json / sprite_data.gd 의 chars·items·weapons·props·fx·ui 항목을 갱신
import json, os, sys
import numpy as np
from PIL import Image, ImageFilter, ImageEnhance
from scipy import ndimage as nd

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHEET = os.path.join(ROOT, "assets", "_sheet", "sheetA.png")
DST = os.path.join(ROOT, "assets", "sprites")

# ── 배경 제거 ────────────────────────────────────────
def cutout(path):
    im = np.asarray(Image.open(path).convert("RGB")).astype(np.float32)
    mx = im.max(2); mn = im.min(2)
    bglike = ((mx - mn) < 14) & (mn > 188)
    g = im.mean(2)
    m = nd.uniform_filter(g, 7); m2 = nd.uniform_filter(g * g, 7)
    std = np.sqrt(np.maximum(m2 - m * m, 0))
    frac = nd.uniform_filter(bglike.astype(np.float32), 7)
    checker = bglike & (std > 7) & (frac > 0.85)
    tex = nd.uniform_filter((std > 5).astype(np.float32), 9) > 0.5
    allow = bglike & (tex | checker)
    lab, n = nd.label(allow)
    border = np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))
    cnt = nd.sum(np.ones_like(g), lab, index=np.arange(n + 1))
    chk = nd.sum(checker.astype(np.float32), lab, index=np.arange(n + 1))
    keep = np.zeros(n + 1, bool)
    keep[cnt > 2000] = True
    keep[border] = True
    keep[(~keep) & (chk / np.maximum(cnt, 1) > 0.45)] = True
    keep[0] = False
    bg = nd.binary_closing(keep[lab], iterations=1)
    a = np.where(bg, 0, 255).astype(np.float32)
    edge = (~bg) & nd.binary_dilation(bg, iterations=1)
    a[edge & bglike] = 0
    a[edge & ~bglike] = 170
    # 밝은 회색 테두리(체크무늬 잔여) 한 겹 더 깎기
    edge2 = (a > 0) & nd.binary_dilation(a == 0, iterations=1) & bglike
    a[edge2] = 0
    return np.dstack([im, a]).astype(np.uint8)

A = None

def crop(box, pad=2, edge_drop=0.25):
    x0, y0, x1, y1 = box
    sub = A[y0:y1, x0:x1].copy()
    a = sub[:, :, 3] > 40
    lab, n = nd.label(a, structure=np.ones((3, 3)))
    if n:
        cnt = nd.sum(a, lab, range(1, n + 1))
        big = cnt.max()
        objs = nd.find_objects(lab)
        keep = []
        h, w = a.shape
        for i, c in enumerate(cnt):
            if c < max(12, big * 0.004):
                continue
            s = objs[i]
            touches = s[1].start == 0 or s[1].stop == w or s[0].start == 0 or s[0].stop == h
            if touches and c < big * edge_drop:
                continue
            keep.append(i + 1)
        m = np.isin(lab, keep)
        sub[~m] = 0
    else:
        m = a
    ys, xs = np.where(m)
    X0, X1 = max(xs.min() - pad, 0), xs.max() + 1 + pad
    Y0, Y1 = max(ys.min() - pad, 0), ys.max() + 1 + pad
    im = Image.fromarray(sub[Y0:Y1, X0:X1], "RGBA")
    out = Image.new("RGBA", (im.width + 6, im.height + 6), (0, 0, 0, 0))
    out.paste(im, (3, 3))
    return out

def defringe(im):
    """잘라낸 가장자리의 흰 체크무늬 잔여 제거 + 가장자리 색 안쪽 색으로 번짐 + 살짝 부드럽게"""
    A_ = np.asarray(im).astype(np.float32)
    rgb, a = A_[:, :, :3], A_[:, :, 3]
    solid = a > 200
    inner = nd.binary_erosion(solid, iterations=2)
    edge = (a > 0) & ~inner
    mx = rgb.max(2); mn = rgb.min(2)
    light = ((mx - mn) < 22) & (mn > 170)
    a[edge & light & (a < 250)] = 0
    # 바깥 테두리의 회색 반투명(체크무늬와 섞인 안티앨리어싱) 한 겹 제거
    grey = ((mx - mn) < 18) & (mn > 105)
    outer = (a > 0) & (a < 250) & nd.binary_dilation(a == 0, iterations=1)
    a[outer & grey] = 0
    # 가장자리 RGB를 안쪽 픽셀 색으로 (번짐)
    idx = nd.distance_transform_edt(~inner, return_distances=False, return_indices=True)
    bleed = rgb[idx[0], idx[1]]
    e2 = (a > 0) & ~inner
    rgb[e2] = rgb[e2] * 0.35 + bleed[e2] * 0.65
    a = nd.gaussian_filter(a, 0.6)
    a[~nd.binary_dilation(A_[:, :, 3] > 0, iterations=1)] = 0
    # 일정한 짙은 외곽선(스티커 느낌, 지저분한 가장자리 가림)
    sil = a > 110
    ring = nd.binary_dilation(sil, iterations=2) & ~sil
    ol = nd.gaussian_filter(ring.astype(np.float32) * 255, 0.7)
    oc = np.array([38, 30, 34], np.float32)
    k = (ol / 255.0)[:, :, None] * (1 - a[:, :, None] / 255.0)
    rgb = rgb * (1 - k) + oc * k
    a = np.maximum(a, ol * 0.92)
    out = np.dstack([rgb, np.clip(a, 0, 255)]).astype(np.uint8)
    return Image.fromarray(out, "RGBA")

def polish(im, sat=1.08, sharp=True):
    im = defringe(im)
    rgb = im.convert("RGB"); al = im.getchannel("A")
    rgb = ImageEnhance.Color(rgb).enhance(sat)
    if sharp:
        rgb = rgb.filter(ImageFilter.UnsharpMask(1.2, 60, 2))
    out = rgb.convert("RGBA"); out.putalpha(al)
    return out

def feet_anchor(im):
    """발 위치 = 아래쪽 25% 영역의 불투명 픽셀 중앙 x, 맨 아래 y"""
    a = np.asarray(im)[:, :, 3] > 80
    ys, xs = np.where(a)
    bottom = ys.max()
    top = ys.min()
    band = a[max(bottom - int((bottom - top) * 0.25), 0):bottom + 1]
    bx = np.where(band.any(0))[0]
    # 몸통 중심: 아래 띠에서 가장 넓은 연속 구간의 중앙
    cols = band.sum(0) > 0
    best = (0, 0, 0)
    s = None
    for x, v in enumerate(list(cols) + [False]):
        if v and s is None:
            s = x
        elif not v and s is not None:
            if x - s > best[0]:
                best = (x - s, s, x)
            s = None
    cx = (best[1] + best[2]) / 2.0
    return cx, float(bottom), float(bottom - top)

# ── 캐릭터 프레임 정의 (시트 좌표) ───────────────────
H1 = [[15,55,105,170],[110,55,200,170],[203,55,292,170],[295,55,382,170],[385,55,470,170],[475,55,562,170],[565,55,650,170],[652,55,745,170]]
H2 = [[12,178,105,285],[108,178,210,285],[212,178,308,285],[312,178,400,285],[402,178,512,285],[515,178,620,285],[622,178,765,285]]
H3 = [[12,292,105,402],[107,292,205,402],[207,292,290,402],[300,292,400,402],[405,292,515,402],[518,292,622,402],[625,292,772,402]]
H4 = [[12,412,118,530],[125,412,210,530],[222,412,318,530],[322,412,428,530],[430,412,525,530],[535,412,640,530],[640,412,745,530]]
H5 = [[15,532,100,628],[105,532,190,628],[195,532,285,628],[290,532,375,628],[383,532,475,628],[478,532,598,628],[600,532,740,628]]
C1 = [[778,48,905,172],[908,48,1025,172],[1040,48,1135,172],[1145,48,1250,172],[1250,48,1338,172],[1338,48,1418,172],[1418,48,1532,172]]
C2 = [[782,175,888,288],[892,175,992,288],[1002,175,1095,288],[1105,175,1188,288],[1188,175,1282,288],[1285,175,1390,288],[1392,175,1532,288]]
C3 = [[775,292,875,402],[875,292,975,402],[975,292,1072,402],[1075,292,1185,402],[1188,292,1285,402],[1290,292,1405,402],[1405,292,1532,402]]
C4 = [[778,405,900,528],[915,405,1030,528],[1030,405,1160,528],[1160,405,1340,528],[1345,405,1532,528]]
C5 = [[770,526,895,628],[905,526,1030,628],[1035,526,1150,628],[1150,526,1285,628],[1285,526,1415,628],[1420,526,1532,628]]

# kind: (시트 기본 방향이 왼쪽인가, 게임 내 목표 키(px), {anim: [박스...]})
CHARS = {
    "hamster": (False, 52.0, {
        "idle": [H1[7]],
        "walk": [H2[0], H2[1], H2[2], H2[3]],
        "idle_front": [H1[0]],
        "walk_front": [H1[0], H1[1], H1[2], H1[3]],
        "idle_back": [H1[5]],
        "walk_back": [H1[5], H1[6]],
        "aim": [H4[0]],
        "hurt": [H1[4]],
        "happy": [H4[1]],
        "heal": [H4[5]],
        "dodge": [H5[5]],
        "sleep": [H5[6]],
        "portrait": [H5[0]],
        "portrait_hurt": [H5[2]],
        "portrait_happy": [H5[1]],
    }),
    "cat_tabby": (True, 50.0, {
        "idle": [C2[0]],
        "walk": [C2[0]],
        "alert": [C2[0]],
        "windup": [C4[1]],
        "attack": [C4[3]],
        "hurt": [C3[6]],
        "dead": [C5[5]],
    }),
    "cat_black": (True, 60.0, {
        "idle": [C2[2]],
        "walk": [C2[2]],
        "alert": [C3[2]],
        "windup": [C3[4]],
        "attack": [C4[2]],
        "hurt": [C5[3]],
        "dead": [C5[5]],
    }),
    "cat_white": (True, 52.0, {
        "idle": [C1[2]],
        "walk": [C1[2]],
        "alert": [C1[2]],
        "windup": [C5[2]],
        "attack": [C5[2]],
        "hurt": [C3[5]],
        "dead": [C5[5]],
    }),
}

ITEMS = {  # 게임 아이템 id → 시트 박스
    "medkit": [20, 872, 80, 923], "ammo_pistol": [85, 870, 140, 923], "lucky_coin": [145, 872, 185, 920],
    "canned_food": [375, 868, 411, 920], "energy_drink": [425, 862, 470, 920], "ammo_shell": [85, 930, 135, 988],
    "silver_bell": [262, 934, 305, 983], "rope": [320, 927, 393, 995], "battery": [410, 930, 473, 995],
}
WEAPONS = {  # 무기 아이콘(HUD·인벤토리)
    "pistol": [22, 692, 90, 748], "shotgun": [237, 687, 358, 733], "rifle": [110, 682, 223, 740],
    "sniper": [370, 682, 483, 736], "knife": [425, 755, 485, 815], "launcher": [232, 727, 415, 823],
    "ak": [22, 742, 153, 810], "revolver": [167, 745, 233, 810],
}
# 소품: 이름 → (박스, 바닥 깊이 비율) ; 바닥 중심 = 아래에서 depth*폭/2
PROPS = {
    "crate": ([1047, 687, 1128, 760], 0.5), "crate_blue": ([1132, 687, 1203, 758], 0.5),
    "barrel_red": ([1210, 680, 1253, 750], 0.45), "barrel_blue": ([1255, 690, 1300, 750], 0.45),
    "fence": ([1302, 647, 1393, 733], 0.12), "fence2": ([1394, 647, 1485, 733], 0.12),
    "lamp": ([1480, 640, 1525, 816], 0.6), "sandbags": ([1287, 730, 1403, 795], 0.45),
    "locker": ([1405, 722, 1463, 790], 0.5), "barrier_orange": ([1045, 765, 1115, 833], 0.35),
    "barrier_concrete": ([1125, 757, 1218, 823], 0.35), "cardboard": ([1225, 760, 1285, 813], 0.5),
    "barrier_stripe": ([1055, 830, 1148, 888], 0.4), "cone": ([1145, 820, 1200, 893], 0.5),
    "tires": ([1202, 817, 1283, 890], 0.5), "ammo_locker": ([1287, 795, 1343, 873], 0.5),
    "bush": ([1342, 797, 1435, 865], 0.45), "rock": ([1410, 797, 1450, 826], 0.5),
    "stump": ([1440, 827, 1475, 866], 0.5), "crate_small": ([1475, 820, 1520, 873], 0.5),
    "pallet": ([1305, 867, 1403, 911], 0.6), "trough": ([1412, 870, 1495, 915], 0.45),
}
PROP_PX_PER_TILE = 78.0
FX = {
    "flash1": [512, 687, 585, 718], "flash2": [587, 687, 665, 718], "explosion": [772, 672, 875, 730],
    "smoke": [882, 682, 945, 730], "explosion2": [952, 682, 1020, 730], "puff1": [672, 740, 710, 773],
    "puff2": [717, 740, 760, 773], "slash": [800, 740, 880, 810], "smoke_big": [892, 740, 953, 783],
    "burst": [960, 740, 1025, 785], "heal": [520, 777, 580, 835], "sparkle": [592, 777, 645, 825],
    "orb": [587, 827, 650, 890], "coin": [665, 830, 703, 875], "blood": [860, 797, 920, 862],
    "impact": [925, 782, 1000, 845], "crater": [872, 867, 962, 900], "dust": [705, 852, 780, 900],
    "bag": [142, 925, 203, 990], "key": [217, 932, 250, 988], "grenade": [270, 862, 313, 918],
    "decal_blood": [1057, 942, 1130, 990], "decal_scorch": [1142, 942, 1205, 990], "decal_crack": [1227, 943, 1293, 993],
}
UI = {
    "heart": [520, 950, 565, 995], "shield": [570, 950, 615, 995], "bolt": [620, 950, 665, 995], "ammo": [667, 950, 715, 995],
    "crosshair": [722, 950, 770, 995], "grenade": [776, 950, 822, 995], "skull": [827, 950, 873, 995],
    "alert": [877, 950, 920, 995], "question": [925, 950, 970, 995], "coin": [975, 950, 1020, 995],
}

def build_char(kind, faces_left, target_h, anims):
    frames = []
    names = {}
    for an, boxes in anims.items():
        names[an] = [len(frames), len(boxes)]
        for b in boxes:
            frames.append(polish(crop(b)))
    info = [feet_anchor(f) for f in frames]
    # 기준 키: idle 첫 프레임
    ref_h = info[names["idle"][0]][2]
    left = max(cx for cx, by, h in info)
    right = max(f.width - cx for f, (cx, by, h) in zip(frames, info))
    up = max(by for cx, by, h in info)
    down = max(f.height - by for f, (cx, by, h) in zip(frames, info))
    hw = int(np.ceil(max(left, right))) + 2
    fw, fh = hw * 2, int(np.ceil(up + down)) + 4
    ay = int(np.ceil(up)) + 2
    strip = Image.new("RGBA", (fw * len(frames), fh), (0, 0, 0, 0))
    for i, (f, (cx, by, h)) in enumerate(zip(frames, info)):
        strip.alpha_composite(f, (int(round(i * fw + hw - cx)), int(round(ay - by))))
    os.makedirs(os.path.join(DST, "chars"), exist_ok=True)
    strip.save(os.path.join(DST, "chars", kind + ".png"), optimize=True)
    return {"frame": [fw, fh], "count": len(frames), "anchor": [float(hw), float(ay)], "anims": names,
            "faces_left": faces_left, "scale": target_h / ref_h, "h": ref_h}

def save_icon(group, name, box, maxside=None, sat=1.08):
    im = polish(crop(box), sat)
    if maxside and max(im.size) > maxside:
        im.thumbnail((maxside, maxside), Image.LANCZOS)
    os.makedirs(os.path.join(DST, group), exist_ok=True)
    im.save(os.path.join(DST, group, name + ".png"), optimize=True)
    return im

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

def main():
    global A
    A = cutout(SHEET)
    data = json.load(open(os.path.join(DST, "sprites.json"), encoding="utf-8"))
    for kind, (fl, th, anims) in CHARS.items():
        data["chars"][kind] = build_char(kind, fl, th, anims)
    for iid, box in ITEMS.items():
        im = save_icon("items", iid, box, 256)
        data["items"][iid] = list(im.size)
    data["icons"] = {}
    for wid, box in WEAPONS.items():
        im = save_icon("icons", "w_" + wid, box)
        data["icons"]["w_" + wid] = list(im.size)
    data["sprops"] = {}
    for name, (box, depth) in PROPS.items():
        im = save_icon("sprops", name, box)
        w, h = im.size
        data["sprops"][name] = {"anchor": [w / 2.0, h - depth * w * 0.5 * 0.55 - 2], "size": [w, h], "px_per_tile": PROP_PX_PER_TILE}
    data["fx"] = {}
    for name, box in FX.items():
        im = save_icon("fx", name, box, sat=1.0)
        data["fx"][name] = list(im.size)
    data["ui"] = {}
    for name, box in UI.items():
        im = save_icon("ui", name, box)
        data["ui"][name] = list(im.size)
    json.dump(data, open(os.path.join(DST, "sprites.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    with open(os.path.join(DST, "sprite_data.gd"), "w", encoding="utf-8") as f:
        f.write("# 자동 생성 (tools/post_sprites.py, tools/sheet_sprites.py) — 직접 수정하지 마세요\nclass_name SpriteData\nextends RefCounted\n\nconst DATA := " + to_gd(data) + "\n")
    print("done", {k: len(v) for k, v in data.items()})

if __name__ == "__main__":
    main()
