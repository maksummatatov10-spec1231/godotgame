class_name FX
extends RefCounted
## Одноразовые эффекты: взрывы, брызги, вспышки. Сами исчезают.

static var effects_root: Node2D = null

static func spawn(dir_path: String, pos: Vector2, fps: float = 15.0, scale: float = 1.0, z: int = 60) -> AnimatedSprite2D:
	if effects_root == null:
		return null
	var s := AnimLib.sprite(dir_path, fps, false)
	s.global_position = pos
	s.scale = Vector2.ONE * scale
	s.z_index = z
	effects_root.add_child(s)
	s.animation_finished.connect(s.queue_free)
	return s

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
static func smoke(pos: Vector2, scale := 0.5) -> void: spawn("assets/effects/smoke_burst", pos, 15.0, scale)
static func cast(pos: Vector2) -> void: spawn("assets/bullets/cast", pos, 14.0, 0.8, 15)

# всплывающие цифры урона/лечения
static func damage_number(pos: Vector2, amount: int, color := Color(1.0, 0.9, 0.3)) -> void:
	if effects_root == null:
		return
	var l := Label.new()
	l.text = str(amount)
	l.z_index = 80
	var ls := LabelSettings.new()
	ls.font_size = 9
	ls.font_color = color
	ls.outline_size = 2
	ls.outline_color = Color(0.1, 0.0, 0.1)
	l.label_settings = ls
	l.global_position = pos + Vector2(randf_range(-6.0, 6.0), -14.0)
	effects_root.add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "global_position:y", l.global_position.y - 12.0, 0.5)
	tw.tween_property(l, "modulate:a", 0.0, 0.55)
	tw.chain().tween_callback(l.queue_free)

static func heal_number(pos: Vector2, amount: int) -> void:
	damage_number(pos, amount, Color(0.4, 1.0, 0.4))
