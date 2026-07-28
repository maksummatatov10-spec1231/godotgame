extends CanvasLayer
## HUD: бары, таймер, карточки уровня, экраны смерти/победы.
## Весь интерфейс строится кодом — view-порт 480x270.

var player: Node2D
var main: Node

var hp_fill: ColorRect
var hp_label: Label
var xp_fill: ColorRect
var level_label: Label
var timer_label: Label
var kills_label: Label
var boss_bar: Control
var boss_fill: ColorRect
var boss_name: Label
var flash_label: Label
var _flash_t := 0.0
var levelup_panel: Control
var gameover_panel: Control
var win_panel: Control
var _cards := []
var _pending_upgrades := []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	main = get_parent()
	_build_bars()
	_build_levelup()
	_build_gameover()
	_build_win()
	var credits := _mk_label("pixel dungeon: pixel_poem | fx: unTied Games | fire: BDragon1727 | rpg chars: Penzilla", Vector2(6, 258), 7, Color(0.55, 0.5, 0.6, 0.8))
	add_child(credits)

func bind(p: Node2D) -> void:
	player = p

# ---------- ПОСТРОЕНИЕ UI ----------

func _mk_label(text: String, pos: Vector2, size: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.horizontal_alignment = align
	var ls := LabelSettings.new()
	ls.font_size = size
	ls.font_color = color
	l.label_settings = ls
	return l

func _mk_bar(pos: Vector2, size: Vector2, bg: Color, fg: Color) -> Array:
	var b := ColorRect.new()
	b.position = pos
	b.size = size
	b.color = bg
	var f := ColorRect.new()
	f.position = pos + Vector2(1, 1)
	f.size = size - Vector2(2, 2)
	f.color = fg
	return [b, f]

func _build_bars() -> void:
	var hb = _mk_bar(Vector2(10, 8), Vector2(126, 10), Color(0.1, 0.05, 0.08, 0.85), Color(0.85, 0.2, 0.2))
	add_child(hb[0]); add_child(hb[1]); hp_fill = hb[1]
	hp_label = _mk_label("100/100", Vector2(142, 6), 9, Color(1, 0.85, 0.85))
	add_child(hp_label)
	var xb = _mk_bar(Vector2(10, 21), Vector2(460, 5), Color(0.08, 0.08, 0.05, 0.85), Color(0.35, 0.9, 0.3))
	add_child(xb[0]); add_child(xb[1]); xp_fill = xb[1]
	level_label = _mk_label("LV 1", Vector2(10, 28), 9, Color(0.8, 1, 0.7))
	add_child(level_label)
	timer_label = _mk_label("00:00", Vector2(0, 8), 13, Color(1, 0.95, 0.7), HORIZONTAL_ALIGNMENT_CENTER)
	timer_label.size = Vector2(480, 20)
	timer_label.position = Vector2(0, 8)
	add_child(timer_label)
	kills_label = _mk_label("☠ 0", Vector2(0, 8), 10, Color(1, 0.6, 0.6))
	kills_label.position = Vector2(430, 8)
	add_child(kills_label)
	# босс-бар
	boss_bar = Control.new()
	boss_bar.visible = false
	add_child(boss_bar)
	var bb = _mk_bar(Vector2(140, 246), Vector2(200, 9), Color(0.12, 0.02, 0.05, 0.9), Color(0.7, 0.1, 0.55))
	boss_bar.add_child(bb[0]); boss_bar.add_child(bb[1]); boss_fill = bb[1]
	boss_name = _mk_label("БОСС", Vector2(140, 234), 8, Color(1, 0.5, 0.9))
	boss_bar.add_child(boss_name)
	# мигающее сообщение
	flash_label = _mk_label("", Vector2(0, 60), 16, Color(1, 0.9, 0.4), HORIZONTAL_ALIGNMENT_CENTER)
	flash_label.size = Vector2(480, 24)
	add_child(flash_label)

func _build_levelup() -> void:
	levelup_panel = Control.new()
	levelup_panel.visible = false
	add_child(levelup_panel)
	var dim := ColorRect.new()
	dim.size = Vector2(480, 270)
	dim.color = Color(0.02, 0, 0.05, 0.72)
	levelup_panel.add_child(dim)
	var title := _mk_label("УРОВЕНЬ ВЫРОС — ВЫБЕРИ СИЛУ", Vector2(0, 34), 13, Color(1, 0.85, 0.3), HORIZONTAL_ALIGNMENT_CENTER)
	title.size = Vector2(480, 20)
	levelup_panel.add_child(title)

func _card(i: int, u: Dictionary) -> PanelContainer:
	var p := PanelContainer.new()
	p.position = Vector2(34 + i * 146, 66)
	p.size = Vector2(132, 142)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.05, 0.13, 0.97)
	sb.border_color = Color(0.85, 0.55, 0.2)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(v)
	var icon := TextureRect.new()
	icon.texture = load(u["icon"])
	icon.custom_minimum_size = Vector2(40, 36)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	v.add_child(icon)
	var t := _mk_label(u["name"], Vector2.ZERO, 11, Color(1, 0.8, 0.4), HORIZONTAL_ALIGNMENT_CENTER)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t)
	var d := _mk_label(u["desc"], Vector2.ZERO, 8, Color(0.85, 0.8, 0.9), HORIZONTAL_ALIGNMENT_CENTER)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(d)
	var hint := _mk_label("[ %d ]" % (i + 1), Vector2.ZERO, 9, Color(0.5, 1, 0.5), HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(hint)
	p.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_pick(i)
	)
	p.mouse_entered.connect(func(): sb.border_color = Color(1, 0.9, 0.3))
	p.mouse_exited.connect(func(): sb.border_color = Color(0.85, 0.55, 0.2))
	return p

func _build_gameover() -> void:
	gameover_panel = Control.new()
	gameover_panel.visible = false
	add_child(gameover_panel)
	var dim := ColorRect.new()
	dim.size = Vector2(480, 270)
	dim.color = Color(0.03, 0, 0, 0.78)
	gameover_panel.add_child(dim)

func _build_win() -> void:
	win_panel = Control.new()
	win_panel.visible = false
	add_child(win_panel)
	var dim := ColorRect.new()
	dim.size = Vector2(480, 270)
	dim.color = Color(0.05, 0.05, 0.02, 0.65)
	win_panel.add_child(dim)
	var txt := AnimLib.sprite("assets/ui/complete_text", 15.0, true)
	txt.position = Vector2(240, 85)
	txt.scale = Vector2.ONE * 0.85
	win_panel.add_child(txt)
	var crown := AnimLib.sprite("assets/ui/crown", 15.0, true)
	crown.position = Vector2(240, 120)
	crown.scale = Vector2.ONE * 0.5
	win_panel.add_child(crown)
	var rank := AnimLib.sprite("assets/ui/rank_S", 15.0, true)
	rank.position = Vector2(240, 160)
	rank.scale = Vector2.ONE * 0.8
	win_panel.add_child(rank)
	var t := _mk_label("Подземелье зачищено! Таймер идёт дальше — качаемся до упора", Vector2(0, 195), 10, Color(0.9, 1, 0.7), HORIZONTAL_ALIGNMENT_CENTER)
	t.size = Vector2(480, 20)
	win_panel.add_child(t)
	var hint := _mk_label("ENTER — продолжить", Vector2(0, 215), 10, Color(0.6, 1, 0.6), HORIZONTAL_ALIGNMENT_CENTER)
	hint.size = Vector2(480, 20)
	win_panel.add_child(hint)

# ---------- ЛОГИКА ----------

func _process(delta: float) -> void:
	if player and is_instance_valid(player) and not GameState.game_over:
		hp_fill.size = Vector2(maxi(0, int(124.0 * player.hp / player.max_hp)), 8)
		hp_label.text = "%d/%d" % [maxi(0, int(player.hp)), int(player.max_hp)]
		xp_fill.size = Vector2(int(458.0 * float(player.xp) / float(player.xp_next)), 3)
		level_label.text = "LV %d" % player.level
		var t := int(GameState.run_time)
		timer_label.text = "%02d:%02d" % [t / 60, t % 60]
		kills_label.text = "☠ %d" % GameState.kills
	if GameState.current_boss and is_instance_valid(GameState.current_boss):
		boss_bar.visible = true
		var b = GameState.current_boss
		boss_fill.size = Vector2(maxi(0, int(198.0 * b.hp / b.max_hp)), 7)
		boss_name.text = Data.BOSSES.get(b.type_name, {}).get("title", "БОСС")
		boss_name.position = Vector2(140 + 100 - boss_name.size.x / 2.0, 234)
	else:
		boss_bar.visible = false
	if _flash_t > 0.0:
		_flash_t -= delta
		flash_label.modulate.a = clampf(_flash_t, 0.0, 1.0)

func flash(text: String, time := 2.0) -> void:
	flash_label.text = text
	flash_label.modulate.a = 1.0
	_flash_t = time

func show_levelup(upgrades: Array) -> void:
	_pending_upgrades = upgrades
	for c in _cards:
		c.queue_free()
	_cards.clear()
	for i in range(upgrades.size()):
		var c := _card(i, upgrades[i])
		levelup_panel.add_child(c)
		_cards.append(c)
	levelup_panel.visible = true

func _pick(i: int) -> void:
	if not levelup_panel.visible or i >= _pending_upgrades.size():
		return
	levelup_panel.visible = false
	main.on_upgrade_picked(_pending_upgrades[i]["id"])

func show_game_over() -> void:
	# символы из гигапака
	var txt := AnimLib.sprite("assets/ui/game_over_text", 15.0, true)
	txt.position = Vector2(240, 80)
	txt.scale = Vector2.ONE * 0.85
	gameover_panel.add_child(txt)
	var rank_id: String = GameState.rank()
	var rank := AnimLib.sprite("assets/ui/rank_" + rank_id, 15.0, true)
	rank.position = Vector2(240, 130)
	rank.scale = Vector2.ONE * 0.75
	gameover_panel.add_child(rank)
	var t := int(GameState.run_time)
	var stats := _mk_label("Время: %02d:%02d   Убийств: %d   Уровень: %d" % [t / 60, t % 60, GameState.kills, player.level], Vector2(0, 175), 11, Color(0.95, 0.9, 0.9), HORIZONTAL_ALIGNMENT_CENTER)
	stats.size = Vector2(480, 20)
	gameover_panel.add_child(stats)
	var rank_lbl := _mk_label("РАНГ: " + rank_id, Vector2(0, 193), 12, Color(1, 0.85, 0.3), HORIZONTAL_ALIGNMENT_CENTER)
	rank_lbl.size = Vector2(480, 20)
	gameover_panel.add_child(rank_lbl)
	var hint := _mk_label("R — заново", Vector2(0, 215), 11, Color(0.6, 1, 0.6), HORIZONTAL_ALIGNMENT_CENTER)
	hint.size = Vector2(480, 20)
	gameover_panel.add_child(hint)
	gameover_panel.visible = true

func show_win() -> void:
	win_panel.visible = true
	flash("ПОБЕДА! РЕЖИМ ВА-БАНК!", 3.0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if levelup_panel.visible and event.keycode in [KEY_1, KEY_2, KEY_3]:
			_pick(event.keycode - KEY_1)
		elif gameover_panel.visible and event.keycode == KEY_R:
			get_tree().paused = false
			get_tree().reload_current_scene()
		elif win_panel.visible and event.keycode == KEY_ENTER:
			win_panel.visible = false
