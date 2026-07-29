extends TileMapLayer
## Арена на TileMapLayer. Свобода редактирования:
## - Рисуй карту в редакторе прямо в этой сцене (см. TUTORIAL_MAP.md).
## - Если клеток нет вообще — нарисуем арену по умолчанию сами (кольцо стен).
## - Строки тайлсета-стены: 0 (верх стены), 4 (лицо стены), 5 (низ стены), 7 (декор стен).
##   Всё остальное считается проходимым полом.

const TS := 16
# atlas-строки, считающиеся СТЕНАМИ (непроходимыми) — см. tutorial
# ряд 0  — крышки стен (верх)
# ряд 4  — лицо стены
# ряд 5  — низ стены (тень)
# ряд 7  — декор НА стенах (знамя, цепи, черепа) — висит на стене → тоже стена
# ряды 1,2,3,6,8,9 — пол/предметы (проходимо), КРОМЕ закрытых дверей (см. door.gd)
const WALL_ROWS := [0, 4, 5, 7]
@export var default_paint := true  # сними галку, если рисуешь карту полностью сам
@export var demo_paint := false    # вкл только в обучающей сцене demo_map.tscn
var painted_default := false        # true, если арена нарисована кодом по умолчанию

func _ready() -> void:
	GameState.arena = self
	if get_used_rect().size == Vector2i.ZERO:
		if demo_paint:
			_paint_demo()
		elif default_paint:
			_paint_default()
	GameState.map_rect = _map_rect()
	GameState.play_rect = _play_rect()

func is_walkable(world_pos: Vector2) -> bool:
	var cell := local_to_map(to_local(world_pos))
	var ac := get_cell_atlas_coords(cell)
	if ac == Vector2i(-1, -1):
		return false  # пустота за пределами рисованной карты — непроходима
	if GameState.closed_doors.has(cell):
		return false  # закрытая дверь — стена и для героя, и для врагов, и для снарядов
	return not WALL_ROWS.has(ac.y)

## клетка проходима по тайлам? (без учёта дверей — их добавляет сетка GameState)
func grid_cell_walkable(cell: Vector2i) -> bool:
	var ac := get_cell_atlas_coords(cell)
	return ac != Vector2i(-1, -1) and not WALL_ROWS.has(ac.y)

func _map_rect() -> Rect2:
	var u := get_used_rect()
	if u.size == Vector2i.ZERO:
		return Rect2(32, 48, 960, 512)
	return Rect2(Vector2(u.position) * TS, Vector2(u.size) * TS)

func _play_rect() -> Rect2:
	# играбельная зона = карта минус 2 тайла стен по краю
	var u := get_used_rect()
	if u.size == Vector2i.ZERO:
		push_warning("Карта пуста и default_paint выключен — использую стандартные границы")
		return Rect2(50, 66, 924, 448)
	return Rect2(
		Vector2(u.position) * TS + Vector2(TS * 2, TS * 2),
		Vector2(u.size) * TS - Vector2(TS * 4, TS * 4))

# ---------- АРЕНА ПО УМОЛЧАНИЮ (64x36, кольцо стен) ----------

func _paint_default() -> void:
	painted_default = true
	seed(11)
	var floor_pool: Array = []
	for r in [1, 2, 3]:
		for c in range(1, 5):
			floor_pool.append(Vector2i(c, r))
	var cap: Array = []
	for c in range(1, 6):
		cap.append(Vector2i(c, 0))
	var face: Array = []
	for c in range(0, 6):
		face.append(Vector2i(c, 4))
	var shad: Array = []
	for c in range(0, 3):
		shad.append(Vector2i(c, 5))
	var w_size := 64
	var h_size := 36
	# пол (внешние 2 кольца клеток НЕ красим — остаются пустыми = непроходимая пустота)
	for ty in range(2, h_size - 2):
		for tx in range(2, w_size - 2):
			set_cell(Vector2i(tx, ty), 0, floor_pool[randi() % floor_pool.size()])
	# верхняя стена: cap + face по порядку
	for tx in range(w_size):
		set_cell(Vector2i(tx, 2), 0, cap[tx % cap.size()])
		set_cell(Vector2i(tx, 3), 0, face[tx % face.size()])
	# нижняя стена: face + shad
	for tx in range(w_size):
		set_cell(Vector2i(tx, h_size - 4), 0, face[tx % face.size()])
		set_cell(Vector2i(tx, h_size - 3), 0, shad[tx % shad.size()])
	# боковые стены
	for ty in range(4, h_size - 4):
		set_cell(Vector2i(2, ty), 0, face[ty % face.size()])
		set_cell(Vector2i(w_size - 3, ty), 0, face[ty % face.size()])
	# декор стен: знамя, черепа, лестницы
	for kv in [[9, Vector2i(2, 7)], [22, Vector2i(3, 7)], [41, Vector2i(4, 7)], [54, Vector2i(2, 7)]]:
		set_cell(Vector2i(kv[0], 3), 0, kv[1])
	for tx in [14, 49]:
		set_cell(Vector2i(tx, 3), 0, Vector2i(9, 3))
	# дверь внизу по центру
	set_cell(Vector2i(int(w_size / 2.0), h_size - 3), 0, Vector2i(8, 3))

# ---------- ОБУЧАЮЩАЯ КАРТА (demo_map.tscn): зал с колоннами, дверью и проёмом ----------
# Показывает правильную структуру: cap(ряд 0)+face(ряд 4) сверху, face+shad(ряд 5) снизу,
# боковые стены столбцом face, пол из рядов 1-3, редкие треснувшие плиты ряда 6.

func _paint_demo() -> void:
	seed(7)
	var floor_pool: Array = []
	for r in [1, 2, 3]:
		for c in range(1, 5):
			floor_pool.append(Vector2i(c, r))
	var cap: Array = []
	for c in range(1, 6):
		cap.append(Vector2i(c, 0))
	var face: Array = []
	for c in range(0, 6):
		face.append(Vector2i(c, 4))
	# пол
	for ty in range(4, 20):
		for tx in range(3, 37):
			var t: Vector2i = floor_pool[randi() % floor_pool.size()]
			if randf() < 0.08:  # треснувшие плиты для живости
				t = Vector2i(randi() % 4, 6)
			set_cell(Vector2i(tx, ty), 0, t)
	# верхняя стена: cap + face
	for tx in range(2, 38):
		set_cell(Vector2i(tx, 2), 0, cap[tx % cap.size()])
		set_cell(Vector2i(tx, 3), 0, face[tx % face.size()])
	# нижняя стена: face + shad
	for tx in range(2, 38):
		set_cell(Vector2i(tx, 20), 0, face[tx % face.size()])
		set_cell(Vector2i(tx, 21), 0, Vector2i(tx % 3, 5))
	# боковые стены
	for ty in range(4, 20):
		set_cell(Vector2i(2, ty), 0, face[ty % face.size()])
		set_cell(Vector2i(37, ty), 0, face[ty % face.size()])
	# дверь внизу по центру (живая — вскрывается при подходе)
	set_cell(Vector2i(20, 20), 0, Vector2i(8, 3))
	# верхний проём с ТРЕМЯ ЗАКРЫТЫМИ ДВЕРЬМИ (6,2) — вскрой их!
	for gap in [19, 20, 21]:
		set_cell(Vector2i(gap, 2), 0, Vector2i(2, 1))
		set_cell(Vector2i(gap, 3), 0, Vector2i(6, 2))
	# колонны 2x2 (капители сверху, грани снизу) — непроходимые
	for p in [Vector2i(10, 8), Vector2i(27, 8), Vector2i(10, 15), Vector2i(27, 15)]:
		set_cell(p, 0, Vector2i(1, 0))
		set_cell(p + Vector2i(1, 0), 0, Vector2i(3, 0))
		set_cell(p + Vector2i(0, 1), 0, Vector2i(1, 4))
		set_cell(p + Vector2i(1, 1), 0, Vector2i(3, 4))
	# декор стен: знамя (вне проёма!), цепи, череп
	set_cell(Vector2i(17, 3), 0, Vector2i(4, 7))
	set_cell(Vector2i(12, 3), 0, Vector2i(5, 7))
	set_cell(Vector2i(29, 3), 0, Vector2i(7, 7))
