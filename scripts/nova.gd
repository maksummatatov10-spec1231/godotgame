class_name Nova
extends Node2D
## Огненная нова: ОГНЕННОЕ КОЛЬЦО из Super Pixel Effects Gigapack
## (round_firework_burst) разлетается от героя и жжёт всю толпу вокруг.
## v2: яркий, крупный, хорошо читаемый взрыв-кольцо вместо бледных огоньков.

var radius := 62.0
var dmg := 26.0

static func burst(parent: Node, pos: Vector2, p_radius: float, p_dmg: float, p_tier: int) -> void:
	var n := Nova.new()
	n.radius = p_radius
	n.dmg = p_dmg
	n.global_position = pos
	parent.add_child(n)
	n._ignite(p_tier)

func _ignite(p_tier: int) -> void:
	# урон — мгновенно всем, кого накрыло кольцо (массив-копия: смерти его мутируют)
	for e in GameState.enemies.duplicate():
		if is_instance_valid(e) and not e.dead:
			var d: float = global_position.distance_to(e.global_position)
			if d <= radius + e.radius:
				e.take_damage(dmg, global_position.direction_to(e.global_position))
	# ГЛАВНОЕ КОЛЬЦО: золотой round-burst из Гигапака, масштаб = радиусу новы
	# (кадр 96px = радиус 48 px; с 4-го тира — чистое золото, иначе — жар сыра)
	var ring := FX.spawn("assets/effects/fire_ring", global_position, 30.0, radius / 46.0, 12)
	if ring != null:
		if p_tier >= 3:
			ring.modulate = Color(1.55, 1.25, 0.55)  # золотое пламя!
		else:
			ring.modulate = Color(1.5, 0.78, 0.35)   # рыже огненное кольцо
	# вспышка в центре + огненные брызги по кругу − кольцо читается мгновенно
	FX.explosion(global_position, 0.9, false)
	var count := 8
	for i in range(count):
		var ang: float = TAU * float(i) / float(count)
		var rim: Vector2 = global_position + Vector2.from_angle(ang) * radius
		FX.spawn("assets/bullets/fire_explosion/red", rim, 22.0, 0.5, 12)
	# самоуничтожение, когда кольцо догорело
	get_tree().create_timer(0.9, false).timeout.connect(queue_free)
