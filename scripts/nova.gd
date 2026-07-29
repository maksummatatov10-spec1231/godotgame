class_name Nova
extends Node2D
## Огненная нова: кольцо пламени расходится от героя и жжёт всю толпу вокруг.
## Новый вид магической атаки — покупается на уровне (карточка "Огненная нова").

const LIFE := 0.42        # время разлёта кольца
const FLAME_SCALE := 0.5  # размер огоньков кольца

var radius := 62.0
var dmg := 26.0

var _t := 0.0
var _flames: Array = []   # {s: AnimatedSprite2D, dir: Vector2, spin: float}

static func burst(parent: Node, pos: Vector2, p_radius: float, p_dmg: float, p_tier: int) -> void:
	var n := Nova.new()
	n.radius = p_radius
	n.dmg = p_dmg
	n.global_position = pos
	parent.add_child(n)
	n._ignite(p_tier)

func _ignite(p_tier: int) -> void:
	z_index = 12
	# урон — мгновенно всем, кого накрыло пламенем (массив-копия: смерти его мутируют)
	for e in GameState.enemies.duplicate():
		if is_instance_valid(e) and not e.dead:
			var d: float = global_position.distance_to(e.global_position)
			if d <= radius + e.radius:
				e.take_damage(dmg, global_position.direction_to(e.global_position))
	# вспышка в центре + кольцо языков пламени (с 4-го уровня — золотое!)
	FX.explosion(global_position, 0.8, false)
	var dir_path := "assets/bullets/fire_explosion/gold" if p_tier >= 3 else "assets/bullets/fire_explosion/red"
	var count := 16
	for i in range(count):
		var ang := TAU * float(i) / float(count)
		var f := AnimLib.sprite(dir_path, 24.0, false)
		var frames_total: int = f.sprite_frames.get_frame_count("default")
		if frames_total > 0:
			f.frame = randi() % frames_total  # рассинхрон — кольцо живое, не штампованное
		f.scale = Vector2.ONE * FLAME_SCALE
		f.z_index = 12
		add_child(f)
		_flames.append({"s": f, "dir": Vector2.from_angle(ang)})

func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	var k: float = _t / LIFE
	var grow: float = ease(k, 0.6)          # резкий старт, мягкое затухание
	var r_now: float = lerpf(14.0, radius, grow)
	var shrink: float = lerpf(1.0, 0.55, k) # огоньки тают к краю
	for fl in _flames:
		var s: AnimatedSprite2D = fl["s"]
		if is_instance_valid(s):
			s.position = fl["dir"] * r_now
			s.scale = Vector2.ONE * FLAME_SCALE * shrink
