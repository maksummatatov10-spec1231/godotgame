class_name Player
extends Node2D
## Пиромант: движение, авто-атака дротиками и огненным полумесяцем, XP/уровни.

signal leveled_up(level: int)
signal died_player

# статы
var max_hp := 100.0
var hp := 100.0
var speed := 105.0
var level := 1
var xp := 0
var xp_next := 12  # ceil(4 * 1^1.35 / 0.7 * 2) — прокачка замедлена в 2 раза
# оружие
var dart_cd := 1.0
var dart_dmg := 10.0
var dart_count := 1
var dart_speed := 250.0
var dart_tier := 0        # цвет пламени
var slash_cd := 2.1
var slash_dmg := 16.0
var slash_radius := 46.0
var slash_tier := 0
var magnet_radius := 48.0
var regen := 0.0

var upgrade_levels := {}
var sprite: AnimatedSprite2D
var body: Node2D           # обёртка спрайта: пульс каста не конфликтует с походкой
var shadow: Polygon2D
var glow: PointLight2D
var nick_label: Label
var outline_mat: ShaderMaterial
var _t_dart := 0.4
var _t_slash := 0.0
var _dash_cd := 0.0
var _iframes := 0.0
var _regen_acc := 0.0
var _walk_t := 0.0
var _step_t := 0.0
var _step_snd_t := 0.0
var _dead := false

# вспышка каста в цвет текущего пламени (золото → … → красное)
const CAST_GLOW := [
	Color(1.7, 1.5, 0.75), Color(1.7, 1.35, 0.6), Color(1.75, 1.05, 0.55),
	Color(0.8, 1.7, 0.8), Color(0.7, 1.2, 1.8), Color(1.3, 0.8, 1.8),
	Color(1.8, 0.7, 1.5), Color(1.9, 0.6, 0.6),
]

func _ready() -> void:
	# тень под ногами (эллипс из кода)
	shadow = Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(16):
		var a := TAU * i / 16.0
		pts.append(Vector2(cos(a) * 6.5, sin(a) * 2.6))
	shadow.polygon = pts
	shadow.color = Color(0.0, 0.0, 0.0, 0.4)
	shadow.position = Vector2(0, 6)
	shadow.z_index = -2          # под спрайтом героя (z спрайта 0 относительно нас)
	add_child(shadow)
	body = Node2D.new()
	body.name = "Body"
	add_child(body)
	sprite = AnimLib.sprite("assets/player/pyro/idle", 3.0, true)
	body.add_child(sprite)
	# контур: синий -> постепенно краснеет с каждым уровнем (отличить героя от врагов)
	outline_mat = ShaderMaterial.new()
	outline_mat.shader = load("res://shaders/outline.gdshader")
	sprite.material = outline_mat
	_update_outline()
	# тёплое свечение героя (факел в руке!)
	glow = PointLight2D.new()
	glow.texture = load("res://assets/fx/light_warm.png")
	glow.color = Color(1.0, 0.8, 0.55)
	glow.texture_scale = 0.55
	glow.energy = 0.4
	add_child(glow)
	# ник над головой (задаётся в главном меню)
	nick_label = Label.new()
	nick_label.position = Vector2(-50, -24)
	nick_label.size = Vector2(100, 10)
	nick_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var nls := LabelSettings.new()
	nls.font_size = 7
	nls.font_color = Color(0.8, 0.9, 1.0)
	nls.outline_size = 2
	nls.outline_color = Color(0, 0, 0, 0.9)
	nick_label.label_settings = nls
	nick_label.text = GameState.player_name
	add_child(nick_label)
	z_index = 12
	GameState.player = self

func _update_outline() -> void:
	# с каждым уровнем контур всё краснее (полностью красный к ~13 уровню)
	var base := Color(0.25, 0.60, 1.0)
	var hot := Color(1.0, 0.25, 0.15)
	outline_mat.set_shader_parameter("line_color", base.lerp(hot, minf(1.0, (level - 1) / 12.0)))

func _process(delta: float) -> void:
	if _dead or GameState.game_over:
		return
	# ник мог поменяться в меню
	if nick_label.text != GameState.player_name:
		nick_label.text = GameState.player_name
	# пульсация свечения
	glow.energy = 0.4 + 0.03 * sin(_walk_t * 1.7)
	# движение (WASD + стрелки, действия move_* настроены в GameState)
	var dir := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up"))
	if dir.length() > 0.0:
		dir = dir.normalized()
		var before := global_position
		global_position = GameState.slide_move(global_position, dir * speed * delta, 6.0)
		GameState.dist_traveled += global_position.distance_to(before)
		sprite.flip_h = dir.x < 0.0
		sprite.speed_scale = 2.6   # быстрый переступ двух кадров = "шагаем"
		# процедурная "ходьба": покачивание, присяд в такт, наклон (в паках нет walk-кадров героя)
		_walk_t += delta * 11.0
		sprite.position.y = -absf(sin(_walk_t)) * 2.2
		var squash := sin(_walk_t * 2.0)
		sprite.scale = Vector2(1.0 + squash * 0.05, 1.0 - squash * 0.06)
		sprite.rotation = lerpf(sprite.rotation, dir.x * 0.10, delta * 10.0)
		# пыль из-под ног + звук шагов
		_step_t -= delta
		if _step_t <= 0.0:
			_step_t = 0.26
			FX.smoke(global_position + Vector2(0, 5), 0.22, 8)
		_step_snd_t -= delta
		if _step_snd_t <= 0.0:
			_step_snd_t = 0.36
			SFX.play("step", -4.0)
	else:
		sprite.speed_scale = 1.0
		sprite.scale = sprite.scale.lerp(Vector2.ONE, delta * 10.0)
		sprite.position.y = lerpf(sprite.position.y, 0.0, delta * 10.0)
		sprite.rotation = lerpf(sprite.rotation, 0.0, delta * 10.0)
	# ДЭШ (Space): короткий рывок с неуязвимостью и дымом
	_dash_cd -= delta
	if _dash_cd <= 0.0 and Input.is_action_just_pressed("dash"):
		var dd := dir if dir.length() > 0.0 else (Vector2.LEFT if sprite.flip_h else Vector2.RIGHT)
		_dash_cd = 1.2
		_iframes = maxf(_iframes, 0.35)
		FX.smoke(global_position, 0.35, 22)
		SFX.play("dash", -2.0)
		var rest := 52.0
		while rest > 0.0:  # короткими шагами — чтобы не пролезть сквозь стену
			var np := GameState.slide_move(global_position, dd * minf(8.0, rest), 6.0)
			if np == global_position:
				break
			GameState.dist_traveled += global_position.distance_to(np)
			global_position = np
			rest -= 8.0
		FX.smoke(global_position, 0.3, 22)
		FX.sparkle(global_position, 0.25)
	# реген
	if regen > 0.0:
		_regen_acc += regen * delta
		if _regen_acc >= 1.0:
			_regen_acc -= 1.0
			hp = minf(hp + 1.0, max_hp)
	if _iframes > 0.0:
		_iframes -= delta
		sprite.modulate.a = 0.45 + 0.3 * sin(_iframes * 40.0)
	else:
		sprite.modulate.a = 1.0
	# атака дротиками: авто-наведение ИЛИ ручная стрельба мышью (настройка на паузе)
	_t_dart -= delta
	if _t_dart <= 0.0:
		if GameState.opt_manual_aim:
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):  # зажми ЛКМ — стреляй в курсор
				var mpos := get_global_mouse_position()
				if mpos.distance_to(global_position) > 4.0:
					_fire_darts_dir(global_position.direction_to(mpos))
					_t_dart = dart_cd
				else:
					_t_dart = 0.12
			else:
				_t_dart = 0.12
		else:
			var target := _nearest_enemy(600.0)
			if target:
				_fire_darts(target)
				_t_dart = dart_cd
			else:
				_t_dart = 0.15
	# огненный полумесяц по ближним
	_t_slash -= delta
	if _t_slash <= 0.0:
		var near := _nearest_enemy(slash_radius + 26.0)
		if near:
			var ndir: Vector2
			if GameState.opt_manual_aim:  # полумесяц бьёт в сторону курсора
				var mpos2 := get_global_mouse_position()
				ndir = global_position.direction_to(mpos2) if mpos2.distance_to(global_position) > 4.0 else global_position.direction_to(near.global_position)
			else:
				ndir = global_position.direction_to(near.global_position)
			sprite.flip_h = ndir.x < 0.0
			# микровыпад в сторону цели — читается как анимация атаки
			global_position = GameState.slide_move(global_position, ndir * 7.0, 6.0)
			var tw := body.create_tween()
			tw.tween_property(body, "scale", Vector2(0.85, 1.18), 0.06)
			tw.tween_property(body, "scale", Vector2.ONE, 0.16)
			FX.sparkle(global_position + ndir * slash_radius * 0.5, 0.2)
			SFX.play("slash", -6.0)
			GameState.slashes_used += 1
			Slash.strike(self, global_position, ndir, slash_radius, slash_dmg, slash_tier)
			_t_slash = slash_cd
		else:
			_t_slash = 0.1

func _nearest_enemy(max_dist: float) -> Node2D:
	var best: Node2D = null
	var best_d := max_dist * max_dist
	for e in GameState.enemies:
		if not is_instance_valid(e) or e.dead:
			continue
		var d: float = global_position.distance_squared_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best

func _fire_darts(target: Node2D) -> void:
	_fire_darts_dir(global_position.direction_to(target.global_position))

## залп дротиков по направлению (общее ядро: авто-наведение и ручная стрельба)
func _fire_darts_dir(base_dir: Vector2) -> void:
	# герой всегда лицом к цели атаки (не "задом")
	sprite.flip_h = base_dir.x < 0.0
	FX.cast(global_position + Vector2(0, -3))
	SFX.play("shoot", -8.0)
	# вспышка "руки": искра в точке вылета снаряда
	FX.impact_yellow(global_position + base_dir * 10.0 + Vector2(0, -3), 0.13)
	# отдача-пульс каста на обёртке (не конфликтует с походкой)
	var tw := body.create_tween()
	tw.tween_property(body, "scale", Vector2(1.18, 0.88), 0.06)
	tw.tween_property(body, "scale", Vector2.ONE, 0.14)
	# магическая вспышка в цвет текущего пламени
	sprite.modulate = CAST_GLOW[mini(dart_tier, 7)]
	var fw := sprite.create_tween()
	fw.tween_property(sprite, "modulate", Color.WHITE, 0.18)
	var n := dart_count
	GameState.darts_fired += n
	for i in range(n):
		var spread := (i - (n - 1) / 2.0) * 0.13
		var d := base_dir.rotated(spread)
		add_sibling_bullet(d)

func add_sibling_bullet(d: Vector2) -> void:
	var b := Bullet.dart(global_position, d, dart_speed, dart_dmg, dart_tier)
	get_parent().get_node("Bullets").add_child(b)

func take_damage(dmg: float) -> void:
	if _dead or _iframes > 0.0 or GameState.game_over:
		return
	hp -= dmg
	_iframes = 0.55
	GameState.combo = 0      # серия сгорела — ранение сбрасывает комбо
	GameState.combo_t = 0.0
	SFX.play("player_hurt", -2.0)
	sprite.modulate = Color(3.0, 0.6, 0.6)
	var t := Timer.new()
	t.wait_time = 0.12
	t.one_shot = true
	t.timeout.connect(func():
		if is_instance_valid(sprite):
			sprite.modulate = Color.WHITE
		t.queue_free()
	)
	add_child(t)
	t.start()
	FX.splatter(global_position, false, 0.3)
	if hp <= 0.0:
		_die()

func heal(amount: float) -> void:
	var before := hp
	hp = minf(hp + amount, max_hp)
	FX.heal(global_position)
	var gained := int(hp - before)
	if gained > 0:
		FX.heal_number(global_position, gained)

func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_next:
		xp -= xp_next
		level += 1
		# прокачка замедлена в ~2.86 раза (x1/0.7 * 2) по просьбе
		xp_next = int(ceil(4.0 * pow(level, 1.35) / 0.7 * 2.0))
		_update_outline()
		FX.level_up(global_position + Vector2(0, -18))
		FX.sparkle(global_position, 0.5)
		SFX.play("levelup", -2.0)
		leveled_up.emit(level)

func apply_upgrade(id: String) -> void:
	upgrade_levels[id] = upgrade_levels.get(id, 0) + 1
	match id:
		"dart_rate": dart_cd = maxf(0.18, dart_cd * 0.80)
		"dart_dmg":
			dart_dmg *= 1.30
			dart_tier = mini(dart_tier + 1, 7)
		"dart_count": dart_count = mini(dart_count + 1, 5)
		"slash":
			slash_dmg *= 1.40
			slash_radius += 7.0
			slash_tier = mini(slash_tier + 1, 7)
		"boots": speed *= 1.12
		"heart":
			max_hp += 25.0
			heal(25.0)
		"magnet": magnet_radius *= 1.45
		"regen": regen += 0.6

func _die() -> void:
	_dead = true
	FX.explosion(global_position, 1.0)
	FX.smoke_skull(global_position, 0.9)
	sprite.visible = false
	died_player.emit()
