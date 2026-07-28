class_name Slash
extends Node2D
## Огненный полумесяц — мгновенный удар по дуге перед игроком.
## Использует 4 кадра-полумесяца из огненного пака.

var dmg := 16.0
var radius := 46.0

static func strike(owner: Node, pos: Vector2, dir: Vector2, p_radius: float, p_dmg: float, tier: int) -> Slash:
	var s := Slash.new()
	s.dmg = p_dmg
	s.radius = p_radius
	s.global_position = pos + dir * 16.0
	s.rotation = dir.angle()
	s.z_index = 13
	var spr := AnimLib.sprite("assets/bullets/slash/" + Data.SLASH_COLORS[tier], 15.0, false)
	spr.scale = Vector2.ONE * (p_radius / 46.0)
	s.add_child(spr)
	# урон всем в передней полусфере
	for e in GameState.enemies:
		if not is_instance_valid(e) or e.dead:
			continue
		var to_e: Vector2 = e.global_position - pos
		if to_e.length() < p_radius + 20.0 and to_e.normalized().dot(dir) > 0.2:
			e.take_damage(p_dmg, dir)
	FX.spawn("assets/effects/impact_yellow", pos + dir * (p_radius * 0.5), 18.0, 0.3)
	owner.get_parent().get_node("Effects").add_child(s)
	return s

func _ready() -> void:
	var t := Timer.new()
	t.wait_time = 0.30
	t.one_shot = true
	t.timeout.connect(queue_free)
	add_child(t)
	t.start()
