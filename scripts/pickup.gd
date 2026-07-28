class_name Pickup
extends Node2D
## Подбираемые предметы.
## Монета/флаконы/ключи — опыт и лечение; сундуки открываются с добычей.
## kind: coin, gem, elixir, heal, heal_big, key_silver, key_gold, chest, mini_chest

var kind := "coin"
var value := 1
var sprite: AnimatedSprite2D
var arrow: TextureRect  # деревянная стрелка-указатель над сундуками
var _vel := Vector2.ZERO
var _flying := false
var _opened := false
var _bob_t := 0.0
var _life := 0.0

const DESPAWN_AT := 46.0   # сек жизни мелкого лута (сундуки вечные)
const BLINK_AT := 36.0     # начало мигания "я скоро пропаду!"

static func spawn(kind_name: String, pos: Vector2) -> Pickup:
	var p := Pickup.new()
	p.kind = kind_name
	match kind_name:
		"coin":
			p.value = 1
			p.sprite = AnimLib.sprite("assets/items/coin", 8.0, true)
		"gem":  # синий флакон — опыт
			p.value = 6
			p.sprite = AnimLib.sprite("assets/items/flask_blue", 8.0, true)
		"elixir":  # зелёный флакон — много опыта
			p.value = 12
			p.sprite = AnimLib.sprite("assets/items/flask_green", 8.0, true)
		"heal":  # красный флакон — лечение
			p.value = 20
			p.sprite = AnimLib.sprite("assets/items/flask_red", 8.0, true)
		"heal_big":  # жёлтый флакон — сильное лечение
			p.value = 35
			p.sprite = AnimLib.sprite("assets/items/flask_yellow", 8.0, true)
		"key_silver":  # серебряный ключ — опыт
			p.value = 10
			p.sprite = AnimLib.sprite("assets/items/key_silver", 8.0, true)
		"key_gold":  # золотой ключ — много опыта
			p.value = 20
			p.sprite = AnimLib.sprite("assets/items/key_gold", 8.0, true)
		"chest":
			p.value = 0
			p.sprite = AnimLib.sprite("assets/items/chest", 6.0, true)
		"mini_chest":
			p.value = 0
			p.sprite = AnimLib.sprite("assets/items/mini_chest", 6.0, true)
		_:
			push_warning("Pickup: неизвестный kind '%s', делаю монету" % kind_name)
			p.kind = "coin"
			p.value = 1
			p.sprite = AnimLib.sprite("assets/items/coin", 8.0, true)
	p.global_position = pos
	p.z_index = 5
	p.add_child(p.sprite)
	if p.is_chest():
		# деревянная стрелка над неоткрытым сундуком (UI-пак)
		p.arrow = TextureRect.new()
		p.arrow.texture = load("res://assets/ui/fantasy/arrow_wood.png")
		p.arrow.position = Vector2(-8, -46)
		p.arrow.pivot_offset = Vector2(8, 26)
		p.arrow.scale = Vector2.ONE * 0.75
		p.arrow.z_index = 7
		p.add_child(p.arrow)
	GameState.pickups.append(p)
	return p

func is_chest() -> bool:
	return kind == "chest" or kind == "mini_chest"

func _process(delta: float) -> void:
	if _opened:
		return
	_life += delta
	# время жизни мелкого лута: мигание и исчезновение (сундуки вечные)
	if not is_chest():
		if _life >= DESPAWN_AT:
			_despawn()
			return
		if _life >= BLINK_AT:
			sprite.modulate.a = 0.35 + 0.65 * absf(sin(_life * 9.0))
	elif arrow:
		arrow.position.y = -46 + sin(_life * 4.0) * 3.0  # стрелка приглашает
		arrow.rotation = sin(_life * 4.0) * 0.12
	var pl := GameState.player
	if pl == null or not is_instance_valid(pl):
		return
	var dist := global_position.distance_to(pl.global_position)
	if is_chest():
		if dist < 16.0:
			_open_chest()
		return
	# магнит
	if _flying or dist < pl.magnet_radius:
		_flying = true
		var d := global_position.direction_to(pl.global_position)
		_vel = _vel.lerp(d * 190.0, delta * 6.0)
		global_position += _vel * delta
		if dist < 11.0:
			_collect(pl)
	else:
		_bob_t += delta * 4.0
		sprite.position.y = sin(_bob_t) * 1.2

func _despawn() -> void:
	GameState.pickups.erase(self)
	FX.smoke(global_position, 0.3, 20)
	var tw := sprite.create_tween()
	tw.set_parallel(true)
	tw.tween_property(sprite, "scale", Vector2.ZERO, 0.22)
	tw.tween_property(sprite, "modulate:a", 0.0, 0.22)
	tw.chain().tween_callback(queue_free)

func _collect(pl: Node2D) -> void:
	match kind:
		"coin":  # звон монеты растёт в тоне с твоим комбо (серия убийств)
			pl.add_xp(1)
			SFX.play("coin", -6.0, minf(1.45, 1.0 + GameState.combo * 0.045))
		"gem":
			pl.add_xp(value)
			FX.sparkle(global_position, 0.25)
			SFX.play("gem", -6.0, minf(1.35, 1.0 + GameState.combo * 0.035))
		"elixir":
			pl.add_xp(value)
			FX.sparkle(global_position, 0.35)
			SFX.play("gem", -4.0, 0.85)
		"key_silver", "key_gold":
			pl.add_xp(value)
			FX.sparkle(global_position, 0.4)
			FX.coin_burst(global_position, 0.25)
			SFX.play("key", -4.0, 1.1 if kind == "key_gold" else 1.0)
		"heal":
			pl.heal(float(value))
			SFX.play("flask", -4.0)
		"heal_big":  # большой жёлтый — почти воскрешение (хор из Hel Circle)
			pl.heal(float(value))
			SFX.play("resurrect", 0.0)
	GameState.pickups.erase(self)
	queue_free()

func _open_chest() -> void:
	if _opened:
		return
	_opened = true
	GameState.pickups.erase(self)
	if arrow:
		arrow.queue_free()  # сундук открыт — указатель больше не нужен
		arrow = null
	var is_mini := kind == "mini_chest"
	sprite.sprite_frames = AnimLib.frames(
		"assets/items/mini_chest_open" if is_mini else "assets/items/chest_open", 10.0, false)
	sprite.play("default")
	FX.coin_burst(global_position, 0.3 if is_mini else 0.5)
	SFX.play("crate" if is_mini else "chest", -3.0, 1.15 if is_mini else 1.0)
	sprite.animation_finished.connect(func():
		# монеты крутятся вокруг, потом летят к игроку
		var coins := 3 if is_mini else 6
		for i in range(coins):
			var coin := Pickup.spawn(
				"coin", global_position + Vector2.from_angle(TAU * i / float(coins)) * randf_range(8.0, 16.0))
			get_parent().add_child(coin)
		if not is_mini:
			for i in range(2):
				var gem := Pickup.spawn(
					"gem", global_position + Vector2(randf_range(-14, 14), randf_range(-10, 10)))
				get_parent().add_child(gem)
			if randf() < 0.5:
				get_parent().add_child(Pickup.spawn("heal", global_position + Vector2(10, 6)))
		FX.heart_burst(global_position, 0.55)
		FX.sparkle(global_position, 0.5)
		queue_free()
	, CONNECT_ONE_SHOT)

func _exit_tree() -> void:
	GameState.pickups.erase(self)
