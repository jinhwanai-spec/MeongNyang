class_name Regions
extends RefCounted
## 원정 지역 정보 (지도는 LevelData.MAPS). 은신처 출발 준비에서 고른다.

const ORDER := ["mart", "dock", "town", "subway"]

const DATA := {
	"mart": {
		"name": "지역 1 · 멍냥마트와 뒷골목", "short": "멍냥마트 · 뒷골목", "danger": "★★☆", "reward": "★★☆",
		"info": "제한 14분 · 탈출구 2곳 (A 맨홀: 항상 열림 / B 하역장: 발전기 필요)\n출몰: 길냥이 돌격병(빠름) · 중장갑 흑냥이(망치·돌진) · 흰냥 저격수(조준선 주의)",
		"floor": "res://assets/sprites/map/floor.png", "minimap": "res://assets/sprites/map/map_top.png",
		"exits": {"A": ["A 맨홀", "manhole"], "B": ["B 하역장", "truck"]},
		"lock": "창고의 비상 발전기를 켜야 열린다",
		"glass_row": 16, "loot": 1.0,
		"boss": ["bulldog", "창고지기 흑냥이", "auto_shotgun"],
		"reinforce": [Vector2(56, 22), Vector2(1, 24), Vector2(30, 1), Vector2(56, 30)],
		"lights": [
			[Vector2(14, 8), "#FFE9C4", 7.0, 1.6], [Vector2(23, 8), "#FFE9C4", 7.0, 1.6], [Vector2(31, 7), "#CFE8FF", 6.0, 1.4],
			[Vector2(14, 13.5), "#FFE9C4", 6.0, 1.3], [Vector2(26, 13.5), "#FFE9C4", 6.0, 1.3], [Vector2(33, 13), "#FFD9A0", 5.0, 1.4],
			[Vector2(44, 7), "#9FB6FF", 7.0, 1.6], [Vector2(22, 17.0), "#FF7FB0", 5.0, 2.2],
			[Vector2(6.5, 19.3), "#FFD89A", 6.0, 2.4], [Vector2(17.5, 19.3), "#FFD89A", 6.0, 2.4], [Vector2(33.5, 19.3), "#FFD89A", 6.0, 2.4],
			[Vector2(45.5, 19.3), "#FFD89A", 6.0, 2.4], [Vector2(54.5, 19.3), "#FFD89A", 6.0, 2.4],
			[Vector2(20, 33), "#FFB070", 5.5, 2.0], [Vector2(42, 33), "#B0C8FF", 6.0, 1.8], [Vector2(54, 36), "#7CFF9A", 3.5, 1.6],
		],
		"decor": [
			["lamp", 6.5, 19.3, 1.0], ["lamp", 17.5, 19.3, 1.0], ["lamp", 33.5, 19.3, 1.0], ["lamp", 45.5, 19.3, 1.0], ["lamp", 54.5, 19.3, 1.0],
			["bush", 2.2, 6.6, 0.9], ["bush", 3.4, 12.8, 0.8], ["rock", 1.6, 9.4, 0.9], ["stump", 3.6, 15.2, 0.9], ["bush", 49.5, 20.6, 0.8],
			["cone", 11.6, 20.4, 0.7], ["cone", 12.5, 20.7, 0.7], ["barrier_stripe", 44.8, 2.6, 0.8], ["cone", 26.5, 2.5, 0.7],
			["pallet", 40.5, 31.6, 0.9], ["tires", 44.5, 37.8, 0.9], ["barrier_orange", 51.2, 30.6, 0.8], ["crate_small", 18.6, 33.7, 0.8],
			["cardboard", 20.4, 37.6, 0.8], ["trough", 37.5, 29.6, 0.8], ["rock", 56.2, 33.5, 0.8],
		],
	},
	"dock": {
		"name": "지역 2 · 냥냥 항구 창고단지", "short": "냥냥 항구 · 창고단지", "danger": "★★★", "reward": "★★★",
		"info": "제한 14분 · 탈출구 2곳 (A 선착장 보트: 항상 열림 / B 하역장 트럭: 창고 발전기 필요)\n컨테이너 미로와 큰 창고 · 흑냥이가 많고 저격수가 컨테이너 사이를 노린다 · 사물함·공구함이 많아 부품·갑옷 재료가 잘 나온다",
		"floor": "res://assets/sprites/map/floor_dock.png", "minimap": "res://assets/sprites/map/floor_dock.png",
		"exits": {"A": ["A 선착장", "boat"], "B": ["B 하역장", "truck"]},
		"lock": "창고 안 비상 발전기를 켜면 셔터가 열린다",
		"glass_row": -1, "loot": 1.15,
		"boss": ["bulldog", "항구 대장 흑냥이", "lmg"],
		"mood": {"sun": "#F2EEE6", "sun_e": 1.2, "sun_rot": Vector3(-56, -20, 0), "amb": "#BCC4D0", "amb_e": 0.82, "bg": "#1B2633", "sat": 1.04},
		"reinforce": [Vector2(54, 7), Vector2(1, 33), Vector2(30, 6), Vector2(54, 34)],
		"lights": [
			[Vector2(7, 12), "#FFE2B0", 6.0, 1.6], [Vector2(15, 12), "#FFE2B0", 6.0, 1.6], [Vector2(7, 19), "#FFE2B0", 6.0, 1.5], [Vector2(15, 19), "#FFE2B0", 6.0, 1.5],
			[Vector2(12, 10.6), "#FF8A4A", 3.0, 1.6], [Vector2(22.5, 13.5), "#FF6A5A", 4.0, 1.4],
			[Vector2(30, 12), "#BFD8FF", 7.0, 1.4], [Vector2(40, 12), "#BFD8FF", 7.0, 1.4], [Vector2(48, 12), "#BFD8FF", 6.0, 1.3],
			[Vector2(49, 23), "#FFF0D0", 6.0, 1.6], [Vector2(49, 27), "#FFF0D0", 6.0, 1.5],
			[Vector2(24.5, 3), "#7CFF9A", 4.0, 1.6], [Vector2(10, 6), "#FFD89A", 6.0, 2.0], [Vector2(38, 6), "#FFD89A", 6.0, 2.0],
			[Vector2(12, 32), "#FFB070", 6.0, 1.8], [Vector2(34, 32), "#FFB070", 6.0, 1.8], [Vector2(28, 27), "#B0C8FF", 5.0, 1.4],
		],
		"decor": [
			["lamp", 10.5, 6.9, 1.0], ["lamp", 31.5, 6.9, 1.0], ["lamp", 45.5, 6.9, 1.0], ["lamp", 18.5, 31.9, 1.0], ["lamp", 40.5, 31.9, 1.0],
			["barrel_blue", 25.4, 20.6, 0.9], ["barrel_red", 26.2, 21.4, 0.9], ["barrel_blue", 43.4, 18.5, 0.9], ["pallet", 37.5, 19.6, 0.9],
			["tires", 30.6, 26.4, 0.9], ["cone", 21.6, 31.5, 0.7], ["cone", 23.2, 31.6, 0.7], ["crate_small", 17.6, 8.5, 0.8],
			["barrier_concrete", 2.6, 31.0, 0.9], ["barrier_stripe", 52.0, 31.0, 0.8], ["sandbags", 28.5, 7.9, 0.9], ["crate_blue", 49.4, 8.5, 0.9],
			["bush", 3.4, 23.6, 0.9], ["rock", 8.5, 29.6, 0.8], ["stump", 11.6, 23.8, 0.8], ["cardboard", 35.5, 22.6, 0.8],
			# 부두 크레인 (북쪽 바다 쪽, 플레이어를 가리지 않는 자리)
			["proc:crane", 12.0, 5.6, 1.0], ["proc:crane", 41.0, 5.6, 1.0],
		],
	},
	"town": {
		"name": "지역 3 · 냥냥 주택가와 공원", "short": "냥냥 주택가 · 공원", "danger": "★★☆", "reward": "★★★",
		"info": "제한 14분 · 탈출구 2곳 (A 맨홀: 항상 열림 / B 차고 트럭: 차고 발전기 필요)
넓은 풀숲 공원(웅크리면 숨기 좋다) · 연못 · 집 세 채를 뒤지면 냉장고·약품함·사물함이 많다",
		"floor": "res://assets/sprites/map/floor_town.png", "minimap": "res://assets/sprites/map/floor_town.png",
		"exits": {"A": ["A 맨홀", "manhole"], "B": ["B 차고 트럭", "truck"]},
		"lock": "차고 안 발전기를 켜면 셔터가 열린다",
		"glass_row": -1, "loot": 1.1,
		"boss": ["hyena", "골목대장 길냥이", "smg"],
		"mood": {"sun": "#FFC48A", "sun_e": 1.4, "sun_rot": Vector3(-34, -62, 0), "amb": "#C9B4D6", "amb_e": 0.68, "bg": "#1E1A24", "sat": 1.16},
		"reinforce": [Vector2(54, 2), Vector2(1, 2), Vector2(54, 37), Vector2(28, 1)],
		"lights": [
			[Vector2(7.5, 25), "#FFE9C4", 6.0, 1.6], [Vector2(21.5, 25), "#FFE9C4", 6.0, 1.6], [Vector2(35, 25), "#FFE9C4", 6.0, 1.6],
			[Vector2(47.5, 26), "#FFD9A0", 6.0, 1.5], [Vector2(47, 23), "#FF8A4A", 3.0, 1.4], [Vector2(53.5, 27.5), "#FF6A5A", 4.0, 1.3],
			[Vector2(10, 17), "#FFD89A", 6.0, 2.0], [Vector2(26, 17), "#FFD89A", 6.0, 2.0], [Vector2(42, 17), "#FFD89A", 6.0, 2.0],
			[Vector2(26, 7), "#9FD8FF", 7.0, 1.4], [Vector2(8, 5), "#C8FFB0", 6.0, 1.0], [Vector2(46, 9), "#C8FFB0", 6.0, 1.0],
			[Vector2(21, 34), "#FFB070", 5.0, 1.2], [Vector2(48, 35), "#B0C8FF", 5.0, 1.4], [Vector2(3.5, 17), "#7CFF9A", 3.5, 1.6],
		],
		"decor": [
			["lamp", 6.5, 15.9, 1.0], ["lamp", 22.5, 15.9, 1.0], ["lamp", 38.5, 15.9, 1.0], ["lamp", 50.5, 15.9, 1.0],
			["lamp", 12.5, 19.9, 1.0], ["lamp", 32.5, 19.9, 1.0],
			["bush", 3.5, 2.6, 1.0], ["bush", 11.6, 2.8, 0.9], ["bush", 6.4, 9.6, 1.0], ["bush", 37.5, 9.6, 0.9], ["bush", 44.2, 3.0, 1.0],
			["bush", 52.6, 12.4, 0.9], ["bush", 24.0, 12.9, 0.8], ["bush", 30.5, 1.9, 0.8], ["stump", 19.5, 2.5, 0.9], ["rock", 33.5, 9.6, 0.9],
			["rock", 18.6, 9.5, 0.8], ["bush", 9.5, 33.6, 0.9], ["bush", 33.6, 35.6, 0.9], ["bush", 38.6, 32.6, 0.8],
			["cone", 27.4, 18.6, 0.7], ["barrier_stripe", 49.6, 19.5, 0.8], ["tires", 44.6, 33.6, 0.9], ["pallet", 50.5, 36.6, 0.9],
			# 공원: 북쪽 가장자리 나무(플레이어를 가리지 않게), 연못가 벤치, 꽃밭, 피크닉 테이블
			["proc:tree", 2.6, 1.6, 1.0], ["proc:tree2", 8.6, 1.5, 0.95], ["proc:tree", 24.0, 1.4, 1.05], ["proc:tree2", 29.6, 1.6, 0.9],
			["proc:tree", 37.2, 1.5, 1.0], ["proc:tree2", 46.5, 1.4, 1.0], ["proc:tree", 52.5, 1.6, 0.95],
			["proc:bench", 22.0, 2.4, 1.0], ["proc:bench", 27.0, 2.4, 1.0], ["proc:bench", 22.5, 12.9, 1.0, 180.0], ["proc:bench", 28.5, 12.9, 1.0, 180.0],
			["proc:flowerbed", 10.5, 12.8, 1.0], ["proc:flowerbed", 36.5, 12.8, 1.0], ["proc:flowerbed", 44.0, 12.8, 1.0],
			["proc:picnic", 49.5, 3.2, 1.0], ["proc:picnic", 6.5, 7.2, 1.0],
			# 집 앞 우체통
			["proc:mailbox", 6.3, 20.7, 1.0], ["proc:mailbox", 20.3, 20.7, 1.0], ["proc:mailbox", 34.3, 20.7, 1.0],
			# 집 안 가구 (집 세 채)
			["proc:rug", 7.5, 26.6, 1.0], ["proc:bed", 10.6, 24.8, 1.0], ["proc:sofa", 4.6, 27.0, 1.0, 90.0], ["proc:tv", 3.5, 24.0, 1.0, 90.0],
			["proc:rug2", 19.8, 27.4, 1.0], ["proc:bed", 25.4, 24.4, 1.0], ["proc:table", 19.4, 23.6, 1.0],
			["proc:rug", 36.0, 27.0, 1.0], ["proc:bed", 38.6, 24.4, 1.0], ["proc:table", 32.4, 24.0, 1.0],
			# 놀이터 (진흙 마당)
			["proc:swing", 19.5, 33.4, 1.0], ["proc:slide", 25.8, 33.5, 1.0], ["proc:seesaw", 18.6, 36.3, 1.0],
		],
	},
}

const SUBWAY := {
	"name": "지역 4 · 냥냥 지하철역", "short": "냥냥 지하철역", "danger": "★★★", "reward": "★★★",
	"info": "제한 14분 · 탈출구 2곳 (A 비상계단: 항상 열림 / B 정비 터널: 정비 창고 발전기 필요)\n대합실 개찰구 · 승강장 둘 · 선로에 멈춘 열차 사이를 오가며 싸운다 · 실내라 날씨 영향 없음 · 매점·사물함이 많다",
	"floor": "res://assets/sprites/map/floor_subway.png", "minimap": "res://assets/sprites/map/floor_subway.png",
	"exits": {"A": ["A 비상계단", "manhole"], "B": ["B 정비 터널", "truck"]},
	"lock": "정비 창고 발전기를 켜면 셔터가 열린다",
	"glass_row": -1, "loot": 1.2, "indoor": true, "z_model": "train",
	"boss": ["bulldog", "역무원 대장 흑냥이", "battle_rifle"],
	"mood": {"sun": "#DDE6F0", "sun_e": 0.25, "sun_rot": Vector3(-80, -20, 0), "amb": "#C8D4E0", "amb_e": 0.62, "bg": "#0C0E12", "sat": 1.0},
	"reinforce": [Vector2(9, 3), Vector2(1, 12), Vector2(54, 22), Vector2(2, 35)],
	"lights": [
		[Vector2(8, 4), "#FFE9C4", 6.0, 1.5], [Vector2(20, 4), "#E6F0FF", 7.0, 1.6], [Vector2(30, 4), "#E6F0FF", 7.0, 1.6], [Vector2(44, 4), "#FFE9C4", 7.0, 1.6],
		[Vector2(6, 12), "#E6F0FF", 7.0, 1.7], [Vector2(18, 12), "#E6F0FF", 7.0, 1.7], [Vector2(30, 12), "#E6F0FF", 7.0, 1.7], [Vector2(42, 12), "#E6F0FF", 7.0, 1.7], [Vector2(52, 12), "#E6F0FF", 6.0, 1.6],
		[Vector2(6, 22), "#E6F0FF", 7.0, 1.7], [Vector2(18, 22), "#E6F0FF", 7.0, 1.7], [Vector2(30, 22), "#E6F0FF", 7.0, 1.7], [Vector2(42, 22), "#E6F0FF", 7.0, 1.7], [Vector2(52, 22), "#E6F0FF", 6.0, 1.6],
		[Vector2(14, 17), "#FF5A4A", 4.0, 1.0], [Vector2(40, 27), "#FF5A4A", 4.0, 1.0],
		[Vector2(7, 34), "#FFD9A0", 6.0, 1.4], [Vector2(26, 34), "#B0C8FF", 7.0, 1.4], [Vector2(46, 34), "#FF8A4A", 6.0, 1.6], [Vector2(53, 34), "#7CFF9A", 3.5, 1.6],
	],
	"decor": [
		["proc:bench", 9.0, 10.8, 1.0, 180.0], ["proc:bench", 33.0, 10.8, 1.0, 180.0], ["proc:bench", 50.0, 10.8, 1.0, 180.0],
		["proc:bench", 9.0, 23.6, 1.0], ["proc:bench", 22.0, 23.6, 1.0], ["proc:bench", 45.0, 23.6, 1.0],
		["cone", 30.5, 31.5, 0.7], ["cone", 31.5, 31.6, 0.7], ["barrier_stripe", 12.5, 33.0, 0.8], ["pallet", 22.5, 37.6, 0.9], ["tires", 34.5, 37.6, 0.9],
		["cardboard", 3.4, 7.6, 0.8], ["crate_small", 33.6, 6.6, 0.8],
	],
}

static func cur() -> Dictionary:
	return get_info(LevelData.region)

static func get_info(id: String) -> Dictionary:
	if id == "subway":
		return SUBWAY
	return DATA.get(id, DATA.mart)
