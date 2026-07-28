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
	sprite = AnimatedSprite2D.new()
	add_child(sprite)
	z_index = 10
	if is_boss:
		sprite.scale = Vector2.ONE * cfg["scale"]
		z_index = 14
	elif elite:
		sprite.scale = Vector2.ONE * 1.35
		sprite.modulate = Color(1.5, 0.8, 1.8)
	_play("move_anim")

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

func _process(delta: float) -> void:
	if dead:
		return
	if _hit_flash > 0.0:
		_hit_flash -= delta
		if _hit_flash <= 0.0:
			sprite.modulate = Color(1.5, 0.8, 1.8) if elite else Color.WHITE
	var p := GameState.player
	if p == null or not is_instance_valid(p) or GameState.game_over:
		return
	var to_p: Vector2 = p.global_position - global_position
	var dist := to_p.length()
	var dir := to_p.normalized() if dist > 0.1 else Vector2.ZERO
	sprite.flip_h = p.global_position.x > global_position.x
	_attack_cd -= delta

	# рывок кровавой твари
	if cfg.has("lunge"):
		var speed_val: float = cfg["speed"]
		_lunge_cd -= delta
		if _lunge_t > 0.0:
			_lunge_t -= delta
			global_position = GameState.clamp_to_arena(global_position + dir * speed_val * float(cfg["lunge"]["speed_mult"]) * delta, 10.0)
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
		var speed_val: float = cfg["speed"]
		var step: Vector2 = dir * speed_val * delta
		if cfg.get("wobble", false):
			_wobble_t += delta * 6.0
			step += dir.rotated(PI / 2.0) * sin(_wobble_t) * 36.0 * delta
		global_position = GameState.clamp_to_arena(global_position + step, 6.0)
		_play("move_anim")

func _touch_damage() -> void:
	var p := GameState.player
	if _attack_cd > 0.0 or p == null:
		return
	_attack_cd = cfg["attack_cd"]
	if cfg.get("no_attack_anim", false):
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

func take_damage(p_dmg: float, from_dir := Vector2.ZERO) -> void:
	if dead:
		return
	hp -= p_dmg
	_hit_flash = 0.1
	sprite.modulate = Color(3.0, 3.0, 3.0)
	FX.damage_number(global_position, int(p_dmg))
	if not is_boss and from_dir != Vector2.ZERO:
		global_position = GameState.clamp_to_arena(global_position + from_dir * 5.0, 6.0)
	if hp <= 0.0:
		die()
	elif cfg.has("hurt_anim") and not _attacking and randf() < 0.35:
		_attacking = true
		_play("hurt_anim")
		_back_to_move_once()

func die() -> void:
	if dead:
		return
	dead = true
	died.emit(self)
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
