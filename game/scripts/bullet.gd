class_name Bullet
extends Node2D
## Снаряд (дротик игрока / сфера вампира / комета босса). Столкновения — чистая математика, без физики.

var dir := Vector2.RIGHT
var speed := 250.0
var dmg := 10.0
var pierce := 0
var life := 1.7
var hostile := false
var hit_fx := ""
var hit_fx_scale := 0.24
var radius := 6.0
var rot_offset := 0.0  # дротик нарисован влево, комета — вправо

var _sprite: AnimatedSprite2D
var _hit_ids := []

static func dart(pos: Vector2, d: Vector2, p_speed: float, p_dmg: float, tier: int) -> Bullet:
	var b := Bullet.new()
	b.dir = d
	b.speed = p_speed
	b.dmg = p_dmg
	b.pierce = 1 if tier >= 4 else 0  # с синего пламени дротик пробивает насквозь
	var cfg: Dictionary = Data.PROJECTILES["dart"]
	b.life = cfg["life"]
	b.hit_fx = cfg["hit_fx"]
	b.hit_fx_scale = cfg["hit_fx_scale"]
	b.rot_offset = PI  # кадры смотрят влево
	b.global_position = pos
	b.z_index = 11
	b._sprite = AnimLib.sprite("assets/bullets/dart/" + Data.DART_COLORS[tier], cfg["fps"], true)
	b.add_child(b._sprite)
	return b

static func hostile_shot(projectile_id: String, pos: Vector2, d: Vector2, p_dmg: float) -> Bullet:
	var b := Bullet.new()
	b.hostile = true
	b.dir = d
	b.dmg = p_dmg
	var cfg: Dictionary = Data.PROJECTILES[projectile_id]
	b.speed = cfg["speed"]
	b.life = cfg["life"]
	b.hit_fx = cfg["hit_fx"]
	b.hit_fx_scale = cfg["hit_fx_scale"]
	b.global_position = pos
	b.z_index = 11
	b._sprite = AnimLib.sprite(cfg["dir"], cfg["fps"], true)
	b.add_child(b._sprite)
	return b

func _ready() -> void:
	rotation = dir.angle() + rot_offset

func _process(delta: float) -> void:
	global_position += dir * speed * delta
	life -= delta
	if life <= 0.0 or not GameState.map_rect.grow(40).has_point(global_position):
		_fizzle()
		return
	# столкновение со стеной карты
	if not GameState.is_walkable(global_position):
		_fizzle(true)
		return
	if hostile:
		_check_player()
	else:
		_check_enemies()

func _check_player() -> void:
	var p := GameState.player
	if p == null or not is_instance_valid(p):
		return
	if global_position.distance_to(p.global_position) < radius + 6.0:
		p.take_damage(dmg)
		_fizzle(true)

func _check_enemies() -> void:
	for e in GameState.enemies:
		if not is_instance_valid(e) or e.dead or _hit_ids.has(e.get_instance_id()):
			continue
		if global_position.distance_to(e.global_position) < radius + e.radius:
			_hit_ids.append(e.get_instance_id())
			e.take_damage(dmg, dir)
			if hit_fx != "":
				FX.spawn(hit_fx, e.global_position, 18.0, hit_fx_scale)
			if pierce > 0:
				pierce -= 1
			else:
				_fizzle()
			return

func _fizzle(with_fx := false) -> void:
	if with_fx and hit_fx != "":
		FX.spawn(hit_fx, global_position, 18.0, hit_fx_scale)
	queue_free()
