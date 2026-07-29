extends Node2D
## Главная сцена: арена, декор, директор волн, боссы, камера, игровой цикл.
##
## === НАСТРОЙКИ БЕЗ КОДА (выдели узел Main в дереве сцены → Инспектор) ===
## - Спавн врагов: радиус кольца, интервал, лимит врагов.
## - Камера: зум и плавность.
## - Лут: вкл/выкл периодический дроп на карту.
##
## === ТОЧКИ НА КАРТЕ (добавляй дочерние узлы к Main) ===
## - Узел "SpawnPoints" (Node2D) с маркерами (Marker2D) внутри — враги лезут ОТТУДА.
## - Узел "PickupPoints" — там появляются сундуки/флаконы.
## - Маркер "PlayerStart" — точка появления героя.
##   (работают и группы: enemy_spawn / pickup_spawn / player_start)
##
## === ВТОРОЙ TILEMAP-СЛОЙ (декор) ===
## Нарисуй на нём монетки/флаконы/ключи/сундуки/факелы/свечи — на старте игры
## они ОЖИВУТ: тайл стирается, вместо него появляется настоящий предмет.
## Этот слой НИЧЕГО не блокирует: коллизии считаются только по слою Arena.

var player: Player
var hud
var music_track := "music_main"   # боевой трек этой сцены (у demo_map — music_tuto)
var enemies_node: Node2D
var bullets_node: Node2D
var pickups_node: Node2D
var effects_node: Node2D
var decor_node: Node2D
var camera: Camera2D

# ---- НАСТРОЙКИ В ИНСПЕКТОРЕ ----
@export_group("Спавн врагов")
@export var spawn_radius := 170.0    # радиус кольца вокруг героя (если нет SpawnPoints)
@export var interval_start := 1.15   # сек между спавнами в начале игры
@export var interval_min := 0.30     # самый частый интервал (к концу)
@export var cap_start := 14          # максимум врагов на старте
@export var cap_max := 64            # жёсткий лимит врагов на карте
@export_group("Лут")
@export var world_loot := true       # периодически сыпать монеты/флаконы на карту
@export_group("Камера")
@export var camera_zoom := 1.0       # больше — ближе (например 1.5), меньше — дальше
@export var camera_smooth := 6.0     # скорость плавного догона камеры

# нарисованные на декор-слое тайлы -> подбираемые предметы (atlas-координаты тайлсета)
const LOOT_TILES := {
	Vector2i(6, 8): "coin",        # золотая монета
	Vector2i(7, 8): "gem",         # синий флакон (опыт)
	Vector2i(7, 9): "gem",         # большой синий флакон
	Vector2i(9, 8): "heal",        # красный флакон (лечение)
	Vector2i(8, 9): "heal_big",    # большой красный флакон
	Vector2i(8, 8): "key_silver",  # серебряный ключ
	Vector2i(9, 9): "key_gold",    # золотой ключ
	Vector2i(0, 8): "chest",       # большие сундуки
	Vector2i(1, 8): "chest",
	Vector2i(2, 8): "chest",
	Vector2i(3, 8): "chest",
	Vector2i(4, 8): "mini_chest",  # мини-сундуки
	Vector2i(5, 8): "mini_chest",
}
	# тайлы -> анимированный декор (факелы и свечи горят!)
const DECOR_TILES := {
	Vector2i(0, 9): "assets/items/torch",
	Vector2i(1, 9): "assets/items/torch",
	Vector2i(2, 9): "assets/items/candle2",
	Vector2i(3, 9): "assets/items/candle1",
	Vector2i(5, 9): "assets/items/candle1",
}
# параметры света для каждого типа декора: [цвет, радиус, яркость]
const DECOR_LIGHT := {
	"assets/items/torch": [Color(1.0, 0.72, 0.40), 1.15, 0.95],
	"assets/items/torch_side": [Color(1.0, 0.72, 0.40), 0.95, 0.85],
	"assets/items/candle1": [Color(1.0, 0.78, 0.45), 0.60, 0.60],
	"assets/items/candle2": [Color(1.0, 0.78, 0.45), 0.50, 0.50],
}

var _spawn_t := 0.0
var _event_t := 20.0      # кольца мобов
var _chest_t := 45.0      # периодический сундук
var _loot_t := 18.0       # периодические монеты/флаконы на карте
var _loot_cycle := 0
var _boss_idx := 0
var _mini_idx := 0      # следующий мини-босс по расписанию
var _spawn_points: Array = []
var _pickup_points: Array = []
var _flickers: Array = []  # PointLight2D'ы с мерцанием (факелы/свечи)
var _light_tex: Texture2D = null

func _mk_light(color: Color, tex_scale: float, energy: float) -> PointLight2D:
	if _light_tex == null:
		_light_tex = load("res://assets/fx/light_warm.png")
	var l := PointLight2D.new()
	l.texture = _light_tex
	l.color = color
	l.texture_scale = tex_scale
	l.energy = energy
	l.shadow_enabled = false
	l.set_meta("base_e", energy)
	_flickers.append(l)
	return l

func _decor_with_light(anim_path: String, pos: Vector2) -> AnimatedSprite2D:
	var spr := AnimLib.sprite(anim_path, 6.0, true)
	spr.global_position = pos
	decor_node.add_child(spr)
	var lp: Array = DECOR_LIGHT.get(anim_path, [])
	if not lp.is_empty():
		var l := _mk_light(lp[0], lp[1], lp[2])
		l.position = pos + Vector2(0, -3)
		decor_node.add_child(l)
	return spr

func _ready() -> void:
	GameState.reset()
	GameState.load_profile()  # ник и настройки с прошлого запуска
	SFX.attach(self)  # звуки и музыка (assets/sfx)
	# обучающая сцена (demo_map.tscn) идёт под свою спокойную музыку
	var scn := get_tree().current_scene
	if scn and scn.scene_file_path.ends_with("demo_map.tscn"):
		music_track = "music_tuto"
	# контейнеры по z-порядку
	decor_node = _mk("Decor", 0, 2)
	pickups_node = _mk("Pickups", 0, 4)
	effects_node = _mk("Effects", 0, 60)
	enemies_node = _mk("Enemies", 0, 10)
	bullets_node = _mk("Bullets", 0, 11)
	FX.effects_root = effects_node
	_collect_markers()
	_scan_user_layers()   # оживляем тайлы с твоего декор-слоя (двери регистрируются тут)
	if GameState.arena and GameState.arena.painted_default:
		_decorate()       # дефолтный декор — только для дефолтной арены
	# быстрая байтовая карта проходимости — после покраски и дверей (антилаг v0.15)
	GameState.setup_walk_grid()
	# фоновая предзагрузка ВСЕХ ресурсов мелкими порциями — конец фризам при спавне
	Warmup.attach(self)
	# игрок
	player = Player.new()
	GameState.player = player
	player.global_position = _player_start()
	add_child(player)
	player.leveled_up.connect(_on_level_up)
	player.died_player.connect(_on_player_died)
	# камера: своя, НЕ привязана к герою жёстко — плавно догоняет его в _process
	camera = _find_camera()
	if camera == null:
		camera = Camera2D.new()
		add_child(camera)
	elif camera.get_parent() != self:
		camera.reparent(self)
	camera.position = player.global_position
	camera.zoom = Vector2(camera_zoom, camera_zoom)
	camera.make_current()
	# HUD
	hud = preload("res://scripts/hud.gd").new()
	add_child(hud)
	hud.bind(player)
	# стартовые прожиточные монстры
	for i in range(3):
		_spawn_enemy("skeleton1", player.global_position + Vector2.from_angle(TAU * i / 3.0) * 120)
	# главное меню (ник, старт, своя музыка)
	hud.show_menu()

func _mk(nname: String, _z := 0, _rel_z := 0) -> Node2D:
	var n := Node2D.new()
	n.name = nname
	add_child(n)
	return n

func _find_camera() -> Camera2D:
	for n in find_children("*", "Camera2D", true, false):
		return n as Camera2D
	return null

## камера мягко идёт за героем и не вылезает за края играбельной зоны
func _update_camera(delta: float) -> void:
	if camera == null:
		return
	var target := player.global_position if (player and is_instance_valid(player)) else GameState.play_rect.get_center()
	var pos2 := camera.global_position.lerp(target, minf(1.0, delta * camera_smooth))
	# кламп: полэкрана от краёв (если карта меньше экрана — держим её центр)
	var hw := 240.0 / camera_zoom
	var hh := 135.0 / camera_zoom
	var pr := GameState.play_rect.grow(24.0)
	if pr.size.x > hw * 2.0:
		pos2.x = clampf(pos2.x, pr.position.x + hw, pr.end.x - hw)
	else:
		pos2.x = pr.get_center().x
	if pr.size.y > hh * 2.0:
		pos2.y = clampf(pos2.y, pr.position.y + hh, pr.end.y - hh)
	else:
		pos2.y = pr.get_center().y
	camera.global_position = pos2

# ---------------- ТОЧКИ/МАРКЕРЫ ИЗ РЕДАКТОРА ----------------

func _collect_markers() -> void:
	_spawn_points.clear()
	_pickup_points.clear()
	var sp := get_node_or_null("SpawnPoints")
	if sp:
		for c in sp.get_children():
			if c is Node2D:
				_spawn_points.append((c as Node2D).global_position)
	var pp := get_node_or_null("PickupPoints")
	if pp:
		for c in pp.get_children():
			if c is Node2D:
				_pickup_points.append((c as Node2D).global_position)
	for c in get_tree().get_nodes_in_group("enemy_spawn"):
		if c is Node2D:
			_spawn_points.append((c as Node2D).global_position)
	for c in get_tree().get_nodes_in_group("pickup_spawn"):
		if c is Node2D:
			_pickup_points.append((c as Node2D).global_position)

func _player_start() -> Vector2:
	var ps := get_node_or_null("PlayerStart")
	if ps is Node2D:
		return (ps as Node2D).global_position
	for c in get_tree().get_nodes_in_group("player_start"):
		if c is Node2D:
			return (c as Node2D).global_position
	if GameState.arena and GameState.arena.painted_default:
		return Vector2(512, 300)
	return GameState.play_rect.get_center()

# ---------------- ОЖИВЛЕНИЕ ДЕКОР-СЛОЯ ----------------

func _scan_user_layers() -> void:
	# ВСЕ TileMapLayer сцены (включая слой Arena!):
	# монеты/флаконы/ключи/сундуки -> настоящие предметы, факелы/свечи -> горящие спрайты,
	# двери (6,2)/(8,3) на слое Arena -> живые двери (door.gd).
	for n in find_children("*", "TileMapLayer", true, false):
		var layer := n as TileMapLayer
		if layer == null:
			continue
		var is_arena := layer == GameState.arena
		for cell in layer.get_used_cells():
			var ac := layer.get_cell_atlas_coords(cell)
			var wpos := layer.to_global(layer.map_to_local(cell))
			if is_arena and Door.CLOSED_TILES.has(ac):
				add_child(Door.register(cell, ac))
			elif LOOT_TILES.has(ac):
				pickups_node.add_child(Pickup.spawn(LOOT_TILES[ac], wpos))
				_free_cell(layer, cell, is_arena)
			elif DECOR_TILES.has(ac):
				_decor_with_light(DECOR_TILES[ac], wpos)
				_free_cell(layer, cell, is_arena)

func _free_cell(layer: TileMapLayer, cell: Vector2i, is_arena: bool) -> void:
	if is_arena:
		layer.set_cell(cell, 0, Vector2i(2, 1))  # под предметом остаётся пол (дыра была бы стеной)
	else:
		layer.erase_cell(cell)

# ---------------- ДЕФОЛТНЫЙ ДЕКОР (только для дефолтной арены) ----------------

func _decorate() -> void:
	# факелы на верхней стене (со светом!)
	for x in range(96, 929, 104):
		_decor_with_light("assets/items/torch", Vector2(x, 50))
	# боковые факелы
	for y in [130, 240, 350, 460]:
		for x in [41, 983]:
			var st := _decor_with_light("assets/items/torch_side", Vector2(x, y))
			st.flip_h = x > 900
	# подсвечники у двери
	for x in [492, 548]:
		_decor_with_light("assets/items/candle1", Vector2(x, 500))
	# шипы
	for pos in [Vector2(170, 150), Vector2(854, 160), Vector2(200, 440), Vector2(810, 450), Vector2(512, 200)]:
		var s := Spikes.new()
		s.global_position = pos
		decor_node.add_child(s)
	# разрушаемые ящики с добычей (ударь дротиком или полумесяцем!)
	for pos in [Vector2(120, 100), Vector2(138, 108), Vector2(900, 120), Vector2(880, 480),
			Vector2(110, 470), Vector2(300, 130), Vector2(720, 110), Vector2(240, 370),
			Vector2(780, 400), Vector2(512, 420)]:
		decor_node.add_child(Crate.spawn(pos))
	# флаг над точкой спавна
	var flag := AnimLib.sprite("assets/items/flag", 6.0, true)
	flag.global_position = Vector2(512, 236)
	decor_node.add_child(flag)
	# декоративные мини-сундуки
	for pos in [Vector2(880, 190), Vector2(130, 420)]:
		var mc := AnimLib.sprite("assets/items/mini_chest", 5.0, true)
		mc.global_position = pos
		decor_node.add_child(mc)

func _process(delta: float) -> void:
	_update_camera(delta)
	# мерцание огня факелов/свечей (живое пламя!)
	if not _flickers.is_empty():
		var t := Time.get_ticks_msec() / 1000.0
		for l in _flickers:
			if is_instance_valid(l):
				l.energy = l.get_meta("base_e", 0.8) * (
					0.88 + 0.10 * sin(t * 9.0 + l.position.x * 0.61 + l.position.y * 1.13)
					+ 0.06 * sin(t * 23.0 + l.position.y * 0.37))
	if GameState.game_over:
		return
	GameState.run_time += delta
	# комбо: серия гаснет через 2.2 сек без убийств
	if GameState.combo_t > 0.0:
		GameState.combo_t -= delta
		if GameState.combo_t <= 0.0:
			GameState.combo = 0
	# реестр трупов для некроманта: стареют и исчезают
	for i in range(GameState.corpses.size() - 1, -1, -1):
		GameState.corpses[i]["t"] = float(GameState.corpses[i]["t"]) - delta
		if float(GameState.corpses[i]["t"]) <= 0.0:
			GameState.corpses.remove_at(i)
	if GameState.corpses.size() > 18:  # не храним гору — некроманту хватит
		GameState.corpses.remove_at(0)
	_wave_director(delta)
	_separate_enemies()
	# победа через 10 минут (продолжаем ва-банк под садовую музыку)
	if not GameState.won and GameState.run_time >= Data.WIN_TIME:
		GameState.won = true
		SFX.play("win", -1.0)
		SFX.play_music("music_win")
		hud.show_win()

# ---------------- СПАВН ----------------

func _wave_director(delta: float) -> void:
	var m := GameState.minutes
	# интервал спавна ускоряется
	var interval := maxf(interval_min, interval_start - m * 0.10)
	var cap := mini(cap_start + int(m * 9.0), cap_max)
	_spawn_t += delta
	if _spawn_t >= interval and enemies_node.get_child_count() < cap:
		_spawn_t = 0.0
		_spawn_enemy(_pick_type(GameState.run_time), _spawn_pos(m >= 5.0))
	# элитки после 4-й минуты
	if m >= 4.0 and randf() < delta * 0.055:
		_spawn_enemy(_pick_type(GameState.run_time), _spawn_pos(true), true)
	# вор-разбойник крадёт монеты (с 4-й минуты, раз в ~75 сек)
	if m >= 4.0:
		_thief_t -= delta
		if _thief_t <= 0.0:
			_thief_t = 75.0
			_spawn_thief()
	# марш скелетов (раз в ~95 сек, со 2.5-й минуты)
	if m >= 2.5:
		_march_t -= delta
		if _march_t <= 0.0:
			_march_t = 95.0
			_skeleton_march()
	# кольца мобов-сюрпризов
	_event_t -= delta
	if _event_t <= 0.0:
		_event_t = 42.0
		_skull_ring()
	# периодический сундук
	_chest_t -= delta
	if _chest_t <= 0.0:
		_chest_t = 55.0
		_spawn_pickup("chest")
	# монетки и флаконы на карту
	if world_loot:
		_loot_t -= delta
		if _loot_t <= 0.0:
			_loot_t = 20.0
			_spawn_pickup("coin")
			_spawn_pickup("coin")
			# флаконы по кругу: лечение, опыт, большой флакон
			var cycle := ["heal", "gem", "elixir", "heal_big"]
			_spawn_pickup(cycle[_loot_cycle % cycle.size()])
			_loot_cycle += 1
	# боссы по расписанию
	if _boss_idx < Data.BOSS_SCHEDULE.size():
		var bs: Dictionary = Data.BOSS_SCHEDULE[_boss_idx]
		if GameState.run_time >= bs["time"]:
			_boss_idx += 1
			_spawn_boss(bs["type"], bs["hp_mult"])
	# мини-боссы-чемпионы выходят между боссами — держат толпу в тонусе
	if _mini_idx < Data.MINI_BOSS_SCHEDULE.size():
		var mb: Dictionary = Data.MINI_BOSS_SCHEDULE[_mini_idx]
		if GameState.run_time >= mb["time"]:
			_mini_idx += 1
			_spawn_mini_boss(mb)

func _pick_type(t: float) -> String:
	var table: Array = Data.WAVE_TABLE[0][1]
	for row in Data.WAVE_TABLE:
		if t >= row[0]:
			table = row[1]
	var total := 0
	for pair in table:
		total += pair[1]
	var r := randi() % total
	for pair in table:
		r -= pair[1]
		if r < 0:
			return pair[0]
	return table[0][0]

func _spawn_pos(anywhere := false) -> Vector2:
	# 1) твои точки SpawnPoints / группа enemy_spawn
	if not _spawn_points.is_empty():
		for i in range(8):
			var base: Vector2 = _spawn_points[randi() % _spawn_points.size()]
			var pos := base + Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0))
			if GameState.is_walkable(pos):
				return pos
		return _spawn_points[randi() % _spawn_points.size()]
	# 2) иначе — кольцо вокруг героя
	return _ring_pos(spawn_radius, 60.0, anywhere)

func _ring_pos(radius := 170.0, jitter := 0.0, anywhere := false) -> Vector2:
	var p := GameState.player
	var base := p.global_position if p else GameState.play_rect.get_center()
	if anywhere:
		for i in range(12):
			var pos := Vector2(
				randf_range(GameState.play_rect.position.x + 20.0, GameState.play_rect.end.x - 20.0),
				randf_range(GameState.play_rect.position.y + 20.0, GameState.play_rect.end.y - 20.0))
			if GameState.is_walkable(pos):
				return pos
		return GameState.play_rect.get_center()
	return GameState.random_walkable_near(base, radius, radius + 30.0 + jitter, 12.0)

var _thief_t := 70.0    # вор приходит с 4-й минуты
var _march_t := 150.0   # марш скелетов строем

func _spawn_enemy(type: String, pos: Vector2, elite := false) -> Enemy:
	var e := Enemy.create(type, elite)
	e.global_position = pos
	# особые роли: берсерк-скелет (красный) и золотая элитка (дроп x3)
	if type == "skeleton2" and not elite and randf() < 0.22:
		e.berserk = true
	if elite and randf() < 0.10:
		e.golden = true
	enemies_node.add_child(e)
	GameState.enemies.append(e)
	e.died.connect(_on_enemy_died)
	return e

## вор-разбойник: крадёт монеты с пола и улепётывает
func _spawn_thief() -> void:
	var e := _spawn_enemy("dark_rogue", _spawn_pos(true))
	e.make_thief()
	hud.flash("ВОР! БЕРЕГИ МОНЕТЫ!", 1.8)
	SFX.play("scream", -3.0, 1.15)

## марш скелетов: строй восстаёт из земли и идёт колонной
func _skeleton_march() -> void:
	var base := _spawn_pos(true)
	var n := mini(10 + int(GameState.minutes * 2), 20)
	for i in range(n):
		var off := Vector2(float(i % 5) * 11.0, float(i) / 5.0 * 11.0)
		var e2 := _spawn_enemy("skeleton1", base + off)
		e2.orbit_t = 0.0
	FX.smoke_skull(base, 1.0)
	SFX.play("scream", -2.0, 0.8)
	hud.flash("МАРШ СКЕЛЕТОВ!", 1.8)

## мини-босс: здоровенный чемпион из обычного врага (фиолетовая аура, дроп-ларец)
## ВАЖНО: спавним РЯДОМ с героем (за краем экрана) — иначе медленный чемпион
## шёл через всю карту и так и не доходил (баг «чемпион не появляется»)!
func _spawn_mini_boss(mb: Dictionary) -> void:
	var e := _spawn_enemy(String(mb["type"]), _ring_pos(randf_range(185.0, 235.0)), false)
	e.make_mini_boss(float(mb["hp"]))
	FX.smoke_skull(e.global_position, 1.35)
	FX.explosion(e.global_position, 1.1, true)  # фиолетовый взрыв = фирменный знак чемпиона
	hud.flash("МИНИ-БОСС: %s!" % String(mb["title"]), 2.2)

func _spawn_boss(type: String, hp_mult: float) -> void:
	var b := Enemy.create_boss(type, hp_mult)
	b.global_position = _spawn_pos(true)
	enemies_node.add_child(b)
	GameState.enemies.append(b)
	GameState.current_boss = b
	b.died.connect(_on_enemy_died)
	FX.smoke_skull(b.global_position, 1.2)
	SFX.play("boss", -1.0)
	SFX.play_music("music_boss")  # эксклюзив: орган на всё сражение!
	hud.flash("БОСС: %s!" % Data.BOSSES[type]["title"], 2.2)

func _spawn_pickup(kind: String, pos := Vector2.ZERO) -> void:
	var where := pos
	if where == Vector2.ZERO:
		if not _pickup_points.is_empty():
			where = _pickup_points[randi() % _pickup_points.size()]
		else:
			where = _ring_pos(randf_range(60.0, 140.0))
	pickups_node.add_child(Pickup.spawn(kind, where))

func _skull_ring() -> void:
	var n := mini(6 + int(GameState.minutes * 2), 14)
	var type := "skull" if GameState.minutes < 3.0 else ("goblin" if randf() < 0.5 else "skull")
	for i in range(n):
		var e := _spawn_enemy(type, Vector2.ZERO)
		# тесное кольцо теней: кружат ВПЛОТНУЮ к герою (в 3 раза ближе, вдвое медленнее)
		e.global_position = GameState.random_walkable_near(player.global_position, 42.0, 60.0, 12.0)
		e.orbit_r = e.global_position.distance_to(player.global_position)  # радиус зафиксирован
		e.orbit_t = 3.2 + randf() * 0.6  # сначала кружат по орбите, потом бросаются!
	FX.sparkle(player.global_position, 1.1)
	hud.flash("КОЛЬЦО ТЕНЕЙ!", 1.6)

# ---------------- СМЕРТИ/ДРОП ----------------

func _on_enemy_died(e: Enemy) -> void:
	GameState.kills += 1
	GameState.combo += 1
	GameState.combo_t = 2.2
	if e.is_boss:
		_spawn_pickup("chest", e.global_position)
		_spawn_pickup("heal_big", e.global_position + Vector2(18, 8))
		_spawn_pickup("key_gold", e.global_position + Vector2(-18, 8))
		if GameState.player:
			FX.crown(GameState.player.global_position)
		# кровавая тварь делится: пока жив второй сгусток — финал не играем,
		# стрелка и босс-музыка переходят к нему
		var next_boss: Enemy = null
		for o in GameState.enemies:
			if is_instance_valid(o) and not o.dead and o.is_boss:
				next_boss = o
				break
		GameState.current_boss = next_boss
		if next_boss == null:
			# эффектный финал: белая вспышка + слоу-мо (таймер в РЕАЛЬНОМ времени)
			if GameState.opt_slowmo and not GameState.game_over:
				hud.flash_screen()
				Engine.time_scale = 0.25
				get_tree().create_timer(0.3, true, false, true).timeout.connect(
					func(): Engine.time_scale = 1.0)
			if not GameState.game_over:
				SFX.play_music(music_track)  # орган отгремел — назад к боевой теме
			hud.flash("БОСС ПОВЕРЖЕН!", 2.0)
		else:
			hud.flash("СГУСТОК ПОВЕРЖЕН — ОСТАЛСЯ ЕЩЁ ОДИН!", 2.0)
		return
	# дроп: монеты, флаконы, ключи — падают из врагов
	var cc: float = e.cfg.get("coin_chance", 0.45)
	var r := randf()
	if e.mini_boss:
		# чемпион делится богатством: ларец, пара монет и лечилка
		_spawn_pickup("mini_chest", e.global_position)
		_spawn_pickup("coin", e.global_position + Vector2(12, 5))
		_spawn_pickup("coin", e.global_position - Vector2(12, 5))
		_spawn_pickup("heal", e.global_position + Vector2(0, 11))
	elif e.elite:
		_spawn_pickup("chest", e.global_position)
		_spawn_pickup("coin", e.global_position + Vector2(10, 4))
		_spawn_pickup("coin", e.global_position - Vector2(10, 4))
	elif r < cc:
		_spawn_pickup("coin", e.global_position + Vector2(randf_range(-4, 4), randf_range(-4, 4)))
	elif r < cc + 0.10:
		_spawn_pickup("heal", e.global_position)
	elif r < cc + 0.18:
		_spawn_pickup("gem", e.global_position)
	elif r < cc + 0.22:
		_spawn_pickup("elixir", e.global_position)
	elif r < cc + 0.24:
		_spawn_pickup("key_silver", e.global_position)

# растаскивание толпы: ОПТИМИЗИРОВАНО (v0.13) —
# 1) обрабатываем половину пар за кадр (чередуем чётность: 30 Гц хватает),
# 2) квадраты расстояний вместо sqrt (корень — только у реально близких),
# 3) пары, где ОБА врага далеко от героя/экрана, пропускаем (их всё равно не видно),
# 4) get_child(i) вместо get_children() — без лишнего массива каждый кадр.
var _sep_phase := 0

func _separate_enemies() -> void:
	_sep_phase = 1 - _sep_phase
	# идём по РЕЕСТРУ врагов (массив уже есть — get_child на каждую пару не нужен)
	var list := GameState.enemies
	var n := list.size()
	var pl := GameState.player
	var pc := pl.global_position if pl != null and is_instance_valid(pl) else Vector2.ZERO
	const FAR2 := 420.0 * 420.0
	for i in range(n):
		var a := list[i] as Enemy
		# защита от случайных "не-врагов" + кружащихся по орбите не растаскиваем
		if a == null or not is_instance_valid(a) or a.dead or a.is_boss or a.mini_boss or a.orbit_t > 0.0:
			continue
		var a_far := a.global_position.distance_squared_to(pc) > FAR2
		for j in range(i + 1, n):
			if ((i + j) & 1) != _sep_phase:
				continue
			var b := list[j] as Enemy
			if b == null or not is_instance_valid(b) or b.dead or b.is_boss or b.mini_boss or b.orbit_t > 0.0:
				continue
			if a_far and b.global_position.distance_squared_to(pc) > FAR2:
				continue
			var d := a.global_position - b.global_position
			var min_d := (a.radius + b.radius) * 0.85
			var dist2 := d.length_squared()
			if dist2 < min_d * min_d and dist2 > 0.0001:
				var push := d.normalized() * (min_d - sqrt(dist2)) * 0.4
				a.global_position = GameState.slide_move(a.global_position, push, 6.0)
				b.global_position = GameState.slide_move(b.global_position, -push, 6.0)

# ---------------- СОБЫТИЯ ----------------

func _on_level_up(_lvl: int) -> void:
	get_tree().paused = true
	hud.show_levelup(_roll_upgrades())

func _roll_upgrades() -> Array:
	var pool := []
	for u in Data.UPGRADES:
		if player.upgrade_levels.get(u["id"], 0) < u["max"]:
			pool.append(u)
	pool.shuffle()
	return pool.slice(0, 3)

func on_upgrade_picked(id: String) -> void:
	player.apply_upgrade(id)
	get_tree().paused = false

func _on_player_died() -> void:
	GameState.game_over = true
	SFX.music_off()
	SFX.play("gameover", -1.0)
	hud.show_game_over()
