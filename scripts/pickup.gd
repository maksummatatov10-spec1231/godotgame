class_name Pickup
extends Node2D
## Подбираемые предметы: монета (XP), флаконы (XP/лечение), сундук (ивент).

var kind := "coin"
var value := 1
var sprite: AnimatedSprite2D
var _vel := Vector2.ZERO
var _flying := false
var _opened := false
var _bob_t := 0.0

static func spawn(kind_: String, pos: Vector2) -> Pickup:
	var p := Pickup.new()
	p.kind = kind_
	match kind_:
		"coin":
			p.value = 1
			p.sprite = AnimLib.sprite("assets/items/coin", 8.0, true)
		"gem":
			p.value = 6
			p.sprite = AnimLib.sprite("assets/items/flask_blue", 8.0, true)
		"heal":
			p.value = 20
			p.sprite = AnimLib.sprite("assets/items/flask_red", 8.0, true)
		"chest":
			p.value = 0
			p.sprite = AnimLib.sprite("assets/items/chest", 6.0, true)
	p.global_position = pos
	p.z_index = 5
	p.add_child(p.sprite)
	GameState.pickups.append(p)
	return p

func _process(delta: float) -> void:
	var pl := GameState.player
	if pl == null or not is_instance_valid(pl) or _opened:
		return
	var dist := global_position.distance_to(pl.global_position)
	if kind == "chest":
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

func _collect(pl: Node2D) -> void:
	match kind:
		"coin":
			pl.add_xp(1)
		"gem":
			pl.add_xp(6)
			FX.sparkle(global_position, 0.25)
		"heal":
			pl.heal(20.0)
	GameState.pickups.erase(self)
	queue_free()

func _open_chest() -> void:
	if _opened:
		return
	_opened = true
	GameState.pickups.erase(self)
	sprite.sprite_frames = AnimLib.frames("assets/items/chest_open", 10.0, false)
	sprite.play("default")
	FX.coin_burst(global_position, 0.5)
	sprite.animation_finished.connect(func():
		# монеты крутятся вокруг, потом летят к игроку
		for i in range(6):
			var coin := Pickup.spawn("coin", global_position + Vector2.from_angle(TAU * i / 6.0) * randf_range(8.0, 16.0))
			get_parent().add_child(coin)
		for i in range(2):
			var gem := Pickup.spawn("gem", global_position + Vector2(randf_range(-14, 14), randf_range(-10, 10)))
			get_parent().add_child(gem)
		if randf() < 0.5:
			get_parent().add_child(Pickup.spawn("heal", global_position + Vector2(10, 6)))
		FX.heart_burst(global_position, 0.55)
		FX.sparkle(global_position, 0.5)
		queue_free()
	, CONNECT_ONE_SHOT)

func _exit_tree() -> void:
	GameState.pickups.erase(self)
