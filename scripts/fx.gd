class_name FX
extends RefCounted
## Одноразовые эффекты: взрывы, брызги, вспышки. Сами исчезают.

## Цифры урона из пула (антилаг v0.15): раньше КАЖДОЕ попадание порождало
## новый Label + LabelSettings + Tween — при мясорубке это десятки объектов
## в секунду и микрофризы от работы сборщика. Теперь — постоянный пул лейблов,
## которые сами себя анимируют в _process: ноль аллокаций за удар.
class DmgLabel extends Label:
	const LIFE := 0.55
	var age := 0.0

	func _ready() -> void:
		z_index = 80
		visible = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func fire(pos: Vector2, amount: int, ls: LabelSettings) -> void:
		text = str(amount)
		label_settings = ls
		global_position = pos
		modulate.a = 1.0
		age = 0.0
		visible = true

	func _process(delta: float) -> void:
		if not visible:
			return
		age += delta
		global_position.y -= 24.0 * delta
		modulate.a = clampf(1.0 - age / LIFE, 0.0, 1.0)
		if age >= LIFE:
			visible = false

static var effects_root: Node2D = null
# ПУЛ-ЗАГОТОВКИ (идея игрока!): вместо "каждый раз новый объект" эффекты живут
# в запасниках по папкам и берутся оттуда копиями-переиспользованиями.
# Сгорел эффект → прячется обратно в запасник, а не умирает. Ноль мусора при шквале!
static var _pool := {}
const POOL_MAX_PER_KIND := 24

static func spawn(dir_path: String, pos: Vector2, fps: float = 15.0, scale: float = 1.0, z: int = 60) -> AnimatedSprite2D:
	if effects_root == null:
		return null
	var key := "%s|%0.2f" % [dir_path, fps]
	var s: AnimatedSprite2D = null
	if _pool.has(key) and not _pool[key].is_empty():
		s = _pool[key].pop_back()
		if not is_instance_valid(s):
			s = _mk_fx_sprite(key, dir_path, fps)
	else:
		# бюджет: когда мясорубка, декоративные вспышки сверх лимита пропускаем
		if effects_root.get_child_count() > 140:
			return null
		s = _mk_fx_sprite(key, dir_path, fps)
	s.visible = true
	s.modulate = Color.WHITE
	s.global_position = pos
	s.scale = Vector2.ONE * scale
	s.z_index = z
	s.play("default")
	return s

## новый спрайт эффекта и сразу подписка на возврат в пул
static func _mk_fx_sprite(key: String, dir_path: String, fps: float) -> AnimatedSprite2D:
	var s := AnimLib.sprite(dir_path, fps, false)
	effects_root.add_child(s)
	s.animation_finished.connect(_recycle.bind(s, key))
	return s

## догорел — назад в запасник (не удаляем!)
static func _recycle(s: AnimatedSprite2D, key: String) -> void:
	if not is_instance_valid(s):
		return
	var list: Array = _pool.get(key, [])
	if list.size() >= POOL_MAX_PER_KIND:
		s.queue_free()
		return
	s.stop()
	s.visible = false
	s.position = Vector2(-10000, -10000)
	list.append(s)
	_pool[key] = list

# короткие шорткаты
static func impact_yellow(pos: Vector2, scale := 0.24) -> void: spawn("assets/effects/impact_yellow", pos, 18.0, scale)
static func impact_blue(pos: Vector2, scale := 0.22) -> void: spawn("assets/effects/impact_blue", pos, 18.0, scale)
static func splatter(pos: Vector2, green := false, scale := 0.45) -> void:
	spawn("assets/effects/splatter_green" if green else "assets/effects/splatter_red", pos, 16.0, scale)
static func explosion(pos: Vector2, scale := 1.0, violet := false) -> void:
	spawn("assets/effects/explosion_violet" if violet else "assets/effects/explosion_orange", pos, 15.0, scale)
static func heal(pos: Vector2) -> void: spawn("assets/effects/heal_red", pos, 15.0, 0.5, 55)
static func level_up(pos: Vector2) -> void: spawn("assets/ui/level_up", pos, 15.0, 0.8, 55)
static func sparkle(pos: Vector2, scale := 0.35) -> void: spawn("assets/effects/sparkle_burst", pos, 16.0, scale)
static func crown(pos: Vector2) -> void: spawn("assets/ui/crown", pos + Vector2(0, -26), 15.0, 0.7, 70)
static func smoke_skull(pos: Vector2, scale := 0.8) -> void: spawn("assets/effects/skull_smoke", pos, 14.0, scale)
static func coin_burst(pos: Vector2, scale := 0.6) -> void: spawn("assets/effects/coin_burst", pos, 18.0, scale)
static func heart_burst(pos: Vector2, scale := 0.6) -> void: spawn("assets/effects/heart_burst", pos, 16.0, scale)
static func smoke(pos: Vector2, scale := 0.5, z := 60) -> void: spawn("assets/effects/smoke_burst", pos, 15.0, scale, z)
static func cast(pos: Vector2) -> void: spawn("assets/bullets/cast", pos, 14.0, 0.8, 15)

# всплывающие цифры урона/лечения — ПУЛ (переиспользуем, не создаём заново)
static var _dmg_labels: Array = []
const DMG_LABEL_MAX := 26
static var _ls_dmg: LabelSettings = null
static var _ls_crit: LabelSettings = null
static var _ls_heal: LabelSettings = null

static func _mk_dmg_ls(size: int, color: Color) -> LabelSettings:
	var ls := LabelSettings.new()
	ls.font_size = size
	ls.font_color = color
	ls.outline_size = 3 if size >= 13 else 2
	ls.outline_color = Color(0.1, 0.0, 0.1)
	return ls

static func damage_number(pos: Vector2, amount: int, color := Color(1.0, 0.9, 0.3), crit := false) -> void:
	if effects_root == null:
		return
	if _ls_dmg == null:
		_ls_dmg = _mk_dmg_ls(9, Color(1.0, 0.9, 0.3))
		_ls_crit = _mk_dmg_ls(13, Color(1.0, 0.45, 0.85))  # крит — ярко-розовый и крупный
		_ls_heal = _mk_dmg_ls(9, Color(0.4, 1.0, 0.4))
	var ls := _ls_crit if crit else (_ls_heal if color == Color(0.4, 1.0, 0.4) else _ls_dmg)
	# вычищаем мусор от прошлой сцены (после рестарта ссылки мертвы)
	for i in range(_dmg_labels.size() - 1, -1, -1):
		if not is_instance_valid(_dmg_labels[i]):
			_dmg_labels.remove_at(i)
	var l: DmgLabel = null
	for d in _dmg_labels:
		if not (d as DmgLabel).visible:
			l = d
			break
	if l == null:
		if _dmg_labels.size() >= DMG_LABEL_MAX:
			return  # тотальная мясорубка: лишние цифры просто не рисуем — кадр важнее
		l = DmgLabel.new()
		_dmg_labels.append(l)
		effects_root.add_child(l)
	l.fire(pos + Vector2(randf_range(-6.0, 6.0), -14.0), amount, ls)

static func heal_number(pos: Vector2, amount: int) -> void:
	damage_number(pos, amount, Color(0.4, 1.0, 0.4))
