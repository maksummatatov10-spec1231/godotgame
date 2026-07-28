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
var trail := false     # магический шлейф (дротики 5+ тира)
var _trail_t := 0.0

var _sprite: AnimatedSprite2D
var _hit_ids := []

# цвет свечения дротика по тиру (совпадает с палитрой пламени)
const TIER_LIGHT := [
	Color(1.0, 0.85, 0.4), Color(1.0, 0.7, 0.3), Color(1.0, 0.55, 0.2),
	Color(0.5, 1.0, 0.4), Color(0.4, 0.7, 1.0), Color(0.7, 0.4, 1.0),
	Color(1.0, 0.4, 0.9), Color(1.0, 0.3, 0.25),
]

static func _mk_light(color: Color, tex_scale: float, energy: float) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = load("res://assets/fx/light_warm.png")
	l.color = color
	l.texture_scale = tex_scale
	l.energy = energy
	l.shadow_enabled = false
	return l

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
	b.trail = tier >= 5  # фиолетовое пламя и выше оставляет искристый шлейф
	b.global_position = pos
	b.z_index = 11
	b._sprite = AnimLib.sprite("assets/bullets/dart/" + Data.DART_COLORS[tier], cfg["fps"], true)
	b.add_child(b._sprite)
	b.add_child(_mk_light(TIER_LIGHT[clampi(tier, 0, 7)], 0.32, 0.5))
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
	# свечение вражеских снарядов + кометы шумят при взрыве
	var dir_str: String = cfg.get("dir", "")
	if "comet" in dir_str:
		b.add_child(_mk_light(Color(1.0, 0.35, 0.2), 0.55, 0.6))
	elif "orb" in dir_str:
		b.add_child(_mk_light(Color(0.7, 0.4, 1.0), 0.35, 0.4))
	return b

func _ready() -> void:
	rotation = dir.angle() + rot_offset

func _process(delta: float) -> void:
	global_position += dir * speed * delta
	life -= delta
	if trail:
		_trail_t -= delta
		if _trail_t <= 0.0:  # шлейф из искр за снарядом
			_trail_t = 0.05
			FX.sparkle(global_position, 0.12)
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
			GameState.shots_hit += 1
			var final_dmg := dmg
			var crit := randf() < 0.10  # крит: 10% шанс, двойной урон, крупная цифра
			if crit:
				final_dmg *= 2.0
				SFX.play("crit", -4.0)
				FX.sparkle(e.global_position, 0.2)
			e.take_damage(final_dmg, dir, crit)
			SFX.play("hit", -10.0)
			if hit_fx != "":
				FX.spawn(hit_fx, e.global_position, 18.0, hit_fx_scale)
			if pierce > 0:
				pierce -= 1
			else:
				_fizzle()
			return
	# разрушаемые ящики — дротик разбивает их как врага
	for c in GameState.breakables:
		if not is_instance_valid(c):
			continue
		if global_position.distance_to(c.global_position) < radius + c.radius:
			c.break_apart()
			_fizzle(true)
			return

func _fizzle(with_fx := false) -> void:
	if with_fx and hit_fx != "":
		FX.spawn(hit_fx, global_position, 18.0, hit_fx_scale)
		if hostile and hit_fx_scale > 0.5:  # большой взрыв кометы шумит
			SFX.play("comet_hit", -3.0)
	queue_free()
