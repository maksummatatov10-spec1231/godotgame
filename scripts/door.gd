class_name Door
extends Node2D
## Живая дверь. Пока закрыта — стена для героя, врагов и снарядов.
## Герой подходит — дверь трещит (анимация через тайлы) и вскрывается НАВСЕГДА:
## (6,2)/(8,3) закрыта → (7,2) трещит → обломки/пол (проходимо).
## Враги тоже могут выломать дверь, но дольше (долбят ~1.1 сек).
## Рисуй двери на слое Arena тайлами (6,2) или (8,3) — см. TUTORIAL_MAP.md.

const CLOSED_TILES := [Vector2i(6, 2), Vector2i(8, 3)]
const CRACK_TILE := Vector2i(7, 2)
# во что превращается дверь после вскрытия (обломки двери / пол)
const DEBRIS := {
	Vector2i(6, 2): Vector2i(6, 6),
	Vector2i(8, 3): Vector2i(5, 1),
}
const OPEN_RADIUS := 24.0      # герой подошёл ближе — дверь открывается
const CRACK_TIME := 0.15       # сек до трещины
const OPEN_TIME := 0.35        # сек от трещины до вскрытия
const ENEMY_SLOW := 4.5        # враги долбят медленнее (во столько раз)

var cell := Vector2i.ZERO
var closed_tile := Vector2i(6, 2)
var _stage := 0                 # 0 закрыта, 1 трещит, 2 вскрыта
var _t := 0.0
var _by_enemy := false          # дверь выломал враг (а не открыл герой)

static func register(cell_pos: Vector2i, tile: Vector2i) -> Door:
	var d := Door.new()
	d.cell = cell_pos
	d.closed_tile = tile
	GameState.closed_doors[cell_pos] = d
	return d

func _process(delta: float) -> void:
	if _stage >= 2 or GameState.game_over:
		return
	var arena := GameState.arena
	if arena == null:
		return
	var world := arena.to_global(arena.map_to_local(cell))
	global_position = world
	# кто-то рядом?
	var rate := 0.0
	var p := GameState.player
	if p and is_instance_valid(p) and p.global_position.distance_to(world) < OPEN_RADIUS:
		rate = 1.0
		_by_enemy = false
	else:
		for e in GameState.enemies:
			if is_instance_valid(e) and not e.dead and e.global_position.distance_to(world) < OPEN_RADIUS - 4.0:
				rate = 1.0 / ENEMY_SLOW
				_by_enemy = true
				break
	if rate <= 0.0:
		_t = maxf(0.0, _t - delta * 0.5)  # отошли — трещина "заживает"
		return
	_t += delta * rate
	if _stage == 0 and _t >= CRACK_TIME:
		_stage = 1
		arena.set_cell(cell, 0, CRACK_TILE)
		SFX.play("door", -3.0)
		FX.smoke(world + Vector2(0, -3), 0.3, 30)
	elif _stage == 1 and _t >= OPEN_TIME:
		_open(arena, world)

func _open(arena: TileMapLayer, world: Vector2) -> void:
	_stage = 2
	arena.set_cell(cell, 0, DEBRIS.get(closed_tile, Vector2i(5, 1)))
	GameState.closed_doors.erase(cell)
	GameState.set_walkable(cell, true)  # обновляем быстрый кэш проходимости
	if _by_enemy:
		SFX.play_at("doorbreak", world, 0.0)   # грохот позиционный: вдали — тихий
	else:
		SFX.play("hit", -4.0, 0.7)
	FX.smoke(world + Vector2(0, -2), 0.45, 30)
	FX.sparkle(world, 0.3)
	queue_free()
