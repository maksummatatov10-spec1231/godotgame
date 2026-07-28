extends Node
## Глобальное состояние забега (автозагрузка GameState).

const ARENA_RECT := Rect2(50, 66, 924, 448)  # играбельная зона в пикселях мира

var player: Node2D = null
var enemies: Array = []
var pickups: Array = []
var kills := 0
var run_time := 0.0
var current_boss: Node2D = null
var game_over := false
var won := false

var minutes: float:
	get: return run_time / 60.0

func reset() -> void:
	player = null
	enemies = []
	pickups = []
	kills = 0
	run_time = 0.0
	current_boss = null
	game_over = false
	won = false

func clamp_to_arena(pos: Vector2, margin: float = 0.0) -> Vector2:
	return Vector2(
		clampf(pos.x, ARENA_RECT.position.x + margin, ARENA_RECT.end.x - margin),
		clampf(pos.y, ARENA_RECT.position.y + margin, ARENA_RECT.end.y - margin)
	)

func score() -> int:
	return kills + int(run_time * 0.25)

func rank() -> String:
	var s := score()
	var r := "F"
	if s >= 650 or (won and s >= 500):
		r = "S"
	elif s >= 450:
		r = "A"
	elif s >= 300:
		r = "B"
	elif s >= 180:
		r = "C"
	elif s >= 80:
		r = "D"
	return r
