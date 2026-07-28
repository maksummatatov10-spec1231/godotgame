extends Node2D
## Главная сцена: арена, декор, директор волн, боссы, камера, игровой цикл.

var player: Player
var hud
var enemies_node: Node2D
var bullets_node: Node2D
var pickups_node: Node2D
var effects_node: Node2D
var decor_node: Node2D
var camera: Camera2D

var _spawn_t := 0.0
var _event_t := 20.0      # кольца мобов
var _chest_t := 45.0      # периодический сундук
var _boss_idx := 0
var _flask_t := 25.0

func _ready() -> void:
	GameState.reset()
	# контейнеры по z-порядку
	decor_node = _mk("Decor", 0, 2)
	pickups_node = _mk("Pickups", 0, 4)
	effects_node = _mk("Effects", 0, 60)
	enemies_node = _mk("Enemies", 0, 10)
	bullets_node = _mk("Bullets", 0, 11)
	FX.effects_root = effects_node
	_decorate()
	# игрок
	player = Player.new()
	player.global_position = Vector2(512, 300)
	add_child(player)
	player.leveled_up.connect(_on_level_up)
	player.died_player.connect(_on_player_died)
	# камера
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	# границы камеры = играбельная зона + 1.5 тайла стен вокруг
	camera.limit_left = int(GameState.play_rect.position.x) - 24
	camera.limit_top = int(GameState.play_rect.position.y) - 24
	camera.limit_right = int(GameState.play_rect.end.x) + 24
	camera.limit_bottom = int(GameState.play_rect.end.y) + 24
	player.add_child(camera)
	camera.make_current()
	# HUD
	hud = preload("res://scripts/hud.gd").new()
	add_child(hud)
	hud.bind(player)
	# стартовые прожиточные монстры
	for i in range(3):
		_spawn_enemy("skeleton1", player.global_position + Vector2.from_angle(TAU * i / 3) * 120)
	hud.flash("ВЫЖИВИ 10 МИНУТ!", 2.6)

func _mk(nname: String, _z := 0, _rel_z := 0) -> Node2D:
	var n := Node2D.new()
	n.name = nname
	add_child(n)
	return n

func _decorate() -> void:
	# факелы на верхней стене
	for x in range(96, 929, 104):
		var torch := AnimLib.sprite("assets/items/torch", 6.0, true)
		torch.global_position = Vector2(x, 50)
		decor_node.add_child(torch)
	# боковые факелы
	for y in [130, 240, 350, 460]:
		for x in [41, 983]:
			var st := AnimLib.sprite("assets/items/torch_side", 6.0, true)
			st.position = Vector2(x, y)
			st.flip_h = x > 900
			decor_node.add_child(st)
	# подсвечники у двери
	for x in [492, 548]:
		var c := AnimLib.sprite("assets/items/candle1", 6.0, true)
		c.global_position = Vector2(x, 500)
		decor_node.add_child(c)
	# шипы
	for pos in [Vector2(170, 150), Vector2(854, 160), Vector2(200, 440), Vector2(810, 450), Vector2(512, 200)]:
		var s := Spikes.new()
		s.global_position = pos
		decor_node.add_child(s)
	# разбросанные ящики
	for pos in [Vector2(120, 100), Vector2(138, 108), Vector2(900, 120), Vector2(880, 480), Vector2(110, 470)]:
		var b := AnimLib.sprite("assets/items/box1" if randf() < 0.5 else "assets/items/box2", 5.0, true)
		b.global_position = pos
		decor_node.add_child(b)
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
	if GameState.game_over:
		return
	GameState.run_time += delta
	_wave_director(delta)
	_separate_enemies()
	# победа через 10 минут (продолжаем ва-банк)
	if not GameState.won and GameState.run_time >= Data.WIN_TIME:
		GameState.won = true
		hud.show_win()

# ---------------- СПАВН ----------------

func _wave_director(delta: float) -> void:
	var m := GameState.minutes
	# интервал спавна ускоряется
	var interval := maxf(0.30, 1.15 - m * 0.10)
	var cap := mini(14 + int(m * 9.0), 64)
	_spawn_t += delta
	if _spawn_t >= interval and enemies_node.get_child_count() < cap:
		_spawn_t = 0.0
		_spawn_enemy(_pick_type(GameState.run_time), _ring_pos(170.0, 60.0, m >= 5.0))
	# элитки после 4-й минуты
	if m >= 4.0 and randf() < delta * 0.055:
		_spawn_enemy(_pick_type(GameState.run_time), _ring_pos(190.0), true)
	# кольца мобов-сюрпризов
	_event_t -= delta
	if _event_t <= 0.0:
		_event_t = 42.0
		_skull_ring()
	# периодический сундук и флаконы
	_chest_t -= delta
	if _chest_t <= 0.0:
		_chest_t = 55.0
		_spawn_pickup("chest")
	_flask_t -= delta
	if _flask_t <= 0.0:
		_flask_t = 30.0
		_spawn_pickup("heal")
	# боссы по расписанию
	if _boss_idx < Data.BOSS_SCHEDULE.size():
		var bs: Dictionary = Data.BOSS_SCHEDULE[_boss_idx]
		if GameState.run_time >= bs["time"]:
			_boss_idx += 1
			_spawn_boss(bs["type"], bs["hp_mult"])

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

func _spawn_enemy(type: String, pos: Vector2, elite := false) -> Enemy:
	var e := Enemy.create(type, elite)
	e.global_position = pos
	enemies_node.add_child(e)
	GameState.enemies.append(e)
	e.died.connect(_on_enemy_died)
	return e

func _spawn_boss(type: String, hp_mult: float) -> void:
	var b := Enemy.create_boss(type, hp_mult)
	b.global_position = _ring_pos(200.0)
	enemies_node.add_child(b)
	GameState.enemies.append(b)
	GameState.current_boss = b
	b.died.connect(_on_enemy_died)
	FX.smoke_skull(b.global_position, 1.2)
	hud.flash("БОСС: %s!" % Data.BOSSES[type]["title"], 2.2)

func _spawn_pickup(kind: String, pos := Vector2.ZERO) -> void:
	var p := Pickup.spawn(kind, pos if pos != Vector2.ZERO else _ring_pos(randf_range(60.0, 140.0)))
	pickups_node.add_child(p)

func _skull_ring() -> void:
	var n := mini(6 + int(GameState.minutes * 2), 14)
	var type := "skull" if GameState.minutes < 3.0 else ("goblin" if randf() < 0.5 else "skull")
	for i in range(n):
		var e := _spawn_enemy(type, Vector2.ZERO)
		e.global_position = GameState.random_walkable_near(player.global_position, 130.0, 170.0, 12.0)
	FX.sparkle(player.global_position, 1.1)
	hud.flash("КОЛЬЦО ТЕНЕЙ!", 1.6)

# ---------------- СМЕРТИ/ДРОП ----------------

func _on_enemy_died(e: Enemy) -> void:
	GameState.kills += 1
	if e.is_boss:
		_spawn_pickup("chest", e.global_position)
		_spawn_pickup("heal", e.global_position + Vector2(18, 8))
		if GameState.player:
			FX.crown(GameState.player.global_position)
		GameState.current_boss = null
		hud.flash("БОСС ПОВЕРЖЕН!", 2.0)
		return
	# дроп
	var r := randf()
	if e.elite:
		_spawn_pickup("chest", e.global_position)
	elif r < e.cfg.get("coin_chance", 0.4):
		_spawn_pickup("coin", e.global_position + Vector2(randf_range(-4, 4), randf_range(-4, 4)))
	elif r < e.cfg.get("coin_chance", 0.4) + 0.06:
		_spawn_pickup("heal", e.global_position)
	elif r < e.cfg.get("coin_chance", 0.4) + 0.12:
		_spawn_pickup("gem", e.global_position)

func _separate_enemies() -> void:
	var arr := enemies_node.get_children()
	var n := arr.size()
	for i in range(n):
		var a: Enemy = arr[i]
		if a.dead or a.is_boss:
			continue
		for j in range(i + 1, n):
			var b: Enemy = arr[j]
			if b.dead or b.is_boss:
				continue
			var d := a.global_position - b.global_position
			var dist := d.length()
			var min_d := (a.radius + b.radius) * 0.85
			if dist < min_d and dist > 0.01:
				var push := d.normalized() * (min_d - dist) * 0.4
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
	hud.show_game_over()
