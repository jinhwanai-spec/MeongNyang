class_name Regions
extends RefCounted
## 원정 지역 정보 (지도는 LevelData.MAPS). 은신처 출발 준비에서 고른다.

const ORDER := ["mart", "dock"]

const DATA := {
	"mart": {
		"name": "지역 1 · 멍냥마트와 뒷골목", "short": "멍냥마트 · 뒷골목", "danger": "★★☆", "reward": "★★☆",
		"info": "제한 14분 · 탈출구 2곳 (A 맨홀: 항상 열림 / B 하역장: 발전기 필요)\n출몰: 길냥이 돌격병(빠름) · 중장갑 흑냥이(망치·돌진) · 흰냥 저격수(조준선 주의)",
		"floor": "res://assets/sprites/map/floor.png", "minimap": "res://assets/sprites/map/map_top.png",
		"exits": {"A": ["A 맨홀", "manhole"], "B": ["B 하역장", "truck"]},
		"lock": "창고의 비상 발전기를 켜야 열린다",
		"glass_row": 16, "loot": 1.0,
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
		],
	},
}

static func cur() -> Dictionary:
	return DATA.get(LevelData.region, DATA.mart)

static func get_info(id: String) -> Dictionary:
	return DATA.get(id, DATA.mart)
