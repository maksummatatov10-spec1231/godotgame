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
var xp_next := 5
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
var shadow: Polygon2D
var _t_dart := 0.4
var _t_slash := 0.0
var _iframes := 0.0
var _regen_acc := 0.0
var _walk_t := 0.0
var _dead := false

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
	shadow.z_index = 9
	add_child(shadow)
	sprite = AnimLib.sprite("assets/player/pyro/idle", 3.0, true)
	add_child(sprite)
	z_index = 12
	GameState.player = self

func _process(delta: float) -> void:
	if _dead or GameState.game_over:
		return
	# движение
	var dir := Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up"))
	if dir.length() > 0.0:
		dir = dir.normalized()
		global_position = GameState.slide_move(global_position, dir * speed * delta, 6.0)
		sprite.flip_h = dir.x < 0.0
		sprite.speed_scale = 1.7
		# процедурная "ходьба": покачивание и наклон (в паках нет walk-кадров героя)
		_walk_t += delta * 11.0
		sprite.position.y = -absf(sin(_walk_t)) * 2.0
		sprite.rotation = lerpf(sprite.rotation, dir.x * 0.09, delta * 10.0)
	else:
		sprite.speed_scale = 1.0
		sprite.position.y = lerpf(sprite.position.y, 0.0, delta * 10.0)
		sprite.rotation = lerpf(sprite.rotation, 0.0, delta * 10.0)
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
	# авто-атака дротиками
	_t_dart -= delta
	if _t_dart <= 0.0:
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
			var ndir := global_position.direction_to(near.global_position)
			sprite.flip_h = near.global_position.x < global_position.x
			# микровыпад в сторону цели — читается как анимация атаки
			global_position = GameState.slide_move(global_position, ndir * 7.0, 6.0)
			var tw := sprite.create_tween()
			tw.tween_property(sprite, "scale", Vector2(0.85, 1.18), 0.06)
			tw.tween_property(sprite, "scale", Vector2.ONE, 0.16)
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
	var base_dir := global_position.direction_to(target.global_position)
	# герой всегда лицом к цели атаки (не "задом")
	sprite.flip_h = target.global_position.x < global_position.x
	FX.cast(global_position + Vector2(0, -2))
	# отдача-пульс каста
	var tw := sprite.create_tween()
	tw.tween_property(sprite, "scale", Vector2(1.18, 0.88), 0.06)
	tw.tween_property(sprite, "scale", Vector2.ONE, 0.14)
	var n := dart_count
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
		xp_next = int(ceil(4.0 * pow(level, 1.35)))
		FX.level_up(global_position + Vector2(0, -18))
		FX.sparkle(global_position, 0.5)
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
