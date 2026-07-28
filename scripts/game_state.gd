extends Node
## Глобальное состояние забега (автозагрузка GameState).

var arena: TileMapLayer = null
var map_rect := Rect2(32, 48, 960, 512)    # вся нарисованная карта
var play_rect := Rect2(50, 66, 924, 448)   # играбельная зона (карта минус стены)

var player: Node2D = null
var player_name := "ГЕРОЙ"   # задаётся в главном меню (живёт между рестартами)

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

# ---------- ДВИЖЕНИЕ С ОБХОДОМ СТЕН (коллизии по клеткам TileMap) ----------

func is_walkable(pos: Vector2) -> bool:
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
