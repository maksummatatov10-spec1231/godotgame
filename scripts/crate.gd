class_name Crate
extends Node2D
## Разрушаемый ящик: ударь дротиком или огненным полумесяцем —
## разлетится щепками и кинет добычу (монета/флакон).
## Спрайты box1/box2 (Minifantasy), звук crate.

var radius := 7.0
var _broken := false

static func spawn(pos: Vector2) -> Crate:
	var c := Crate.new()
	c.global_position = pos
	c.z_index = 3
	var spr := AnimLib.sprite(
		"assets/items/box1" if randf() < 0.5 else "assets/items/box2", 5.0, true)
	c.add_child(spr)
	GameState.breakables.append(c)
	return c

func break_apart() -> void:
	if _broken:
		return
	_broken = true
	GameState.breakables.erase(self)
	FX.smoke(global_position, 0.4, 26)
	FX.sparkle(global_position, 0.25)
	FX.coin_burst(global_position, 0.2)
	SFX.play("crate", -2.0, randf_range(0.95, 1.1))
	# добыча: обычно монета, иногда флакон
	var r := randf()
	var kind := ""
	if r < 0.72:
		kind = "coin"
	elif r < 0.86:
		kind = "heal"
	elif r < 0.96:
		kind = "gem"
	if kind != "":
		get_parent().add_child(Pickup.spawn(
			kind, global_position + Vector2(randf_range(-4, 4), randf_range(-4, 4))))
	queue_free()

func _exit_tree() -> void:
	GameState.breakables.erase(self)
