extends CanvasLayer
## HUD на UI-паке FantasyUIfree: драконьи хп/опыт-бары, висячие доски-карточки,
## деревянные плашки, сферы счётчиков. View-порт 480x270.

var player: Node2D
var main: Node

var hp_bar: TextureProgressBar
var hp_label: Label
var xp_bar: TextureProgressBar
var level_label: Label
var timer_label: Label
var kills_label: Label
var score_label: Label
var boss_bar: Control
var boss_hp: TextureProgressBar
var boss_name: Label
var flash_label: Label
var _flash_t := 0.0
var levelup_panel: Control
var gameover_panel: Control
var win_panel: Control
var pause_panel: Control
var menu_panel: Control
var nick_edit: LineEdit
var _cards := []
var _pending_upgrades := []
var _paused := false

const TEX := "res://assets/ui/fantasy/"
# тематический значок + мини-значок из UI-пака на доске карточки
const UPGRADE_BADGES := {
	"dart_rate": "icon_circle", "dart_dmg": "icon_plus", "dart_count": "icon_pause",
	"slash": "icon_x", "boots": "arrow_wood", "heart": "vial_red",
	"magnet": "icon_dollar", "regen": "vial_green",
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	main = get_parent()
	_build_bars()
	_build_levelup()
	_build_gameover()
	_build_win()
	_build_pause()
	_build_menu()
	var credits := _mk_label("ui: FantasyUIfree | sfx: Minifantasy/8Bit/SfxPack4/JDSherbert/Hel Circle | dungeon: pixel_poem | fx: unTied Games", Vector2(4, 260), 7, Color(0.55, 0.5, 0.6, 0.8))
	add_child(credits)

func bind(p: Node2D) -> void:
	player = p

# ---------- ХЕЛПЕРЫ ----------

func _tex(name: String) -> Texture2D:
	return load(TEX + name + ".png")

func _mk_label(text: String, pos: Vector2, size: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.horizontal_alignment = align
	var ls := LabelSettings.new()
	ls.font_size = size
	ls.font_color = color
	ls.outline_size = 2
	ls.outline_color = Color(0, 0, 0, 0.8)
	l.label_settings = ls
	return l

func _mk_tex(name: String, pos: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = _tex(name)
	t.position = pos
	t.stretch_mode = TextureRect.STRETCH_KEEP
	return t

func _mk_dragon_bar(pos: Vector2, empty_name: String, full_name: String) -> TextureProgressBar:
	var b := TextureProgressBar.new()
	b.position = pos
	b.texture_under = _tex(empty_name)
	b.texture_progress = _tex(full_name)
	b.min_value = 0.0
	b.max_value = 100.0
	b.step = 0.1
	b.value = 100.0
	b.fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT
	b.size = Vector2(112, 32)
	return b

# ---------- ПОСТРОЕНИЕ UI ----------

func _build_bars() -> void:
	# HP — красный дракон-бар
	hp_bar = _mk_dragon_bar(Vector2(8, 6), "hp_player_empty", "hp_player_full")
	add_child(hp_bar)
	hp_label = _mk_label("100/100", Vector2(8, 16), 9, Color(1, 0.85, 0.85), HORIZONTAL_ALIGNMENT_CENTER)
	hp_label.size = Vector2(112, 12)
	add_child(hp_label)
	# XP — синий дракон-бар
	xp_bar = _mk_dragon_bar(Vector2(8, 40), "xp_empty", "xp_full")
	add_child(xp_bar)
	level_label = _mk_label("УР 1", Vector2(8, 49), 9, Color(0.75, 0.9, 1), HORIZONTAL_ALIGNMENT_CENTER)
	level_label.size = Vector2(112, 12)
	add_child(level_label)
	# таймер на деревянной плашке по центру сверху
	add_child(_mk_tex("plate_wide_x2", Vector2(195, 2)))
	timer_label = _mk_label("00:00", Vector2(195, 20), 13, Color(1, 0.95, 0.75), HORIZONTAL_ALIGNMENT_CENTER)
	timer_label.size = Vector2(90, 20)
	add_child(timer_label)
	# счётчики на сферах справа
	add_child(_mk_tex("orb_fire", Vector2(447, 4)))
	kills_label = _mk_label("0", Vector2(0, 11), 10, Color(1, 0.7, 0.5), HORIZONTAL_ALIGNMENT_RIGHT)
	kills_label.size = Vector2(442, 14)
	add_child(kills_label)
	add_child(_mk_tex("orb_water", Vector2(447, 34)))
	score_label = _mk_label("0", Vector2(0, 41), 10, Color(0.6, 0.85, 1), HORIZONTAL_ALIGNMENT_RIGHT)
	score_label.size = Vector2(442, 14)
	add_child(score_label)
	# босс-бар (по центру снизу)
	boss_bar = Control.new()
	boss_bar.visible = false
	add_child(boss_bar)
	boss_hp = _mk_dragon_bar(Vector2(184, 236), "hp_boss_empty", "hp_boss_full")
	boss_bar.add_child(boss_hp)
	boss_name = _mk_label("БОСС", Vector2(184, 222), 9, Color(1, 0.5, 0.6), HORIZONTAL_ALIGNMENT_CENTER)
	boss_name.size = Vector2(112, 12)
	boss_bar.add_child(boss_name)
	# мигающее сообщение по центру
	flash_label = _mk_label("", Vector2(0, 60), 16, Color(1, 0.9, 0.4), HORIZONTAL_ALIGNMENT_CENTER)
	flash_label.size = Vector2(480, 24)
	add_child(flash_label)

func _dim(color: Color) -> ColorRect:
	var dim := ColorRect.new()
	dim.size = Vector2(480, 270)
	dim.color = color
	return dim

func _build_levelup() -> void:
	levelup_panel = Control.new()
	levelup_panel.visible = false
	add_child(levelup_panel)
	levelup_panel.add_child(_dim(Color(0.03, 0, 0.06, 0.72)))
	var title := _mk_label("УРОВЕНЬ ВЫРОС — ВЫБЕРИ СИЛУ", Vector2(0, 22), 13, Color(1, 0.85, 0.3), HORIZONTAL_ALIGNMENT_CENTER)
	title.size = Vector2(480, 20)
	levelup_panel.add_child(title)
	# склянки-покровители по бокам заголовка (UI-пак)
	var vb := TextureRect.new()
	vb.texture = _tex("vial_blue_x2")
	vb.position = Vector2(88, 16)
	levelup_panel.add_child(vb)
	var vr := TextureRect.new()
	vr.texture = _tex("vial_white_x2")
	vr.position = Vector2(370, 16)
	levelup_panel.add_child(vr)

func _card(i: int, u: Dictionary) -> Control:
	# висячая деревянная доска из UI-пака
	var root := Control.new()
	var w := 71
	var h := 112
	root.position = Vector2(119 + i * (w + 14), 46)
	root.size = Vector2(w, h)
	var bg := TextureRect.new()
	bg.texture = _tex("board_tall")
	bg.size = Vector2(w, h)
	root.add_child(bg)
	# иконка улучшения (игровой спрайт)
	var icon := TextureRect.new()
	icon.texture = load(u["icon"])
	icon.position = Vector2(19, 22)
	icon.size = Vector2(32, 32)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	root.add_child(icon)
	# мини-значок из UI-пака на плече доски
	var badge_name: String = UPGRADE_BADGES.get(u["id"], "icon_question")
	var badge := TextureRect.new()
	badge.texture = _tex(badge_name)
	if badge_name == "arrow_wood":
		badge.position = Vector2(52, 6)
		badge.scale = Vector2.ONE * 0.5
	else:
		badge.position = Vector2(50, 12)
	root.add_child(badge)
	# текст
	var t := _mk_label(u["name"], Vector2(0, 56), 9, Color(1, 0.82, 0.45), HORIZONTAL_ALIGNMENT_CENTER)
	t.size = Vector2(w, 12)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(t)
	var d := _mk_label(u["desc"], Vector2(3, 68), 7, Color(0.92, 0.88, 0.95), HORIZONTAL_ALIGNMENT_CENTER)
	d.size = Vector2(w - 6, 22)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(d)
	# плашка-подсказка с номером клавиши
	var chip := TextureRect.new()
	chip.texture = _tex("plate_small")
	chip.position = Vector2(19, 88)
	root.add_child(chip)
	var hint := _mk_label(str(i + 1), Vector2(19, 94), 9, Color(0.55, 1, 0.55), HORIZONTAL_ALIGNMENT_CENTER)
	hint.size = Vector2(32, 12)
	root.add_child(hint)
	# интерактив
	root.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_pick(i)
	)
	root.mouse_entered.connect(func():
		root.scale = Vector2.ONE * 1.06
		root.pivot_offset = Vector2(w / 2.0, h / 2.0)
	)
	root.mouse_exited.connect(func():
		root.scale = Vector2.ONE
	)
	return root

func _build_gameover() -> void:
	gameover_panel = Control.new()
	gameover_panel.visible = false
	add_child(gameover_panel)
	gameover_panel.add_child(_dim(Color(0.04, 0, 0, 0.8)))
	# висячая доска 2x по центру
	var board := TextureRect.new()
	board.texture = _tex("board_tall_x2")
	board.position = Vector2(169, 20)
	gameover_panel.add_child(board)

func _build_win() -> void:
	win_panel = Control.new()
	win_panel.visible = false
	add_child(win_panel)
	win_panel.add_child(_dim(Color(0.06, 0.05, 0, 0.65)))
	var board := TextureRect.new()
	board.texture = _tex("board_short_x2")
	board.position = Vector2(169, 42)
	win_panel.add_child(board)

func _build_pause() -> void:
	pause_panel = Control.new()
	pause_panel.visible = false
	add_child(pause_panel)
	pause_panel.add_child(_dim(Color(0, 0, 0.04, 0.6)))
	var plate := TextureRect.new()
	plate.texture = _tex("plate_wide_x2")
	plate.position = Vector2(195, 100)
	pause_panel.add_child(plate)
	var pl := _mk_label("ПАУЗА", Vector2(195, 112), 13, Color(1, 0.9, 0.6), HORIZONTAL_ALIGNMENT_CENTER)
	pl.size = Vector2(90, 18)
	pause_panel.add_child(pl)
	var pi := TextureRect.new()
	pi.texture = _tex("icon_pause_x2")
	pi.position = Vector2(226, 134)
	pause_panel.add_child(pi)
	var pq := TextureRect.new()
	pq.texture = _tex("icon_question_x2")
	pq.position = Vector2(262, 134)
	pause_panel.add_child(pq)
	var hint := _mk_label("ESC — продолжить", Vector2(0, 172), 10, Color(0.7, 0.9, 1), HORIZONTAL_ALIGNMENT_CENTER)
	hint.size = Vector2(480, 16)
	pause_panel.add_child(hint)

# ---------- ГЛАВНОЕ МЕНЮ (ник вводится ВНИЗУ) ----------

func _build_menu() -> void:
	menu_panel = Control.new()
	menu_panel.visible = false
	add_child(menu_panel)
	var dim := _dim(Color(0.02, 0.01, 0.06, 0.97))
	menu_panel.add_child(dim)
	var title := _mk_label("DUNGEON SURVIVORS", Vector2(0, 26), 19, Color(1, 0.72, 0.25), HORIZONTAL_ALIGNMENT_CENTER)
	title.size = Vector2(480, 26)
	menu_panel.add_child(title)
	var sub := _mk_label("пиксельный данжен-survivor · Godot 4.3", Vector2(0, 52), 9, Color(0.75, 0.7, 0.85), HORIZONTAL_ALIGNMENT_CENTER)
	sub.size = Vector2(480, 14)
	menu_panel.add_child(sub)
	# висячая доска с подсказками
	var board := TextureRect.new()
	board.texture = _tex("board_tall_x2")
	board.position = Vector2(169, 66)
	menu_panel.add_child(board)
	var hints := _mk_label("WASD/стрелки — движение\n1/2/3 — выбор силы\nESC — пауза\nДвери вскрываются сблизи!", Vector2(0, 118), 9, Color(0.95, 0.9, 0.95), HORIZONTAL_ALIGNMENT_CENTER)
	hints.size = Vector2(480, 60)
	menu_panel.add_child(hints)
	# поле ника ВНИЗУ экрана
	var nick_lbl := _mk_label("НИК ГЕРОЯ (виден над головой):", Vector2(0, 196), 8, Color(0.7, 0.9, 1), HORIZONTAL_ALIGNMENT_CENTER)
	nick_lbl.size = Vector2(480, 12)
	menu_panel.add_child(nick_lbl)
	nick_edit = LineEdit.new()
	nick_edit.position = Vector2(170, 210)
	nick_edit.size = Vector2(140, 20)
	nick_edit.max_length = 14
	nick_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	nick_edit.placeholder_text = "ГЕРОЙ"
	nick_edit.text = GameState.player_name
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.05, 0.12)
	sb.border_color = Color(0.55, 0.4, 0.2)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 6.0
	nick_edit.add_theme_stylebox_override("normal", sb)
	nick_edit.add_theme_font_size_override("font_size", 10)
	nick_edit.add_theme_color_override("font_color", Color(0.9, 1, 1))
	nick_edit.text_submitted.connect(func(_t: String): _start_game())
	menu_panel.add_child(nick_edit)
	# кнопка ИГРАТЬ на деревянной плашке
	var btn := Control.new()
	btn.position = Vector2(195, 236)
	btn.size = Vector2(90, 30)
	var bpl := TextureRect.new()
	bpl.texture = _tex("plate_wide_x2")
	bpl.size = Vector2(90, 58)
	btn.add_child(bpl)
	var bl := _mk_label("ИГРАТЬ", Vector2(0, 6), 13, Color(1, 0.9, 0.5), HORIZONTAL_ALIGNMENT_CENTER)
	bl.size = Vector2(90, 20)
	btn.add_child(bl)
	btn.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_start_game()
	)
	btn.mouse_entered.connect(func(): bl.label_settings.font_color = Color(0.6, 1, 0.6))
	btn.mouse_exited.connect(func(): bl.label_settings.font_color = Color(1, 0.9, 0.5))
	menu_panel.add_child(btn)

func show_menu() -> void:
	nick_edit.text = GameState.player_name
	menu_panel.visible = true
	get_tree().paused = true
	SFX.play_music("music_menu")

func _start_game() -> void:
	var nick := nick_edit.text.strip_edges()
	GameState.player_name = nick if nick != "" else "ГЕРОЙ"
	menu_panel.visible = false
	get_tree().paused = false
	SFX.play("click", -2.0)
	SFX.play_music("music_main")
	flash("ВЫЖИВИ 10 МИНУТ, %s!" % GameState.player_name, 2.8)

# ---------- ЛОГИКА ----------

func _process(delta: float) -> void:
	if player and is_instance_valid(player) and not GameState.game_over:
		hp_bar.value = 100.0 * player.hp / player.max_hp
		hp_label.text = "%d/%d" % [maxi(0, int(player.hp)), int(player.max_hp)]
		xp_bar.value = 100.0 * float(player.xp) / float(player.xp_next)
		level_label.text = "УР %d" % player.level
		var t := int(GameState.run_time)
		timer_label.text = "%02d:%02d" % [floori(t / 60.0), t % 60]
		kills_label.text = "%d " % GameState.kills
		score_label.text = "%d " % GameState.score()
	if GameState.current_boss and is_instance_valid(GameState.current_boss):
		boss_bar.visible = true
		var b = GameState.current_boss
		boss_hp.value = 100.0 * b.hp / b.max_hp
		boss_name.text = Data.BOSSES.get(b.type_name, {}).get("title", "БОСС")
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
	SFX.play("click", -3.0)
	main.on_upgrade_picked(_pending_upgrades[i]["id"])

func show_game_over() -> void:
	# символы из гигапака поверх доски
	var txt := AnimLib.sprite("assets/ui/game_over_text", 15.0, true)
	txt.position = Vector2(240, 92)
	txt.scale = Vector2.ONE * 0.7
	gameover_panel.add_child(txt)
	var rank_id: String = GameState.rank()
	var rank := AnimLib.sprite("assets/ui/rank_" + rank_id, 15.0, true)
	rank.position = Vector2(240, 138)
	rank.scale = Vector2.ONE * 0.65
	gameover_panel.add_child(rank)
	var t := int(GameState.run_time)
	var stats := _mk_label("Время: %02d:%02d   Убийств: %d   Уровень: %d" % [floori(t / 60.0), t % 60, GameState.kills, player.level], Vector2(0, 172), 10, Color(0.95, 0.9, 0.9), HORIZONTAL_ALIGNMENT_CENTER)
	stats.size = Vector2(480, 18)
	gameover_panel.add_child(stats)
	var rank_lbl := _mk_label("РАНГ: " + rank_id, Vector2(0, 190), 11, Color(1, 0.85, 0.3), HORIZONTAL_ALIGNMENT_CENTER)
	rank_lbl.size = Vector2(480, 18)
	gameover_panel.add_child(rank_lbl)
	# плашка-подсказка
	var chip := TextureRect.new()
	chip.texture = _tex("plate_small")
	chip.position = Vector2(209, 212)
	gameover_panel.add_child(chip)
	var hint := _mk_label("R — заново", Vector2(209, 219), 10, Color(0.55, 1, 0.55), HORIZONTAL_ALIGNMENT_CENTER)
	hint.size = Vector2(62, 14)
	gameover_panel.add_child(hint)
	gameover_panel.visible = true

func show_win() -> void:
	# наполняем доску победы
	var txt := AnimLib.sprite("assets/ui/complete_text", 15.0, true)
	txt.position = Vector2(240, 102)
	txt.scale = Vector2.ONE * 0.7
	win_panel.add_child(txt)
	var crown := AnimLib.sprite("assets/ui/crown", 15.0, true)
	crown.position = Vector2(240, 134)
	crown.scale = Vector2.ONE * 0.42
	win_panel.add_child(crown)
	var rank_id: String = GameState.rank()
	var rank := AnimLib.sprite("assets/ui/rank_" + rank_id, 15.0, true)
	rank.position = Vector2(240, 162)
	rank.scale = Vector2.ONE * 0.5
	win_panel.add_child(rank)
	var hint := _mk_label("ENTER — продолжить в режиме ва-банк", Vector2(0, 226), 10, Color(0.6, 1, 0.6), HORIZONTAL_ALIGNMENT_CENTER)
	hint.size = Vector2(480, 18)
	win_panel.add_child(hint)
	win_panel.visible = true
	flash("ПОБЕДА! РЕЖИМ ВА-БАНК!", 3.0)

func _toggle_pause() -> void:
	if levelup_panel.visible or gameover_panel.visible or win_panel.visible or menu_panel.visible:
		return
	_paused = not _paused
	pause_panel.visible = _paused
	get_tree().paused = _paused
	SFX.play("click", -3.0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if menu_panel.visible and event.keycode == KEY_ENTER:
			_start_game()
		elif event.keycode == KEY_ESCAPE:
			_toggle_pause()
		elif levelup_panel.visible and event.keycode in [KEY_1, KEY_2, KEY_3]:
			_pick(event.keycode - KEY_1)
		elif gameover_panel.visible and event.keycode == KEY_R:
			SFX.play("click", -3.0)
			get_tree().paused = false
			get_tree().reload_current_scene()
		elif win_panel.visible and event.keycode == KEY_ENTER:
			SFX.play("click", -3.0)
			win_panel.visible = false
