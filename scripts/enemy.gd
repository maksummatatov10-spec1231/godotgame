class_name Enemy
extends Node2D
## Враг/босс: преследование, атака, смерть, дроп. Коллизии — дистанционные проверки.

signal died(e: Enemy)

var type_name := "skeleton1"
var cfg := {}
var hp := 10.0
var max_hp := 10.0
var radius := 9.0
var dmg := 8.0
var xp_value := 1
var dead := false
var is_boss := false
var elite := false

var sprite: AnimatedSprite2D
var _attack_cd := 0.0
var _lunge_cd := 4.0
var _lunge_t := 0.0
var _hit_flash := 0.0
var _attacking := false
var _wobble_t := 0.0
var _spawn_lock := 0.0      # интро-анимация появления: враг ещё не атакует и не идёт
var _step_t := 0.0
var _hop := 1.0             # высота процедурного шага по типу
# --- особые роли (ставит main при спавне) ---
var thief := false          # разбойник-вор: крадёт монеты и убегает
var golden := false         # золотая элитка (дроп x3)
var berserk := false        # красный берсерк-скелет: серия из 3 ударов
var orbit_t := 0.0          # >0: летит по орбите вокруг героя (кольцо теней)
var orbit_r := 0.0          # радиус орбиты — ЗАФИКСИРОВАН, иначе растаскивание разносит кольцо
var _carried: AnimatedSprite2D = null  # украденная монета над головой
var _revive_cd := 5.0       # некромант: кулдаун воскрешения
var _blink_cd := 0.0        # вампир: кулдаун блинка
var _hop_t := 0.0           # череп: анимация подпрыжки-атаки
var _phase2 := false        # босс во второй фазе
var _phase_t := 0.0         # переход фазы: неуязвимость
var _summon_cd := 6.0       # босс-демон призывает прислугу
var _splash_acc := 0.0      # босс в фазе 2: накопление урона для ответки
var _split_child := false   # детёныш кровавой твари (дальше не делится)

static func create(p_type: String, p_elite := false) -> Enemy:
	var e := Enemy.new()
	e.type_name = p_type
	e.cfg = Data.ENEMIES[p_type]
	e.elite = p_elite
	e.hp = e.cfg["hp"]
	e.max_hp = e.hp
	e.dmg = e.cfg["dmg"]
	e.xp_value = e.cfg["xp"]
	e.radius = e.cfg["radius"]
	if p_elite:
		e.hp *= 4.0
		e.max_hp = e.hp
		e.dmg *= 1.5
		e.xp_value *= 4
		e.radius *= 1.3
	return e

static func create_boss(p_type: String, p_hp_mult := 1.0) -> Enemy:
	var e := Enemy.new()
	e.type_name = p_type
	e.cfg = Data.BOSSES[p_type]
	e.is_boss = true
	e.hp = e.cfg["hp"] * p_hp_mult
	e.max_hp = e.hp
	e.dmg = e.cfg["dmg"]
	e.xp_value = e.cfg["xp"]
	e.radius = e.cfg["radius"]
	return e

func _ready() -> void:
	if not is_boss:
		hp *= 1.0 + GameState.minutes * 0.22
		max_hp = hp
		# честный рост HP от уровня героя (+7% за уровень выше 1-го)
		var pl := GameState.player
		if pl and "level" in pl:
			hp *= 1.0 + 0.07 * float(maxi(0, pl.level - 1))
			max_hp = hp
	sprite = AnimatedSprite2D.new()
	add_child(sprite)
	z_index = 10
	if is_boss:
		sprite.scale = Vector2.ONE * cfg["scale"]
		z_index = 14
		if _split_child:
			sprite.scale = Vector2.ONE * cfg["scale"] * 0.62
	elif elite:
		sprite.scale = Vector2.ONE * 1.35
		sprite.modulate = Color(1.5, 0.8, 1.8)
	match type_name:  # фирменные тона особых ролей
		"shieldknight":
			sprite.scale = Vector2.ONE * 1.2
			sprite.modulate = Color(1.1, 1.15, 1.35)  # серебряный щит-рыцарь
		"necromancer":
			sprite.scale = Vector2.ONE * 1.25
			sprite.modulate = Color(1.25, 0.75, 1.5)  # фиолетовый смертельный мрак
		"dark_rogue":
			if thief:
				sprite.modulate = Color(1.3, 1.1, 0.5)  # золотые перебежки вора
	if berserk:
		sprite.modulate = Color(1.6, 0.55, 0.55)  # красный берсерк
	if golden:
		sprite.scale = Vector2.ONE * 1.45
		sprite.modulate = Color(1.9, 1.5, 0.35)  # ЗОЛОТАЯ элитка
	_play("move_anim")
	_apply_spawn_intro()

# ---------- ИНТРО-АНИМАЦИЯ ПОЯВЛЕНИЯ (у каждого своя!) ----------

func _apply_spawn_intro() -> void:
	if is_boss:
		_spawn_lock = 1.25
		if type_name == "demon":
			# демон вспарывает землю огнём
			FX.explosion(global_position, 1.4)
			FX.spawn("assets/bullets/cast", global_position + Vector2(0, 4), 12.0, 1.3, 12)
		else:
			# кровавая тварь собирается из лужи крови
			FX.splatter(global_position, false, 1.6)
			FX.explosion(global_position, 1.3, true)
			FX.smoke_skull(global_position, 0.9)
		sprite.scale = Vector2.ONE * cfg["scale"] * 0.35
		sprite.modulate.a = 0.0
		return
	_spawn_lock = 0.7 if elite else 0.5
	match type_name:
		"skeleton1", "skeleton2":
			# восстает из-под земли
			sprite.position.y = 10.0
			sprite.modulate.a = 0.0
			FX.splatter(global_position + Vector2(0, 4), false, 0.25)
		"goblin":
			# выскакивает из клуба зелёной пыли
			var base := sprite.scale
			sprite.scale = base * 0.25
			sprite.set_meta("base_scale", base)
			FX.splatter(global_position, true, 0.3)
		"skull":
			# роняется сверху, трясясь
			sprite.position.y = -16.0
			sprite.modulate.a = 0.0
		"vampire":
			# сгущается из дыма
			sprite.modulate.a = 0.0
			FX.smoke_skull(global_position, 0.55)
		"dark_rogue":
			# материализуется из тени, нарастая с 30% размера
			var base2 := sprite.scale
			sprite.scale = base2 * 0.3
			sprite.set_meta("base_scale", base2)
			sprite.modulate.a = 0.0
			FX.smoke_skull(global_position, 0.55)
		"shieldknight":
			# восстаёт из-под земли, как скелет
			sprite.position.y = 10.0
			sprite.modulate.a = 0.0
			FX.splatter(global_position + Vector2(0, 4), false, 0.25)
		"necromancer":
			# собирается из фиолетовой мги
			sprite.modulate.a = 0.0
			FX.smoke_skull(global_position, 0.7)
			FX.sparkle(global_position, 0.4)
	if elite:
		_spawn_lock = 0.8
		SFX.play("spawn", -4.0, 0.9)
		SFX.play_at("scream", global_position, -2.0, 0.9)  # зычный рык элитки
		FX.sparkle(global_position, 0.5)

func _update_spawn_intro(delta: float) -> void:
	_spawn_lock -= delta
	var done := _spawn_lock <= 0.0
	if is_boss:
		var k := clampf(1.0 - _spawn_lock / 1.25, 0.0, 1.0)
		sprite.scale = Vector2.ONE * cfg["scale"] * (0.35 + 0.65 * k)
		sprite.modulate.a = minf(1.0, k * 2.2)
		position.x += randf_range(-0.7, 0.7) * (1.0 - k)  # дрожание при сборке
	else:
		var k := clampf(1.0 - _spawn_lock / (0.8 if elite else 0.5), 0.0, 1.0)
		match type_name:
			"skeleton1", "skeleton2", "shieldknight":
				sprite.position.y = lerpf(10.0, 0.0, k)
				sprite.modulate.a = minf(1.0, k * 2.0)
			"goblin":
				var base: Vector2 = sprite.get_meta("base_scale", Vector2.ONE * (1.35 if elite else 1.0))
				var overshoot := 1.0 + 0.18 * sin(k * PI)
				sprite.scale = base * (0.25 + 0.75 * k) * overshoot
			"dark_rogue":
				# материализуется из тени с перелётом масштаба (как гоблин из пыли)
				var base2: Vector2 = sprite.get_meta("base_scale", Vector2.ONE * (1.35 if elite else 1.0))
				var fly := 1.0 + 0.14 * sin(k * PI)
				sprite.scale = base2 * (0.3 + 0.7 * k) * fly
				sprite.modulate.a = minf(1.0, k * 2.2)
			"skull":
				sprite.position.y = lerpf(-16.0, 0.0, k)
				sprite.position.x = sin(k * 12.0) * 2.0 * (1.0 - k)
				sprite.modulate.a = minf(1.0, k * 2.4)
			"vampire", "necromancer":
				sprite.modulate.a = minf(1.0, k * 1.6)
	if done:
		sprite.modulate.a = 1.0
		sprite.position = Vector2.ZERO
		if type_name == "goblin" or type_name == "dark_rogue":
			sprite.scale = sprite.get_meta("base_scale", Vector2.ONE)
		if elite:
			FX.sparkle(global_position, 0.35)

func _play(key: String) -> void:
	if not cfg.has(key):
		return
	var a: Array = cfg[key]
	var sf := AnimLib.frames(cfg["dir"] + "/" + a[0], a[1], key == "move_anim")
	if sprite.sprite_frames == sf and sprite.is_playing():
		return
	sprite.sprite_frames = sf
	sprite.play("default")

func _back_to_move_once() -> void:
	var cb := func():
		if is_instance_valid(self) and not dead:
			_attacking = false
			_play("move_anim")
	sprite.animation_finished.connect(cb, CONNECT_ONE_SHOT)

## базовый тон спрайта с учётом роли (возвращаемся к нему после вспышки урона)
func _base_tint() -> Color:
	if golden:
		return Color(1.9, 1.5, 0.35)
	if berserk:
		return Color(1.6, 0.55, 0.55)
	if is_boss and _phase2:
		return Color(1.7, 0.6, 0.5)
	match type_name:
		"shieldknight":
			return Color(1.1, 1.15, 1.35)
		"necromancer":
			return Color(1.25, 0.75, 1.5)
		"dark_rogue":
			if thief:
				return Color(1.3, 1.1, 0.5)
	return Color(1.5, 0.8, 1.8) if elite else Color.WHITE

## main включает воровской режим уже после _ready: флаг + фирменный тон
func make_thief() -> void:
	thief = true
	sprite.modulate = Color(1.3, 1.1, 0.5)

func _process(delta: float) -> void:
	if dead:
		return
	if _hit_flash > 0.0:
		_hit_flash -= delta
		if _hit_flash <= 0.0:
			sprite.modulate = _base_tint()
	# интро-анимация появления: враг ещё не опасен
	if _spawn_lock > 0.0:
		_update_spawn_intro(delta)
		return
	var p := GameState.player
	if p == null or not is_instance_valid(p) or GameState.game_over:
		return
	# череп: дуга подпрыжки-атаки
	if _hop_t > 0.0:
		_hop_t -= delta
		sprite.position.y = -10.0 * (1.0 - absf(_hop_t / 0.28 * 2.0 - 1.0))
	# вампир: кулдаун блинка-исчезновения
	if _blink_cd > 0.0:
		_blink_cd -= delta
	# кольцо теней: враг кружит вокруг героя по орбите (радиус зафиксирован!)
	if orbit_t > 0.0:
		orbit_t -= delta
		var off := global_position - p.global_position
		if orbit_r < 1.0:
			orbit_r = maxf(120.0, off.length())
		var base_d := off.normalized() if off.length() > 1.0 else Vector2.RIGHT
		global_position = p.global_position + base_d.rotated(delta * 1.2) * orbit_r
		sprite.flip_h = p.global_position.x < global_position.x
		_step_t += delta * 9.0
		sprite.position.y = -absf(sin(_step_t)) * 1.2
		return
	# вторая фаза демона: переход — босс неуязвим, потом призывает прислугу
	if is_boss and type_name == "demon" and _phase2:
		if _phase_t > 0.0:
			_phase_t -= delta
			sprite.rotation = sin(_phase_t * 30.0) * 0.06
			if _phase_t <= 0.0:
				sprite.rotation = 0.0
				_play("move_anim")
			return
		_summon_cd -= delta
		if _summon_cd <= 0.0:
			_summon_cd = 9.0
			_summon_minions()
	# некромант ведёт реестр трупов и воскрешает павших
	if type_name == "necromancer":
		_revive_cd -= delta
		if _revive_cd <= 0.0:
			_revive_cd = 6.0 if _try_revive() else 1.5
	# вор живёт по своим законам: сначала добыча, потом побег
	if thief and _thief_process(delta, p):
		return
	var to_p: Vector2 = p.global_position - global_position
	var dist := to_p.length()
	var dir := to_p.normalized() if dist > 0.1 else Vector2.ZERO
	# спрайты врагов нарисованы мордой ВПРАВО: флипаем, когда игрок слева
	sprite.flip_h = p.global_position.x < global_position.x
	_attack_cd -= delta

	# рывок кровавой твари
	if cfg.has("lunge"):
		var speed_val: float = cfg["speed"]
		_lunge_cd -= delta
		if _lunge_t > 0.0:
			_lunge_t -= delta
			global_position = GameState.slide_move(global_position, dir * speed_val * float(cfg["lunge"]["speed_mult"]) * delta, 10.0)
			if _lunge_t <= 0.0:
				_lunge_cd = float(cfg["lunge"]["cd"])
			_touch_damage()
			return
		if _lunge_cd <= 0.0 and dist < 220.0 and dist > 60.0:
			_lunge_t = cfg["lunge"]["time"]
			FX.smoke(global_position, 0.5)
			return

	# дальние атаки
	if _attack_cd <= 0.0:
		if cfg.has("volley") and dist < cfg["volley"]["range"]:
			_comet_volley(p)
			_attack_cd = cfg["volley"]["cd"]
			return
		if cfg.get("ranged", false) and dist < 190.0 and dist > 60.0:
			_ranged_shot(p)
			_attack_cd = cfg["attack_cd"] * 1.6
			return
	# контактная атака / погоня
	if dist < cfg["attack_range"] + 4.0:
		_touch_damage()
	elif not _attacking:
		_hop = {"goblin": 2.2, "skull": 1.1, "dark_rogue": 2.4, "shieldknight": 0.5, "necromancer": 0.7}.get(type_name, 0.8)
		var speed_val: float = cfg["speed"]
		var step: Vector2 = dir * speed_val * delta
		if cfg.get("wobble", false):
			_wobble_t += delta * 6.0
			step += dir.rotated(PI / 2.0) * sin(_wobble_t) * 36.0 * delta
		global_position = GameState.slide_move(global_position, step, 6.0)
		_play("move_anim")
		# процедурная походка поверх/вместо анимкадров (у гоблина и черепа кадров ходьбы нет)
		_step_t += delta * speed_val * 0.11
		if not is_boss:
			sprite.position.y = -absf(sin(_step_t)) * _hop
			sprite.rotation = sin(_step_t) * (0.06 if type_name == "goblin" else 0.035)

## разбойник-вор: true = обработал кадр сам (добыча/побег), false = веди себя как враг
func _thief_process(delta: float, p: Node2D) -> bool:
	if _carried != null:
		# убегает прочь от героя — быстрее обычного
		var away := global_position - p.global_position
		var dir_f := away.normalized() if away.length() > 0.1 else Vector2.RIGHT
		global_position = GameState.slide_move(global_position, dir_f * cfg["speed"] * 1.4 * delta, 6.0)
		sprite.flip_h = dir_f.x < 0.0
		_step_t += delta * cfg["speed"] * 0.15
		sprite.position.y = -absf(sin(_step_t)) * 2.6
		sprite.rotation = sin(_step_t) * 0.08
		if away.length() > 320.0:
			# упёхнулся с добычей — растворился в дыму (без дропа!)
			FX.smoke(global_position, 0.5)
			GameState.enemies.erase(self)
			queue_free()
		return true
	# ищем ближайшую монетку/флакон опыта
	var best: Pickup = null
	var best_d := 240.0 * 240.0
	for pk in GameState.pickups:
		if not is_instance_valid(pk) or pk.is_chest():
			continue
		if pk.kind != "coin" and pk.kind != "gem":
			continue
		var d2 := global_position.distance_squared_to(pk.global_position)
		if d2 < best_d:
			best_d = d2
			best = pk
	if best == null:
		return false  # добычи нет — обычный враг
	var to_c: Vector2 = best.global_position - global_position
	if to_c.length() < 10.0:
		# стащил! монета крутится над головой, вор уносит ноги
		GameState.pickups.erase(best)
		best.queue_free()
		_carried = AnimLib.sprite("assets/items/coin", 8.0, true)
		_carried.position = Vector2(0, -17)
		_carried.z_index = 3
		add_child(_carried)
		SFX.play_at("coin", global_position, -4.0, 1.4)
		FX.sparkle(global_position, 0.25)
		return true
	var dir_c := to_c.normalized()
	global_position = GameState.slide_move(global_position, dir_c * cfg["speed"] * 1.15 * delta, 6.0)
	sprite.flip_h = dir_c.x < 0.0
	_step_t += delta * cfg["speed"] * 0.15
	sprite.position.y = -absf(sin(_step_t)) * 2.4
	sprite.rotation = sin(_step_t) * 0.06
	return true

## некромант: воскрешает ближайший труп тем же типом (кроме некромантов!)
func _try_revive() -> bool:
	for i in range(GameState.corpses.size()):
		var cr: Dictionary = GameState.corpses[i]
		if String(cr["type"]) == "necromancer":
			continue
		if global_position.distance_to(cr["pos"]) > 280.0:
			continue
		GameState.corpses.remove_at(i)
		var se := Enemy.create(String(cr["type"]))
		se.global_position = cr["pos"]
		get_parent().add_child(se)
		GameState.enemies.append(se)
		se.died.connect(Callable(get_parent().get_parent(), "_on_enemy_died"))
		FX.smoke_skull(cr["pos"], 0.6)
		FX.sparkle(cr["pos"], 0.4)
		SFX.play_at("resurrect", global_position, -6.0)
		return true
	return false

## демон, фаза 2: призвал одного слугу с его интро-анимацией
func _summon_one(tname: String, r: float, ang: float) -> void:
	var se := Enemy.create(tname)
	var pos2 := global_position
	for k in range(6):
		var try_p := global_position + Vector2.from_angle(ang + float(k) * 0.6) * r
		if GameState.is_walkable(try_p):
			pos2 = try_p
			break
	se.global_position = pos2
	get_parent().add_child(se)
	GameState.enemies.append(se)
	se.died.connect(Callable(get_parent().get_parent(), "_on_enemy_died"))

## демон, фаза 2: периодический призыв пары прислужников
func _summon_minions() -> void:
	_attacking = true
	_play("attack_anim")
	_back_to_move_once()
	var kinds := ["skeleton1", "dark_rogue", "skull"]
	for i in range(2):
		_summon_one(kinds[randi() % kinds.size()], 46.0, randf() * TAU)
	FX.cast(global_position)
	SFX.play_at("spawn", global_position, -3.0)

func _touch_damage() -> void:
	var p := GameState.player
	if _attack_cd > 0.0 or p == null:
		return
	_attack_cd = cfg["attack_cd"]
	if berserk:
		# берсерк: серия из трёх быстрых ударов одним замахом
		_attacking = true
		_play("attack_anim")
		for i in range(3):
			get_tree().create_timer(0.18 + float(i) * 0.15, false).timeout.connect(func():
				if is_instance_valid(self) and not dead and is_instance_valid(p):
					if global_position.distance_to(p.global_position) < cfg["attack_range"] + 12.0:
						p.take_damage(dmg * 0.55)
			)
		_back_to_move_once()
		return
	if cfg.get("no_attack_anim", false):
		if type_name == "skull":
			_hop_t = 0.28  # череп бьёт в прыжке
			SFX.play_at("jump", global_position, -2.0)
		p.take_damage(dmg)
		return
	_attacking = true
	_play("attack_anim")
	var dmg_delay: float = 0.45 if is_boss else 0.35
	get_tree().create_timer(dmg_delay, false).timeout.connect(func():
		if is_instance_valid(self) and not dead and is_instance_valid(p):
			if global_position.distance_to(p.global_position) < cfg["attack_range"] + 12.0:
				p.take_damage(dmg)
	)
	_back_to_move_once()

func _ranged_shot(p: Node2D) -> void:
	_attacking = true
	_play("attack_anim")
	get_tree().create_timer(0.3, false).timeout.connect(func():
		if is_instance_valid(self) and not dead and is_instance_valid(p):
			var d := global_position.direction_to(p.global_position)
			var b := Bullet.hostile_shot("orb_violet", global_position, d, dmg)
			get_parent().get_parent().get_node("Bullets").add_child(b)
			SFX.play_at("vampire_shot", global_position, -3.0)  # позиционно
	)
	_back_to_move_once()

func _comet_volley(p: Node2D) -> void:
	_attacking = true
	_play("attack_anim")
	var count: int = cfg["volley"]["count"]
	get_tree().create_timer(0.5, false).timeout.connect(func():
		if is_instance_valid(self) and not dead and is_instance_valid(p):
			var base := global_position.direction_to(p.global_position)
			for i in range(count):
				var d := base.rotated((i - (count - 1) / 2.0) * 0.30)
				var b := Bullet.hostile_shot(cfg["volley"]["projectile"], global_position, d, dmg * 0.9)
				get_parent().get_parent().get_node("Bullets").add_child(b)
			FX.cast(global_position)
	)
	_back_to_move_once()

func take_damage(p_dmg: float, from_dir := Vector2.ZERO, crit := false) -> void:
	if dead:
		return
	# переход фазы: босс неуязвим, пока трансформируется
	if _phase_t > 0.0:
		FX.sparkle(global_position, 0.15)
		return
	hp -= p_dmg
	_hit_flash = 0.1
	sprite.modulate = Color(3.0, 3.0, 3.0)
	FX.damage_number(global_position, int(p_dmg), Color(1.0, 0.9, 0.3), crit)
	if not is_boss and from_dir != Vector2.ZERO:
		global_position = GameState.slide_move(global_position, from_dir * 5.0, 6.0)
	# вампир: шанс блинка-исчезновения в клубах дыма
	if type_name == "vampire" and hp > 0.0 and _blink_cd <= 0.0 and randf() < 0.35:
		_blink_cd = 3.5
		FX.smoke(global_position, 0.45)
		SFX.play_at("spawn", global_position, -3.0, 1.25)
		var side := Vector2.from_angle(randf() * TAU)
		var pv := GameState.player
		if pv and is_instance_valid(pv):
			side = (global_position - pv.global_position).normalized().rotated(randf_range(-0.9, 0.9))
		var rest_b := 56.0
		while rest_b > 0.0:
			var np := GameState.slide_move(global_position, side * minf(8.0, rest_b), 6.0)
			if np == global_position:
				break
			global_position = np
			rest_b -= 8.0
		FX.smoke(global_position, 0.45)
	# демон на половине жизни — вторая фаза, кровавая тварь — делится
	if is_boss and not _phase2 and not _split_child and hp > 0.0 and hp <= max_hp * 0.5:
		if type_name == "demon":
			_start_phase2()
		elif type_name == "blood":
			_split_blood()
			return
	# босс второй фазы огрызается при уроне сплэшем (hurt-кадры!)
	if is_boss and (_phase2 or _split_child) and hp > 0.0:
		_splash_acc += p_dmg
		if _splash_acc >= 60.0:
			_splash_acc = 0.0
			_hurt_splash()
	if hp <= 0.0:
		die()
	elif cfg.has("hurt_anim") and not _attacking and _phase_t <= 0.0 and randf() < 0.35:
		_attacking = true
		_play("hurt_anim")
		_back_to_move_once()

## демон: вторая фаза — трансформация с неуязвимостью, ярость, почётный караул
func _start_phase2() -> void:
	_phase2 = true
	_phase_t = 1.3          # время неуязвимой трансформации
	_attacking = false
	dmg *= 1.25
	FX.explosion(global_position, 1.6)
	FX.smoke_skull(global_position, 1.0)
	FX.splatter(global_position, false, 1.2)
	SFX.play("scream", -1.0, 0.85)
	sprite.modulate = Color(1.7, 0.6, 0.5)  # адская ярость
	sprite.sprite_frames = AnimLib.frames(cfg["dir"] + "/attack2", 12.0, false)
	sprite.play("default")
	# почётный караул из-под земли
	for i in range(3):
		_summon_one("skeleton1", 44.0, TAU * float(i) / 3.0)

## босс в ярости огрызается: hurt-анимация + волна по округе
func _hurt_splash() -> void:
	if cfg.has("hurt_anim") and not _attacking and _phase_t <= 0.0:
		_attacking = true
		_play("hurt_anim")
		_back_to_move_once()
	FX.explosion(global_position, 0.9, type_name == "blood")
	SFX.play_at("comet_hit", global_position, -6.0)
	var p := GameState.player
	if p and is_instance_valid(p) and global_position.distance_to(p.global_position) < 82.0:
		p.take_damage(dmg * 0.6)

## кровавая тварь делится на два меньших сгустка (не смерть — наград нет!)
func _split_blood() -> void:
	dead = true
	GameState.enemies.erase(self)
	var first: Enemy = null
	for i in range(2):
		var ch := Enemy.create_boss("blood")
		ch.hp = maxf(40.0, hp * 0.5)
		ch.max_hp = ch.hp
		ch.dmg *= 0.8
		ch.radius *= 0.8
		ch._split_child = true
		ch.global_position = global_position + Vector2.from_angle(TAU * float(i) / 2.0 + 0.5) * 26.0
		get_parent().add_child(ch)
		GameState.enemies.append(ch)
		ch.died.connect(Callable(get_parent().get_parent(), "_on_enemy_died"))
		if first == null:
			first = ch
	FX.splatter(global_position, false, 1.8)
	FX.explosion(global_position, 1.4, true)
	FX.smoke_skull(global_position, 0.9)
	SFX.play("boss", -2.0, 0.9)
	if GameState.current_boss == self and first != null:
		GameState.current_boss = first
	queue_free()

func die() -> void:
	if dead:
		return
	dead = true
	died.emit(self)
	# некромант сможет воскресить: запоминаем труп (боссов нельзя)
	if not is_boss:
		GameState.corpses.append({"pos": global_position, "type": type_name, "t": 14.0})
	if is_boss:
		SFX.play("boss_die", -1.0)
	elif elite:
		SFX.play_at("elite_die", global_position, -2.0)  # позиционно: вдали — тише
	else:
		SFX.play_at("enemy_die", global_position, -4.0, 0.92)
	# элитка взрывается и бьёт соседей (золотая — мощнее и дропает x3)
	if elite:
		FX.explosion(global_position, 0.9, false)
		SFX.play_at("comet_hit", global_position, -2.0)
		var boom_dmg := 45.0 if golden else 30.0
		var boom_r := 74.0 if golden else 62.0
		for o in GameState.enemies.duplicate():  # копия: цепная реакция взрывов
			if o != self and is_instance_valid(o) and not o.dead and not o.is_boss:
				if global_position.distance_to(o.global_position) < boom_r:
					o.take_damage(boom_dmg, global_position.direction_to(o.global_position))
	# вор убит с добычей — возвращает монету с процентами (x2!)
	if _carried != null:
		for i in range(2):
			get_parent().add_child(Pickup.spawn(
				"coin", global_position + Vector2(randf_range(-12, 12), randf_range(-8, 8))))
		FX.coin_burst(global_position, 0.4)
	if golden:
		for i in range(3):
			get_parent().add_child(Pickup.spawn(
				"coin", global_position + Vector2(randf_range(-14, 14), randf_range(-10, 10))))
		FX.coin_burst(global_position, 0.6)
	var fx_scale := 0.45
	if type_name == "goblin":
		FX.splatter(global_position, true)
	elif is_boss:
		FX.explosion(global_position, 2.2, type_name == "blood")
		FX.smoke_skull(global_position, 1.1)
	elif cfg.has("death_fx"):
		FX.spawn(cfg["death_fx"], global_position, 16.0, 0.7 if type_name == "vampire" else fx_scale)
	if cfg.has("death_anim"):
		z_index = 8
		_attacking = false
		_play("death_anim")
		sprite.animation_finished.connect(queue_free, CONNECT_ONE_SHOT)
	else:
		queue_free()

func _exit_tree() -> void:
	GameState.enemies.erase(self)
	if GameState.current_boss == self:
		GameState.current_boss = null
