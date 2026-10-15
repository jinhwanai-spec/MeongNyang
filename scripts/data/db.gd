class_name DB
extends RefCounted
## 게임 데이터 모음. 숫자만 바꿔서 밸런스를 조절할 수 있어요.

# ── 팔레트 (기획서 2장) ──────────────────────────────
const C_BG := Color("#2B303A")
const C_CONCRETE := Color("#6B7280")
const C_GRASS := Color("#5F8F4E")
const C_HERO := Color("#F2994A")
const C_CAT := Color("#3E5C8A")
const C_DOG := Color("#8A5A3B")
const C_DANGER := Color("#D64545")
const C_RARE := Color("#3FC1C9")
const C_LEGEND := Color("#F2C14E")
const C_UI := Color(0.102, 0.122, 0.169, 0.88)
const C_UI_SOLID := Color("#1A1F2B")
const C_TEXT := Color("#F3EEE6")
const C_MUTED := Color("#9AA3B2")

# 희귀도: 흰색 → 초록 → 파랑 → 보라 → 금색
const RARITY_COLORS := [Color("#E6E6E6"), Color("#6CCB5F"), Color("#4A90E2"), Color("#A86CE0"), Color("#F2C14E")]
const RARITY_NAMES := ["일반", "고급", "희귀", "영웅", "전설"]

static func rarity_color(r: int) -> Color:
	return RARITY_COLORS[clampi(r, 0, 4)]

# ── 아이템 ───────────────────────────────────────────
# w,h = 배낭 그리드에서 차지하는 칸 / v = 판매가(냥코인)
# cat: food, med, part, valuable, ammo
# use: heal(체력), stamina(스태미너)
const ITEMS := {
	"canned_food": {"name": "참치 통조림", "w": 1, "h": 1, "r": 0, "v": 25, "cat": "food", "use": {"heal": 10, "stamina": 30}, "desc": "든든한 한 끼. 체력과 스태미너를 조금 회복."},
	"kibble": {"name": "사료 봉지", "w": 1, "h": 2, "r": 0, "v": 45, "cat": "food", "desc": "개 상인이 비싸게 사 주는 무거운 식량."},
	"churu": {"name": "츄르", "w": 1, "h": 1, "r": 1, "v": 70, "cat": "food", "use": {"heal": 20}, "desc": "고양이들의 화폐. 먹으면 기분이 좋아진다."},
	"energy_drink": {"name": "멍뭉 에너지", "w": 1, "h": 1, "r": 1, "v": 60, "cat": "food", "use": {"stamina": 100}, "desc": "스태미너를 가득 채운다."},
	"bandage": {"name": "붕대", "w": 1, "h": 1, "r": 0, "v": 30, "cat": "med", "use": {"heal": 35}, "desc": "체력 35 회복. (Q)"},
	"medkit": {"name": "동물병원 구급상자", "w": 2, "h": 2, "r": 2, "v": 160, "cat": "med", "use": {"heal": 90}, "desc": "체력 90 회복. 자리를 많이 차지한다."},
	"screws": {"name": "나사 뭉치", "w": 1, "h": 1, "r": 0, "v": 20, "cat": "part", "desc": "석궁 화살 제작 재료."},
	"pipe": {"name": "쇠파이프", "w": 1, "h": 3, "r": 0, "v": 35, "cat": "part", "desc": "석궁의 몸통이 된다."},
	"rope": {"name": "나일론 끈", "w": 1, "h": 1, "r": 0, "v": 25, "cat": "part", "desc": "석궁 시위 재료."},
	"spring": {"name": "강철 스프링", "w": 1, "h": 1, "r": 1, "v": 60, "cat": "part", "desc": "공구함·창고에서 주로 나온다."},
	"duct_tape": {"name": "덕트 테이프", "w": 1, "h": 1, "r": 0, "v": 30, "cat": "part", "desc": "뭐든 붙인다."},
	"battery": {"name": "배터리", "w": 1, "h": 1, "r": 1, "v": 70, "cat": "part", "desc": "자판기·계산대에서 가끔 나온다."},
	"circuit": {"name": "회로 기판", "w": 1, "h": 2, "r": 2, "v": 130, "cat": "part", "desc": "기술 고양이가 좋아하는 부품."},
	"toy_mouse": {"name": "장난감 쥐", "w": 1, "h": 1, "r": 1, "v": 55, "cat": "valuable", "desc": "삑삑 소리가 난다."},
	"catnip": {"name": "고급 캣닢 상자", "w": 2, "h": 1, "r": 2, "v": 170, "cat": "valuable", "desc": "냥이 시장에서 인기 만점."},
	"silver_bell": {"name": "은방울", "w": 1, "h": 1, "r": 3, "v": 290, "cat": "valuable", "desc": "작지만 값비싸다."},
	"lucky_coin": {"name": "행운의 동전", "w": 1, "h": 1, "r": 3, "v": 320, "cat": "valuable", "desc": "계산대 깊숙한 곳에서 발견된다."},
	"old_camera": {"name": "낡은 즉석카메라", "w": 2, "h": 2, "r": 3, "v": 400, "cat": "valuable", "desc": "무겁지만 고가."},
	"gold_collar": {"name": "황금 목줄", "w": 1, "h": 1, "r": 4, "v": 650, "cat": "valuable", "desc": "전설의 귀중품. 창고 사물함 어딘가에."},
	"sunflower_seed": {"name": "해바라기씨", "w": 1, "h": 1, "r": 0, "v": 15, "cat": "food", "use": {"stamina": 50, "buff": "seed"}, "eat": 0.5, "desc": "기력 +50, 3초간 기력 소모 없음. 먹는 시간이 짧다."},
	"cheese": {"name": "치즈 조각", "w": 1, "h": 1, "r": 1, "v": 40, "cat": "food", "use": {"heal": 30}, "eat": 1.0, "desc": "체력 +30. 냄새가 나서 먹은 뒤 잠시 고양이가 잘 알아챈다."},
	"carrot_juice": {"name": "당근주스", "w": 1, "h": 1, "r": 1, "v": 45, "cat": "food", "use": {"buff": "carrot"}, "eat": 0.8, "desc": "8초간 이동 속도 +25%. 탈출 단거리 질주용."},
	"nut_mix": {"name": "견과류 한 줌", "w": 1, "h": 1, "r": 1, "v": 35, "cat": "food", "use": {"heal": 10, "buff": "nut"}, "eat": 1.4, "desc": "10초간 받는 피해 -20%. 보스전·교전 직전에."},
	"ammo_pistol": {"name": "권총탄", "w": 1, "h": 1, "r": 0, "v": 3, "cat": "ammo", "ammo": "pistol", "amount": 12, "desc": "권총탄 12발."},
	"ammo_shell": {"name": "산탄", "w": 1, "h": 1, "r": 0, "v": 8, "cat": "ammo", "ammo": "shell", "amount": 6, "desc": "산탄 6발."},
	"ammo_bolt": {"name": "석궁 화살", "w": 1, "h": 1, "r": 0, "v": 10, "cat": "ammo", "ammo": "bolt", "amount": 4, "desc": "석궁 화살 4발."},
	"ammo_rifle": {"name": "소총탄", "w": 1, "h": 1, "r": 1, "v": 4, "cat": "ammo", "ammo": "rifle", "amount": 20, "desc": "소총탄 20발."},
	"w_pistol": {"name": "멍멍 권총", "w": 2, "h": 1, "r": 0, "v": 66, "cat": "weapon", "weapon": "pistol", "desc": "무기. 가방에서 사용하면 바로 장착한다."},
	"w_shotgun": {"name": "펌프 산탄총", "w": 4, "h": 1, "r": 1, "v": 209, "cat": "weapon", "weapon": "shotgun", "desc": "무기. 가방에서 사용하면 바로 장착한다."},
	"w_crossbow": {"name": "깡통 석궁", "w": 3, "h": 1, "r": 2, "v": 286, "cat": "weapon", "weapon": "crossbow", "desc": "무기. 가방에서 사용하면 바로 장착한다."},
	"w_revolver": {"name": "냥펀치 리볼버", "w": 2, "h": 1, "r": 1, "v": 121, "cat": "weapon", "weapon": "revolver", "desc": "무기. 가방에서 사용하면 바로 장착한다."},
	"w_machine_pistol": {"name": "따발 기관권총", "w": 2, "h": 1, "r": 1, "v": 143, "cat": "weapon", "weapon": "machine_pistol", "desc": "무기. 가방에서 사용하면 바로 장착한다."},
	"w_derringer": {"name": "주머니 데린저", "w": 1, "h": 1, "r": 1, "v": 82, "cat": "weapon", "weapon": "derringer", "desc": "무기. 가방에서 사용하면 바로 장착한다."},
	"w_sawed_off": {"name": "짤뚝 산탄총", "w": 2, "h": 1, "r": 1, "v": 165, "cat": "weapon", "weapon": "sawed_off", "desc": "무기. 가방에서 사용하면 바로 장착한다."},
	"w_nail_gun": {"name": "공구함 못총", "w": 2, "h": 1, "r": 1, "v": 132, "cat": "weapon", "weapon": "nail_gun", "desc": "무기. 가방에서 사용하면 바로 장착한다."},
	"w_smg": {"name": "꼬리흔들 기관단총", "w": 3, "h": 1, "r": 2, "v": 231, "cat": "weapon", "weapon": "smg", "desc": "무기. 가방에서 사용하면 바로 장착한다."},
	"w_assault_rifle": {"name": "돌격소총", "w": 4, "h": 1, "r": 2, "v": 341, "cat": "weapon", "weapon": "assault_rifle", "desc": "무기. 가방에서 사용하면 바로 장착한다."},
	"w_carbine": {"name": "카빈 소총", "w": 4, "h": 1, "r": 1, "v": 264, "cat": "weapon", "weapon": "carbine", "desc": "무기. 가방에서 사용하면 바로 장착한다."},
	"w_battle_rifle": {"name": "전투소총", "w": 4, "h": 1, "r": 3, "v": 385, "cat": "weapon", "weapon": "battle_rifle", "desc": "무기. 가방에서 사용하면 바로 장착한다."},
	"w_hunting_rifle": {"name": "사냥용 소총", "w": 4, "h": 1, "r": 2, "v": 308, "cat": "weapon", "weapon": "hunting_rifle", "desc": "무기. 가방에서 사용하면 바로 장착한다."},
	"w_sniper": {"name": "저격소총", "w": 5, "h": 1, "r": 4, "v": 605, "cat": "weapon", "weapon": "sniper", "desc": "무기. 가방에서 사용하면 바로 장착한다."},
	"w_dmr": {"name": "지정사수 소총", "w": 4, "h": 1, "r": 3, "v": 467, "cat": "weapon", "weapon": "dmr", "desc": "무기. 가방에서 사용하면 바로 장착한다."},
	"w_lmg": {"name": "경기관총", "w": 4, "h": 1, "r": 3, "v": 539, "cat": "weapon", "weapon": "lmg", "desc": "무기. 가방에서 사용하면 바로 장착한다."},
	"w_double_barrel": {"name": "쌍열 산탄총", "w": 4, "h": 1, "r": 1, "v": 231, "cat": "weapon", "weapon": "double_barrel", "desc": "무기. 가방에서 사용하면 바로 장착한다."},
	"w_auto_shotgun": {"name": "자동 산탄총", "w": 4, "h": 1, "r": 3, "v": 495, "cat": "weapon", "weapon": "auto_shotgun", "desc": "무기. 가방에서 사용하면 바로 장착한다."},
	"w_compound_bow": {"name": "컴파운드 활", "w": 3, "h": 1, "r": 2, "v": 253, "cat": "weapon", "weapon": "compound_bow", "desc": "무기. 가방에서 사용하면 바로 장착한다."},
	"w_harpoon_gun": {"name": "작살총", "w": 4, "h": 1, "r": 3, "v": 352, "cat": "weapon", "weapon": "harpoon_gun", "desc": "무기. 가방에서 사용하면 바로 장착한다."},
	"w_bat": {"name": "쇠파이프 배트", "w": 3, "h": 1, "r": 0, "v": 44, "cat": "weapon", "weapon": "bat", "desc": "무기. 가방에서 사용하면 바로 장착한다."},
	"w_knife": {"name": "전투 나이프", "w": 2, "h": 1, "r": 0, "v": 38, "cat": "weapon", "weapon": "knife", "desc": "무기. 가방에서 사용하면 바로 장착한다."},
	"w_hammer": {"name": "망치", "w": 2, "h": 1, "r": 0, "v": 49, "cat": "weapon", "weapon": "hammer", "desc": "무기. 가방에서 사용하면 바로 장착한다."},
	"w_machete": {"name": "마체테", "w": 3, "h": 1, "r": 1, "v": 88, "cat": "weapon", "weapon": "machete", "desc": "무기. 가방에서 사용하면 바로 장착한다."},
	"w_katana": {"name": "카타나", "w": 4, "h": 1, "r": 3, "v": 264, "cat": "weapon", "weapon": "katana", "desc": "무기. 가방에서 사용하면 바로 장착한다."},
	"w_crowbar": {"name": "빠루", "w": 3, "h": 1, "r": 0, "v": 55, "cat": "weapon", "weapon": "crowbar", "desc": "무기. 가방에서 사용하면 바로 장착한다."},
	"w_fire_axe": {"name": "소방 도끼", "w": 4, "h": 1, "r": 2, "v": 143, "cat": "weapon", "weapon": "fire_axe", "desc": "무기. 가방에서 사용하면 바로 장착한다."},
	"w_spear": {"name": "죽창", "w": 5, "h": 1, "r": 1, "v": 99, "cat": "weapon", "weapon": "spear", "desc": "무기. 가방에서 사용하면 바로 장착한다."},
	"w_frying_pan": {"name": "프라이팬", "w": 2, "h": 1, "r": 0, "v": 33, "cat": "weapon", "weapon": "frying_pan", "desc": "무기. 가방에서 사용하면 바로 장착한다."},
	"w_sledgehammer": {"name": "오함마", "w": 4, "h": 1, "r": 3, "v": 231, "cat": "weapon", "weapon": "sledgehammer", "desc": "무기. 가방에서 사용하면 바로 장착한다."},
}

# ── 햄스터 용병 8명 (시나리오·캐릭터 설계서) ─────────
# fur = 시트 스프라이트의 주황 털을 바꿀 색, hp/speed/noise = 기본치 배율, skill = 전술 스킬(F)
const HAMSTERS := {
	"baragi": {"name": "바라기", "breed": "시리안", "role": "리더형", "fur": "#F0A050", "hp": 100.0, "speed": 1.0, "noise": 1.0,
		"skill": "rally", "skill_name": "작전 개시!", "cd": 40.0, "desc": "8초간 재장전·기력 회복 +60%, 이동 +10%.", "trait": "모든 무기 반동 -10%"},
	"solbang": {"name": "솔방울", "breed": "로보로프스키", "role": "정찰형", "fur": "#E2C08A", "hp": 80.0, "speed": 1.12, "noise": 0.9,
		"skill": "scout", "skill_name": "종이비행기 정찰", "cd": 45.0, "desc": "12초간 맵의 모든 고양이 위치 표시.", "trait": "이동 +12%, 체력 80"},
	"kongtteok": {"name": "콩떡", "breed": "드워프 정글리안", "role": "은신형", "fur": "#A9A6A8", "hp": 85.0, "speed": 1.0, "noise": 0.6,
		"skill": "cloak", "skill_name": "상자 뒤집어쓰기", "cd": 35.0, "desc": "5초 완전 은신. 쫓던 고양이도 놓친다. 공격하면 해제.", "trait": "발소리 -40%"},
	"cheeseball": {"name": "치즈볼", "breed": "골든", "role": "폭파형", "fur": "#E8B030", "hp": 115.0, "speed": 0.95, "noise": 1.2,
		"skill": "bomb", "skill_name": "치즈 폭탄", "cd": 25.0, "desc": "조준 지점에 치즈 폭탄(70 피해, 넓은 범위). 폭발음이 크다.", "trait": "체력 115, 소음 +20%"},
	"moka": {"name": "모카", "breed": "블랙베어", "role": "함정형", "fur": "#6B4A35", "hp": 100.0, "speed": 1.0, "noise": 0.9,
		"skill": "mine", "skill_name": "솔방울 지뢰", "cd": 18.0, "desc": "발밑에 지뢰 설치(최대 3). 밟은 고양이 50 피해 + 2초 기절.", "trait": "어둠 속에서 잘 안 보임"},
	"marshmallow": {"name": "마시멜로", "breed": "윈터화이트", "role": "지원형", "fur": "#F4EEE6", "hp": 100.0, "speed": 1.0, "noise": 1.0,
		"skill": "snack", "skill_name": "해바라기 간식 상자", "cd": 40.0, "desc": "8초간 주변에서 초당 체력 6 회복.", "trait": "회복·음식 사용 시간 -50%"},
	"meokmul": {"name": "먹물", "breed": "판다 햄스터", "role": "근접 돌격형", "fur": "#3A3438", "hp": 120.0, "speed": 0.98, "noise": 1.1,
		"skill": "dash", "skill_name": "볼주머니 돌진", "cd": 14.0, "desc": "4칸 돌진. 경로의 고양이 25 피해 + 기절 + 넉백. 돌진 중 무적.", "trait": "근접 쿨타임 -50%"},
	"toto": {"name": "토토", "breed": "롱헤어 시리안", "role": "탈출 특화형", "fur": "#F3DDB5", "hp": 90.0, "speed": 1.05, "noise": 1.0,
		"skill": "burrow", "skill_name": "비상 굴", "cd": 30.0, "desc": "조준 방향으로 최대 6칸 땅속 이동(벽 통과, 무적).", "trait": "구르기 기력 -40%"},
}
const HAMSTER_ORDER := ["baragi", "solbang", "kongtteok", "cheeseball", "moka", "marshmallow", "meokmul", "toto"]

## 뺨주머니: 배낭 왼쪽 위 칸들. 여기 완전히 들어간 아이템은 사망해도 지켜진다.
const CHEEK_W := 2
const CHEEK_H := 1

# ── 무기 ─────────────────────────────────────────────
# noise = 총성이 들리는 반경(px). 적이 소리를 듣고 몰려온다.
const WEAPONS := {
	"pistol": {"name": "멍멍 권총", "slot": "sidearm", "ammo": "pistol", "dmg": 17.0, "pellets": 1, "rate": 0.26, "mag": 10, "reload": 1.1,
		"spread": 3.0, "speed": 950.0, "range": 620.0, "noise": 520.0, "recoil": 4.0, "kick": 60.0, "auto": false, "v": 120, "r": 0,
		"desc": "저렴하고 정확하지만 화력이 낮다."},
	"shotgun": {"name": "펌프 산탄총", "slot": "primary", "ammo": "shell", "dmg": 10.0, "pellets": 8, "rate": 0.85, "mag": 5, "reload": 2.1,
		"spread": 24.0, "speed": 820.0, "range": 330.0, "noise": 760.0, "recoil": 12.0, "kick": 170.0, "auto": false, "v": 380, "r": 1,
		"desc": "실내·근거리에서 한 번에 큰 피해. 사거리 짧음."},
	"crossbow": {"name": "깡통 석궁", "slot": "primary", "ammo": "bolt", "dmg": 62.0, "pellets": 1, "rate": 0.3, "mag": 1, "reload": 0.95,
		"spread": 0.6, "speed": 1250.0, "range": 900.0, "noise": 90.0, "recoil": 3.0, "kick": 120.0, "auto": false, "v": 520, "r": 2,
		"pierce": 1, "recover": true, "desc": "은신처 작업대에서 제작. 거의 소리가 나지 않고 화살을 회수할 수 있다."},
	"revolver": {"name": "냥펀치 리볼버", "slot": "sidearm", "ammo": "pistol", "dmg": 32.0, "pellets": 1, "rate": 0.42, "mag": 6, "reload": 1.6,
		"spread": 2.0, "speed": 1050.0, "range": 680.0, "noise": 620.0, "recoil": 8, "kick": 110.0, "auto": false, "v": 220, "r": 1,
		"desc": "한 방이 묵직한 6연발 권총."},
	"machine_pistol": {"name": "따발 기관권총", "slot": "sidearm", "ammo": "pistol", "dmg": 10.0, "pellets": 1, "rate": 0.075, "mag": 20, "reload": 1.4,
		"spread": 9, "speed": 900.0, "range": 480.0, "noise": 560.0, "recoil": 2.5, "kick": 30.0, "auto": true, "v": 260, "r": 1,
		"desc": "권총탄을 무섭게 뿌린다. 탄 소모가 크다."},
	"derringer": {"name": "주머니 데린저", "slot": "sidearm", "ammo": "pistol", "dmg": 30.0, "pellets": 1, "rate": 0.22, "mag": 2, "reload": 1.3,
		"spread": 3, "speed": 900.0, "range": 420.0, "noise": 380.0, "recoil": 6, "kick": 90.0, "auto": false, "v": 150, "r": 1,
		"desc": "두 발짜리 비상용 권총. 작고 조용하다."},
	"sawed_off": {"name": "짤뚝 산탄총", "slot": "sidearm", "ammo": "shell", "dmg": 9.0, "pellets": 7, "rate": 0.3, "mag": 2, "reload": 1.8,
		"spread": 32, "speed": 760.0, "range": 240.0, "noise": 760.0, "recoil": 14, "kick": 190.0, "auto": false, "v": 300, "r": 1,
		"desc": "짧은 쌍열 산탄총. 코앞에서는 최강."},
	"nail_gun": {"name": "공구함 못총", "slot": "sidearm", "ammo": "pistol", "dmg": 13.0, "pellets": 1, "rate": 0.14, "mag": 25, "reload": 1.8,
		"spread": 5, "speed": 820.0, "range": 420.0, "noise": 170.0, "recoil": 2, "kick": 35.0, "auto": true, "v": 240, "r": 1,
		"desc": "권총탄을 못처럼 쏜다. 아주 조용하다."},
	"smg": {"name": "꼬리흔들 기관단총", "slot": "primary", "ammo": "pistol", "dmg": 12.0, "pellets": 1, "rate": 0.075, "mag": 30, "reload": 1.7,
		"spread": 7, "speed": 950.0, "range": 520.0, "noise": 600.0, "recoil": 2.5, "kick": 35.0, "auto": true, "v": 420, "r": 2,
		"desc": "권총탄을 쓰는 연사 무기. 근거리 제압용."},
	"assault_rifle": {"name": "돌격소총", "slot": "primary", "ammo": "rifle", "dmg": 20.0, "pellets": 1, "rate": 0.11, "mag": 30, "reload": 2.0,
		"spread": 4.5, "speed": 1150.0, "range": 760.0, "noise": 820.0, "recoil": 4, "kick": 55.0, "auto": true, "v": 620, "r": 2,
		"desc": "만능 연사 소총."},
	"carbine": {"name": "카빈 소총", "slot": "primary", "ammo": "rifle", "dmg": 24.0, "pellets": 1, "rate": 0.17, "mag": 20, "reload": 1.8,
		"spread": 3, "speed": 1150.0, "range": 780.0, "noise": 780.0, "recoil": 4.5, "kick": 65.0, "auto": false, "v": 480, "r": 1,
		"desc": "가볍고 다루기 쉬운 반자동 소총."},
	"battle_rifle": {"name": "전투소총", "slot": "primary", "ammo": "rifle", "dmg": 34.0, "pellets": 1, "rate": 0.22, "mag": 20, "reload": 2.2,
		"spread": 3.5, "speed": 1200.0, "range": 820.0, "noise": 880.0, "recoil": 7, "kick": 90.0, "auto": false, "v": 700, "r": 3,
		"desc": "한 발 한 발이 강한 반자동 소총."},
	"hunting_rifle": {"name": "사냥용 소총", "slot": "primary", "ammo": "rifle", "dmg": 62.0, "pellets": 1, "rate": 0.95, "mag": 5, "reload": 2.4,
		"spread": 1, "speed": 1350.0, "range": 980.0, "noise": 880.0, "recoil": 10, "kick": 160.0, "auto": false, "v": 560, "r": 2, "pierce": 1,
		"desc": "볼트액션. 한 발에 고양이를 눕힌다."},
	"sniper": {"name": "저격소총", "slot": "primary", "ammo": "rifle", "dmg": 95.0, "pellets": 1, "rate": 1.35, "mag": 5, "reload": 2.8,
		"spread": 0.4, "speed": 1600.0, "range": 1150.0, "noise": 980.0, "recoil": 14, "kick": 220.0, "auto": false, "v": 1100, "r": 4, "pierce": 2,
		"desc": "멀리서 한 방. 총성이 크다."},
	"dmr": {"name": "지정사수 소총", "slot": "primary", "ammo": "rifle", "dmg": 46.0, "pellets": 1, "rate": 0.36, "mag": 10, "reload": 2.3,
		"spread": 1.5, "speed": 1400.0, "range": 950.0, "noise": 860.0, "recoil": 7, "kick": 110.0, "auto": false, "v": 850, "r": 3,
		"desc": "정확하고 빠른 중거리 소총."},
	"lmg": {"name": "경기관총", "slot": "primary", "ammo": "rifle", "dmg": 18.0, "pellets": 1, "rate": 0.085, "mag": 60, "reload": 3.6,
		"spread": 7, "speed": 1150.0, "range": 760.0, "noise": 920.0, "recoil": 4, "kick": 45.0, "auto": true, "v": 980, "r": 3,
		"desc": "탄띠 60발. 재장전이 길다."},
	"double_barrel": {"name": "쌍열 산탄총", "slot": "primary", "ammo": "shell", "dmg": 11.0, "pellets": 9, "rate": 0.22, "mag": 2, "reload": 2.0,
		"spread": 22, "speed": 800.0, "range": 320.0, "noise": 800.0, "recoil": 14, "kick": 180.0, "auto": false, "v": 420, "r": 1,
		"desc": "두 발을 연달아 쏘는 고전 산탄총."},
	"auto_shotgun": {"name": "자동 산탄총", "slot": "primary", "ammo": "shell", "dmg": 9.0, "pellets": 7, "rate": 0.28, "mag": 8, "reload": 2.6,
		"spread": 26, "speed": 820.0, "range": 320.0, "noise": 820.0, "recoil": 11, "kick": 150.0, "auto": true, "v": 900, "r": 3,
		"desc": "산탄을 연사한다. 실내 정리용."},
	"compound_bow": {"name": "컴파운드 활", "slot": "primary", "ammo": "bolt", "dmg": 48.0, "pellets": 1, "rate": 0.6, "mag": 1, "reload": 0.75,
		"spread": 0.8, "speed": 1150.0, "range": 850.0, "noise": 70.0, "recoil": 2, "kick": 100.0, "auto": false, "v": 460, "r": 2, "recover": true,
		"desc": "거의 소리 없는 활. 화살을 회수할 수 있다."},
	"harpoon_gun": {"name": "작살총", "slot": "primary", "ammo": "bolt", "dmg": 75.0, "pellets": 1, "rate": 0.5, "mag": 1, "reload": 1.4,
		"spread": 0.6, "speed": 1000.0, "range": 700.0, "noise": 150.0, "recoil": 6, "kick": 260.0, "auto": false, "v": 640, "r": 3, "pierce": 2, "recover": true,
		"desc": "꿰뚫는 작살. 화살탄을 쓴다."},
}

const MELEE := {"name": "쇠파이프 배트", "dmg": 34.0, "range": 70.0, "arc": 110.0, "cooldown": 0.5, "noise": 110.0, "kick": 260.0}

# ── 근접 무기 10종 (V) ─────────────────────────────
const MELEES := {
	"bat": {"name": "쇠파이프 배트", "dmg": 34.0, "range": 70.0, "arc": 110.0, "cooldown": 0.5, "noise": 110.0, "kick": 260.0, "v": 80, "r": 0, "desc": "기본 근접 무기. 언제나 챙길 수 있다."},
	"knife": {"name": "전투 나이프", "dmg": 24.0, "range": 52.0, "arc": 80.0, "cooldown": 0.26, "noise": 60.0, "kick": 120.0, "v": 70, "r": 0, "desc": "빠르고 조용하다. 암습에 좋다."},
	"hammer": {"name": "망치", "dmg": 42.0, "range": 62.0, "arc": 90.0, "cooldown": 0.62, "noise": 120.0, "kick": 300.0, "v": 90, "r": 0, "desc": "묵직하게 내려친다."},
	"machete": {"name": "마체테", "dmg": 36.0, "range": 74.0, "arc": 120.0, "cooldown": 0.42, "noise": 90.0, "kick": 220.0, "v": 160, "r": 1, "desc": "넓게 베는 정글도."},
	"katana": {"name": "카타나", "dmg": 46.0, "range": 88.0, "arc": 130.0, "cooldown": 0.46, "noise": 90.0, "kick": 240.0, "v": 480, "r": 3, "desc": "길고 날카로운 칼."},
	"crowbar": {"name": "빠루", "dmg": 34.0, "range": 68.0, "arc": 100.0, "cooldown": 0.48, "noise": 110.0, "kick": 280.0, "v": 100, "r": 0, "desc": "문도 열고 고양이도 친다."},
	"fire_axe": {"name": "소방 도끼", "dmg": 58.0, "range": 80.0, "arc": 110.0, "cooldown": 0.8, "noise": 140.0, "kick": 340.0, "v": 260, "r": 2, "desc": "한 방이 크지만 느리다."},
	"spear": {"name": "죽창", "dmg": 40.0, "range": 115.0, "arc": 40.0, "cooldown": 0.55, "noise": 90.0, "kick": 260.0, "v": 180, "r": 1, "desc": "멀리 찌른다. 좁은 각도."},
	"frying_pan": {"name": "프라이팬", "dmg": 28.0, "range": 60.0, "arc": 120.0, "cooldown": 0.5, "noise": 180.0, "kick": 420.0, "v": 60, "r": 0, "desc": "맞으면 멀리 날아간다. 소리가 크다."},
	"sledgehammer": {"name": "오함마", "dmg": 75.0, "range": 82.0, "arc": 140.0, "cooldown": 1.15, "noise": 180.0, "kick": 460.0, "v": 420, "r": 3, "desc": "아주 느리지만 무엇이든 부순다."},
}

## 고양이 종류별로 들고 다니는 무기 (죽으면 그 무기 + 맞는 탄약을 떨어뜨린다)
const ENEMY_WEAPONS := {
	"hyena": ["knife", "machete", "bat", "crowbar", "katana", "spear", "pistol", "revolver", "machine_pistol", "derringer", "nail_gun", "sawed_off", "smg"],
	"bulldog": ["hammer", "sledgehammer", "fire_axe", "frying_pan", "shotgun", "double_barrel", "auto_shotgun", "lmg"],
	"cat": ["sniper", "hunting_rifle", "dmr", "carbine", "battle_rifle", "assault_rifle", "crossbow", "compound_bow", "harpoon_gun"],
}

## 총소리: 무기 계열별
static func shot_sfx(wid: String) -> String:
	match wid:
		"pistol", "shotgun", "crossbow":
			return "shot_" + wid
		"sniper", "hunting_rifle", "dmr", "battle_rifle":
			return "shot_sniper"
		"assault_rifle", "carbine", "lmg":
			return "shot_rifle"
		"smg", "machine_pistol", "nail_gun":
			return "shot_smg"
		"revolver", "derringer":
			return "shot_revolver"
	var w: Dictionary = WEAPONS.get(wid, {})
	match str(w.get("ammo", "pistol")):
		"shell":
			return "shot_shotgun"
		"bolt":
			return "shot_crossbow"
		"rifle":
			return "shot_rifle"
	return "shot_pistol"

static func is_melee(wid: String) -> bool:
	return MELEES.has(wid)

static func weapon_data(wid: String) -> Dictionary:
	if WEAPONS.has(wid):
		return WEAPONS[wid]
	return MELEES.get(wid, {})

# ── 적 ───────────────────────────────────────────────
# tier: 1=약탈자, 2=정규 적 / eye: 눈 색 = 위협도
const ENEMIES := {
	"hyena": {"name": "길냥이 돌격병", "tier": 1, "hp": 34.0, "speed": 175.0, "chase_speed": 265.0, "radius": 15.0, "vision": 430.0, "fov": 130.0,
		"attack": "bite", "dmg": 8.0, "attack_range": 42.0, "attack_cd": 0.7, "eye": Color("#F2C14E"), "name_color": Color("#E6E6E6"),
		"body": Color("#A9A9AD"), "group_call": 520.0, "loot": [["canned_food", 0.25], ["toy_mouse", 0.15], ["ammo_pistol", 0.35]]},
	"bulldog": {"name": "중장갑 흑냥이", "tier": 2, "hp": 150.0, "speed": 95.0, "chase_speed": 150.0, "radius": 22.0, "vision": 380.0, "fov": 110.0,
		"attack": "hammer", "dmg": 24.0, "attack_range": 62.0, "attack_cd": 1.45, "eye": Color("#F2994A"), "name_color": Color("#F2994A"),
		"body": Color("#3A3A42"), "group_call": 650.0, "loot": [["kibble", 0.5], ["ammo_shell", 0.6], ["spring", 0.3], ["bandage", 0.4]]},
	"cat": {"name": "흰냥 저격수", "tier": 2, "hp": 60.0, "speed": 120.0, "chase_speed": 175.0, "radius": 15.0, "vision": 620.0, "fov": 100.0,
		"attack": "bolt", "dmg": 16.0, "attack_range": 470.0, "attack_cd": 1.7, "eye": Color("#D64545"), "name_color": Color("#D64545"),
		"body": Color("#F3F0EA"), "group_call": 560.0, "loot": [["ammo_bolt", 0.6], ["churu", 0.4], ["rope", 0.35], ["silver_bell", 0.1]]},
}

# ── 파밍 상자 (지도 기호 → 종류) ──────────────────────
# search = 뒤지는 시간(초), slots = 생성 아이템 수, table = [아이템, 가중치]
const CONTAINERS := {
	"shelf": {"name": "진열대", "search": 1.0, "slots": [1, 2], "noise": 60.0, "table": [["canned_food", 30], ["sunflower_seed", 22], ["nut_mix", 8], ["kibble", 18], ["churu", 12], ["energy_drink", 10], ["duct_tape", 12], ["toy_mouse", 8], ["ammo_pistol", 8]]},
	"fridge": {"name": "음료 냉장고", "search": 1.2, "slots": [1, 2], "noise": 80.0, "table": [["energy_drink", 40], ["cheese", 22], ["carrot_juice", 14], ["churu", 25], ["canned_food", 20], ["battery", 6]]},
	"register": {"name": "계산대", "search": 2.2, "slots": [1, 3], "noise": 140.0, "table": [["lucky_coin", 10], ["silver_bell", 12], ["battery", 20], ["toy_mouse", 20], ["ammo_pistol", 15], ["catnip", 10]]},
	"box": {"name": "골판지 상자", "search": 1.4, "slots": [1, 3], "noise": 70.0, "table": [["screws", 25], ["rope", 22], ["duct_tape", 20], ["pipe", 14], ["canned_food", 14], ["ammo_shell", 10], ["spring", 6]]},
	"trash": {"name": "쓰레기통", "search": 1.0, "slots": [0, 2], "noise": 90.0, "table": [["cheese", 8], ["screws", 30], ["canned_food", 25], ["duct_tape", 15], ["toy_mouse", 12], ["rope", 12]]},
	"dumpster": {"name": "대형 수거함", "search": 2.0, "slots": [1, 3], "noise": 150.0, "table": [["pipe", 25], ["screws", 25], ["rope", 15], ["kibble", 12], ["circuit", 6], ["ammo_shell", 10]]},
	"vending": {"name": "자판기", "search": 1.8, "slots": [1, 2], "noise": 170.0, "table": [["energy_drink", 40], ["battery", 25], ["churu", 15], ["lucky_coin", 4]]},
	"plant": {"name": "화분", "search": 0.8, "slots": [0, 1], "noise": 40.0, "table": [["sunflower_seed", 30], ["toy_mouse", 30], ["silver_bell", 8], ["screws", 30], ["catnip", 6]]},
	"toolbox": {"name": "공구함", "search": 1.6, "slots": [2, 3], "noise": 110.0, "table": [["spring", 35], ["screws", 30], ["duct_tape", 25], ["circuit", 10], ["pipe", 10]]},
	"medcab": {"name": "약품 보관함", "search": 1.6, "slots": [1, 2], "noise": 60.0, "table": [["bandage", 45], ["medkit", 18], ["churu", 10], ["energy_drink", 12]]},
	"locker": {"name": "직원 사물함", "search": 2.4, "slots": [1, 3], "noise": 100.0, "table": [["silver_bell", 18], ["old_camera", 12], ["gold_collar", 5], ["catnip", 15], ["ammo_shell", 18], ["circuit", 12], ["medkit", 10]]},
}

const MAP_CONTAINER_CODES := {"S": "shelf", "F": "fridge", "R": "register", "B": "box", "T": "trash", "D": "dumpster", "V": "vending", "P": "plant", "K": "toolbox", "M": "medcab", "L": "locker"}

# ── 제작 (은신처 작업대) ─────────────────────────────
const RECIPES := [
	{"id": "crossbow", "kind": "weapon", "name": "깡통 석궁", "cost": {"pipe": 1, "rope": 2, "spring": 1, "duct_tape": 1}, "coins": 40,
		"benefit": "다음 원정: 조용한 원거리 저격 + 화살 회수", "hint": {"pipe": "대형 수거함·공구함", "rope": "골판지 상자·쓰레기통", "spring": "공구함(창고)", "duct_tape": "진열대·상자"}},
	{"id": "ammo_bolt", "kind": "ammo", "name": "석궁 화살 ×6", "ammo": "bolt", "amount": 6, "cost": {"screws": 2}, "coins": 0,
		"benefit": "석궁 탄약 확보", "hint": {"screws": "쓰레기통·상자"}},
	{"id": "cheese", "kind": "item", "name": "치즈 조각 ×2", "item": "cheese", "amount": 2, "cost": {"canned_food": 1, "churu": 1}, "coins": 0,
		"benefit": "다음 원정: 체력 회복 간식", "hint": {"canned_food": "진열대·쓰레기통", "churu": "진열대·냉장고"}},
	{"id": "carrot_juice", "kind": "item", "name": "당근주스", "item": "carrot_juice", "amount": 1, "cost": {"energy_drink": 1, "canned_food": 1}, "coins": 10,
		"benefit": "다음 원정: 탈출 질주용 속도 버프", "hint": {"energy_drink": "냉장고·자판기", "canned_food": "진열대"}},
	{"id": "bandage", "kind": "item", "name": "붕대 ×2", "item": "bandage", "amount": 2, "cost": {"rope": 1, "duct_tape": 1}, "coins": 0,
		"benefit": "다음 원정 생존력 상승", "hint": {"rope": "골판지 상자", "duct_tape": "진열대"}},
]

# ── 상점 (냥이 시장) ─────────────────────────────────
const SHOP := [
	{"id": "ammo_pistol", "kind": "ammo", "ammo": "pistol", "amount": 12, "price": 36, "name": "권총탄 12발"},
	{"id": "ammo_shell", "kind": "ammo", "ammo": "shell", "amount": 6, "price": 54, "name": "산탄 6발"},
	{"id": "bandage", "kind": "item", "item": "bandage", "amount": 1, "price": 45, "name": "붕대"},
	{"id": "sunflower_seed", "kind": "item", "item": "sunflower_seed", "amount": 3, "price": 40, "name": "해바라기씨 ×3"},
	{"id": "nut_mix", "kind": "item", "item": "nut_mix", "amount": 1, "price": 55, "name": "견과류 한 줌"},
	{"id": "shotgun", "kind": "weapon", "weapon": "shotgun", "price": 420, "name": "펌프 산탄총"},
	{"id": "ammo_rifle", "kind": "ammo", "ammo": "rifle", "amount": 20, "price": 60, "name": "소총탄 20발"},
	{"id": "revolver", "kind": "weapon", "weapon": "revolver", "price": 320, "name": "냥펀치 리볼버"},
	{"id": "smg", "kind": "weapon", "weapon": "smg", "price": 560, "name": "꼬리흔들 기관단총"},
	{"id": "carbine", "kind": "weapon", "weapon": "carbine", "price": 640, "name": "카빈 소총"},
]

const RAID_TIME := 14.0 * 60.0
const BACKPACK_W := 6
const BACKPACK_H := 4
const TILE := 48
