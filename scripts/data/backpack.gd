class_name Backpack
extends RefCounted
## 그리드 배낭. 아이템은 크기만큼 칸을 차지하고, 자리가 없으면 90도 돌려서라도 넣어 본다.

signal changed

var w: int
var h: int
var entries: Array = []  # [{id, x, y, rot}]

func _init(width: int = DB.BACKPACK_W, height: int = DB.BACKPACK_H) -> void:
	w = width
	h = height

static func size_of(id: String, rot: bool) -> Vector2i:
	var it: Dictionary = DB.ITEMS[id]
	return Vector2i(it.h, it.w) if rot else Vector2i(it.w, it.h)

func _occupied(skip: int = -1) -> Array:
	var grid := []
	grid.resize(w * h)
	grid.fill(false)
	for i in entries.size():
		if i == skip:
			continue
		var e: Dictionary = entries[i]
		var s := size_of(e.id, e.rot)
		for yy in s.y:
			for xx in s.x:
				grid[(e.y + yy) * w + e.x + xx] = true
	return grid

func can_place(id: String, x: int, y: int, rot: bool, skip: int = -1) -> bool:
	var s := size_of(id, rot)
	if x < 0 or y < 0 or x + s.x > w or y + s.y > h:
		return false
	var grid := _occupied(skip)
	for yy in s.y:
		for xx in s.x:
			if grid[(y + yy) * w + x + xx]:
				return false
	return true

var has_cheek := false  # 플레이어 배낭: 왼쪽 위가 뺨주머니

## 자동으로 넣을 때는 뺨주머니를 비워 두고(직접 끌어다 넣는 칸), 다른 자리가 없을 때만 쓴다
func find_spot(id: String) -> Dictionary:
	for pass_i in (2 if has_cheek else 1):
		for rot in [false, true]:
			for y in h:
				for x in w:
					if pass_i == 0 and has_cheek and _overlaps_cheek(id, x, y, rot):
						continue
					if can_place(id, x, y, rot):
						return {"x": x, "y": y, "rot": rot}
	return {}

func _overlaps_cheek(id: String, x: int, y: int, rot: bool) -> bool:
	var s := size_of(id, rot)
	return x < DB.CHEEK_W and y < DB.CHEEK_H and x + s.x > 0 and y + s.y > 0

func in_cheek(e: Dictionary) -> bool:
	var s := size_of(e.id, e.rot)
	return has_cheek and e.x + s.x <= DB.CHEEK_W and e.y + s.y <= DB.CHEEK_H

## 뺨주머니에 완전히 들어간 아이템 id 목록 (사망해도 지켜짐)
func cheek_ids() -> Array:
	var out := []
	for e in entries:
		if in_cheek(e):
			out.append(e.id)
	return out

## 적재율 0~1
func load_ratio() -> float:
	return float(used_cells()) / float(w * h)

func try_add(id: String) -> bool:
	var spot := find_spot(id)
	if spot.is_empty():
		return false
	entries.append({"id": id, "x": spot.x, "y": spot.y, "rot": spot.rot})
	changed.emit()
	return true

func move(index: int, x: int, y: int, rot: bool) -> bool:
	var e: Dictionary = entries[index]
	if not can_place(e.id, x, y, rot, index):
		return false
	e.x = x
	e.y = y
	e.rot = rot
	changed.emit()
	return true

func remove_at(index: int) -> String:
	var id: String = entries[index].id
	entries.remove_at(index)
	changed.emit()
	return id

func index_at_cell(cx: int, cy: int) -> int:
	for i in entries.size():
		var e: Dictionary = entries[i]
		var s := size_of(e.id, e.rot)
		if cx >= e.x and cx < e.x + s.x and cy >= e.y and cy < e.y + s.y:
			return i
	return -1

func find_first(id: String) -> int:
	for i in entries.size():
		if entries[i].id == id:
			return i
	return -1

func count(id: String) -> int:
	var n := 0
	for e in entries:
		if e.id == id:
			n += 1
	return n

func total_value() -> int:
	var v := 0
	for e in entries:
		v += int(DB.ITEMS[e.id].v)
	return v

func used_cells() -> int:
	var n := 0
	for e in entries:
		var s := size_of(e.id, e.rot)
		n += s.x * s.y
	return n

func ids() -> Array:
	var out := []
	for e in entries:
		out.append(e.id)
	return out
