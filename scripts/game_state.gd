extends Node
## Глобальное состояние забега (автозагрузка GameState).

var arena: TileMapLayer = null
var map_rect := Rect2(32, 48, 960, 512)    # вся нарисованная карта
var play_rect := Rect2(50, 66, 924, 448)   # играбельная зона (карта минус стены)

var player: Node2D = null
var player_name := "ГЕРОЙ"   # задаётся в главном меню (живёт между рестартами)

# ---------- СОХРАНЕНИЕ ПРОФИЛЯ (ник + настройки — между запусками игры!) ----------
const SAVE_PATH := "user://dungeon_survivors.cfg"

## записать ник и все переключатели настроек на диск
func save_profile() -> void:
	var c := ConfigFile.new()
	c.set_value("profile", "player_name", player_name)
	c.set_value("settings", "opt_manual_aim", opt_manual_aim)
	c.set_value("settings", "opt_minimap", opt_minimap)
	c.set_value("settings", "opt_slowmo", opt_slowmo)
	c.set_value("settings", "sfx_volume", SFX.sfx_volume)
	c.set_value("settings", "music_volume", SFX.music_volume)
	c.save(SAVE_PATH)

## прочитать ник и настройки (вызывается main при запуске, до постройки HUD)
func load_profile() -> void:
	var c := ConfigFile.new()
	if c.load(SAVE_PATH) != OK:
		return
	player_name = str(c.get_value("profile", "player_name", "ГЕРОЙ"))
	opt_manual_aim = bool(c.get_value("settings", "opt_manual_aim", false))
	opt_minimap = bool(c.get_value("settings", "opt_minimap", true))
	opt_slowmo = bool(c.get_value("settings", "opt_slowmo", true))
	SFX.set_sfx_volume(float(c.get_value("settings", "sfx_volume", 0.75)))
	SFX.set_music_volume(float(c.get_value("settings", "music_volume", 0.45)))

# ---------- НАСТРОЙКИ (переключаются на паузе, живут между забегами) ----------
var opt_manual_aim := false  # ручная стрельба мышью (зажми ЛКМ и целься)
var opt_minimap := true      # мини-карта в углу
var opt_slowmo := true       # слоу-мо + вспышка на смерти босса

# ---------- СТАТИСТИКА ЗАБЕГА (для экрана смерти, чистится в reset) ----------
var dist_traveled := 0.0     # пройдено пикселей
var darts_fired := 0
var slashes_used := 0
var shots_hit := 0           # попадания дротиками (для точности)

# ---------- КОМБО (серия убийств без паузы -> звонкие монеты) ----------
var combo := 0
var combo_t := 0.0

# ---------- ТРУПЫ (некромант ведёт реестр: позиция, тип, ост. времени) ----------
var corpses := []
var enemies: Array = []
var pickups: Array = []
var breakables: Array = []   # разрушаемые ящики (crate.gd)
var closed_doors := {}          # Vector2i -> Door: закрытые двери (непроходимы, см. door.gd)
var kills := 0
var run_time := 0.0
var current_boss: Node2D = null
var game_over := false
var won := false

var minutes: float:
	get: return run_time / 60.0

func _ready() -> void:
	_setup_input()

# Управление: WASD + стрелки (physical_keycode — раскладка клавиатуры не важна,
# т.е. WASD работает и на русской раскладке).
func _setup_input() -> void:
	var binds := {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"dash": [KEY_SPACE],  # рывок
	}
	for action in binds:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in binds[action]:
			var already := false
			for old_ev in InputMap.action_get_events(action):
				if old_ev is InputEventKey and old_ev.physical_keycode == key:
					already = true
			if not already:
				var ev := InputEventKey.new()
				ev.physical_keycode = key
				InputMap.action_add_event(action, ev)

func reset() -> void:
	# arena/map_rect/play_rect НЕ трогаем: Arena регистрирует себя в _ready
	# (дети сцены готовятся раньше родителя, т.е. до вызова reset из Main)
	# player_name и настройки opt_* НЕ чистим — живут между забегами
	player = null
	enemies = []
	pickups = []
	breakables = []
	closed_doors = {}
	kills = 0
	run_time = 0.0
	current_boss = null
	game_over = false
	won = false
	dist_traveled = 0.0
	darts_fired = 0
	slashes_used = 0
	shots_hit = 0
	combo = 0
	combo_t = 0.0
	corpses = []
	walk_w = 0   # сетка проходимости недействительна до setup_walk_grid новой сцены

# ---------- КЭШ ПРОХОДИМОСТИ (антилаг v0.15) ----------
# Раньше КАЖДЫЙ is_walkable дёргал TileMapLayer (local_to_map + atlas-координаты)
# по 5 раз на врага за кадр — при толпе в 60+ мобов это сотни нативных вызовов/кадр.
# Теперь карта проходимости — плоский байтовый массив: проверка = одно чтение.
var walk_layer := Vector2.ZERO   # где стоит узел арены в мире
var walk_origin := Vector2i.ZERO # координаты первой клетки карты (в клетках)
var walk_w := 0
var walk_h := 0
var walk_grid := PackedByteArray()

## строится main'ом ПОСЛЕ покраски карты и регистрации дверей
func setup_walk_grid() -> void:
	walk_w = 0
	if arena == null:
		return
	var u: Rect2i = arena.get_used_rect()
	if u.size.x <= 0 or u.size.y <= 0:
		return
	walk_origin = u.position
	walk_w = u.size.x
	walk_h = u.size.y
	walk_layer = arena.global_position
	walk_grid = PackedByteArray()
	walk_grid.resize(walk_w * walk_h)
	for y in range(walk_h):
		for x in range(walk_w):
			var cell := Vector2i(walk_origin.x + x, walk_origin.y + y)
			walk_grid[y * walk_w + x] = 1 if arena.grid_cell_walkable(cell) else 0
	# закрытые двери — стены (вскроются позже через set_walkable)
	for cell in closed_doors:
		set_walkable(cell, false)

## дверь открылась (или ломаем клетку): обновить одну клетку кэша
func set_walkable(cell: Vector2i, ok: bool) -> void:
	if walk_w <= 0:
		return
	var lx := cell.x - walk_origin.x
	var ly := cell.y - walk_origin.y
	if lx < 0 or ly < 0 or lx >= walk_w or ly >= walk_h:
		return
	walk_grid[ly * walk_w + lx] = 1 if ok else 0

# ---------- ДВИЖЕНИЕ С ОБХОДОМ СТЕН (коллизии по клеткам TileMap) ----------

func is_walkable(pos: Vector2) -> bool:
	# быстрый путь: байтовая карта проходимости (самый горячий вызов игры!)
	if walk_w > 0 and walk_grid.size() == walk_w * walk_h:
		var lx := int(floor((pos.x - walk_layer.x) / 16.0)) - walk_origin.x
		var ly := int(floor((pos.y - walk_layer.y) / 16.0)) - walk_origin.y
		if lx < 0 or ly < 0 or lx >= walk_w or ly >= walk_h:
			return false
		return walk_grid[ly * walk_w + lx] == 1
	# запасной путь: как раньше, напрямую по тайлмапу
	if arena == null:
		return play_rect.has_point(pos)
	return arena.is_walkable(pos)

func _circle_walkable(p: Vector2, r: float) -> bool:
	return (
		is_walkable(p)
		and is_walkable(p + Vector2(r, 0))
		and is_walkable(p - Vector2(r, 0))
		and is_walkable(p + Vector2(0, r * 0.6))
		and is_walkable(p - Vector2(0, r * 0.6))
	)

func slide_move(from: Vector2, motion: Vector2, radius := 6.0) -> Vector2:
	# движение по осям: даёт скольжение вдоль стен вместо полной остановки
	var res := from
	var tx := Vector2(from.x + motion.x, from.y)
	if _circle_walkable(tx, radius):
		res.x = tx.x
	var ty := Vector2(res.x, from.y + motion.y)
	if _circle_walkable(ty, radius):
		res.y = ty.y
	return res

func random_walkable_near(center: Vector2, min_r: float, max_r: float, margin := 10.0) -> Vector2:
	# ищем проходимую точку кольцом вокруг center
	for i in range(10):
		var r := randf_range(min_r, max_r + 20.0)
		var pos := center + Vector2.from_angle(randf() * TAU) * r
		if play_rect.has_point(pos) and _circle_walkable(pos, margin):
			return pos
	# запасной вариант — центр карты
	return play_rect.get_center()

# ---------- СТАТИСТИКА ----------

func score() -> int:
	return kills + int(run_time * 0.25)

func rank() -> String:
	var s := score()
	var r := "F"
	if s >= 650 or (won and s >= 500):
		r = "S"
	elif s >= 450:
		r = "A"
	elif s >= 300:
		r = "B"
	elif s >= 180:
		r = "C"
	elif s >= 80:
		r = "D"
	return r
