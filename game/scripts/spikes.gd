class_name Spikes
extends Node2D
## Ловушка-шипы из dungeon-пака: анимация peaks. Опасны, когда подняты (кадры 2-3).

var sprite: AnimatedSprite2D
var _tick := 0.0

func _init() -> void:
	sprite = AnimLib.sprite("assets/items/spikes", 4.0, true)
	add_child(sprite)
	z_index = 6

func _process(delta: float) -> void:
	_tick -= delta
	if _tick > 0.0 or sprite.frame < 2:
		return
	var pl := GameState.player
	if pl and is_instance_valid(pl) and global_position.distance_to(pl.global_position) < 11.0:
		_tick = 0.55
		pl.take_damage(8.0)
