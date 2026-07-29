extends CanvasLayer
## HUD: драконьи хп/опыт-бары и сферы из пака FantasyUIfree (игроку нравятся — оставлены),
## а панели/карточки/кнопки — СОБСТВЕННЫЕ: рисуются кодом с пиксельной рамкой
## и тёплым шейдером блика (shaders/ui_warm.gdshader). View-порт 480x270.

## Наша панель: пиксельная рамка с заклёпками по углам + шейдер блика/свечения.
class UIPanel extends Control:
	var accent := Color(1.0, 0.8, 0.35)
	var fill := Color(0.07, 0.045, 0.11, 0.97)
	var _mat: ShaderMaterial

	func _init() -> void:
		_mat = ShaderMaterial.new()
		_mat.shader = load("res://shaders/ui_warm.gdshader")
		material = _mat

	func _ready() -> void:
		refresh()

	## применить акцент в рисунок и шейдер (вызвать после смены accent)
	func refresh() -> void:
		_mat.set_shader_parameter("accent", accent)
		queue_redraw()

	## 0..1 — подсветка при наведении
	func set_hover(v: float) -> void:
		_mat.set_shader_parameter("hover", v)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		# мягкая тень под панелью
		draw_rect(Rect2(Vector2(3, 4), size), Color(0, 0, 0, 0.5), true)
		# тело
		draw_rect(r, fill, true)
		# внешняя тёмная рамка 2px
		draw_rect(r, accent.darkened(0.72), false, 2.0)
		# внутренняя яркая нить
		var inner := Rect2(Vector2(3, 3), size - Vector2(6, 6))
		draw_rect(inner, Color(accent.lightened(0.2), 0.8), false, 1.0)
		# заклёпки-уголки 2px
		for c in [Vector2(2, 2), Vector2(size.x - 4, 2), Vector2(2, size.y - 4), Vector2(size.x - 4, size.y - 4)]:
			draw_rect(Rect2(c, Vector2(2, 2)), accent.lightened(0.35), true)


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
var menu_title: Label
var menu_sub: Label
var menu_group: Control     # висячая доска с ником и кнопкой (покачивается)
var menu_hint: Label
var menu_glows := []        # аддитивные свечения факелов
var embers: CPUParticles2D  # летящие искры
var nick_edit: LineEdit
var _menu_t := 0.0
var _menu_intro := 0.0      # идёт анимация появления меню
# настройки/миникарта/эффекты
var minimap: Control
var boss_arrow: TextureRect # стрелка на краю экрана к боссу за кадром
var combo_label: Label
var white_flash: ColorRect  # белая вспышка (смерть босса)
var _settings_rows := []    # строки переключателей на паузе
var _cards := []
var _pending_upgrades := []
var _paused := false

const TEX := "res://assets/ui/fantasy/"
# фирменный акцент каждой силы — рамка карточки, блик, раскраска
const UPGRADE_ACCENTS := {
	"dart_rate": Color(1.0, 0.60, 0.25),  # пылающие руны — огонь
	"dart_dmg": Color(1.0, 0.42, 0.35),   # урон — красный
	"dart_count": Color(0.75, 0.55, 1.0), # больше дротиков — фиолет
	"slash": Color(0.45, 0.85, 1.0),      # полумесяц — ледяная сталь
	"boots": Color(0.55, 1.0, 0.60),      # сапоги — ветер
	"heart": Color(1.0, 0.45, 0.55),      # сердце — рубин
	"magnet": Color(1.0, 0.85, 0.35),     # магнит — золото
	"regen": Color(0.65, 1.0, 0.50),      # реген — живая зелень
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
	# мини-карта (рисуется кодом, обновляется каждый кадр)
	minimap = Control.new()
	minimap.position = Vector2(378, 210)
	minimap.size = Vector2(98, 56)
	minimap.visible = false
	minimap.draw.connect(_mm_draw)
	add_child(minimap)
	# стрелка-указатель на босса за экраном
	boss_arrow = TextureRect.new()
	boss_arrow.texture = _tex("arrow_wood")
	boss_arrow.size = Vector2(8, 26)
	boss_arrow.pivot_offset = Vector2(4, 13)
	boss_arrow.stretch_mode = TextureRect.STRETCH_KEEP
	boss_arrow.visible = false
	add_child(boss_arrow)
	# белая вспышка поверх всего (на смерть босса)
	white_flash = ColorRect.new()
	white_flash.size = Vector2(480, 270)
	white_flash.color = Color(1, 1, 1)
	white_flash.modulate.a = 0.0
	white_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(white_flash)
	var credits := _mk_label("ui: FantasyUIfree | sfx: Minifantasy/8Bit/SfxPack4/JDSherbert/Hel Circle | dungeon: pixel_poem | fx: unTied Games", Vector2(4, 260), 7, Color(0.55, 0.5, 0.6, 0.8))
	add_child(credits)

func bind(p: Node2D) -> void:
	player = p

# ---------- ХЕЛПЕРЫ ----------

func _tex(fname: String) -> Texture2D:
	return load(TEX + fname + ".png")

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
	l.use_parent_material = false  # наш шейдер блика — только на панель, текст чист
	return l

func _mk_tex(fname: String, pos: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = _tex(fname)
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
	# таймер — просто чёткая цифра по центру сверху (без плашки: больше не загораживает)
	timer_label = _mk_label("00:00", Vector2(195, 4), 13, Color(1, 0.93, 0.7), HORIZONTAL_ALIGNMENT_CENTER)
	timer_label.size = Vector2(90, 18)
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
	# комбо-счётчик серии убийств
	combo_label = _mk_label("", Vector2(0, 26), 11, Color(1, 0.65, 0.2), HORIZONTAL_ALIGNMENT_CENTER)
	combo_label.size = Vector2(480, 14)
	add_child(combo_label)

## белая вспышка на весь экран (слоу-мо смерти босса)
func flash_screen() -> void:
	white_flash.modulate.a = 0.85
	var tw := white_flash.create_tween()
	tw.tween_property(white_flash, "modulate:a", 0.0, 0.4)

## отрисовка мини-карты (сигнал draw узла minimap)
func _mm_draw() -> void:
	var pr := GameState.play_rect
	if pr.size.x < 1.0:
		return
	var sc: Vector2 = minimap.size / pr.size
	minimap.draw_rect(Rect2(Vector2.ZERO, minimap.size), Color(0.02, 0.02, 0.06, 0.75), true)
	minimap.draw_rect(Rect2(Vector2.ZERO, minimap.size), Color(0.75, 0.6, 0.35, 0.9), false, 1.0)
	var dot := func(p: Vector2, c: Color, r: float) -> void:
		var lp: Vector2 = (p - pr.position) * sc
		lp = lp.clamp(Vector2(2.5, 2.5), minimap.size - Vector2(2.5, 2.5))
		minimap.draw_circle(lp, r, c)
	# закрытые двери — янтарные точки
	if GameState.arena and is_instance_valid(GameState.arena):
		for cell2 in GameState.closed_doors:
			dot.call(GameState.arena.to_global(GameState.arena.map_to_local(cell2)), Color(0.85, 0.55, 0.2), 1.6)
	# сундуки — золотые, мелкий лут — голубой
	for pk in GameState.pickups:
		if not is_instance_valid(pk):
			continue
		if pk.is_chest():
			dot.call(pk.global_position, Color(1.0, 0.8, 0.2), 2.0)
		else:
			dot.call(pk.global_position, Color(0.4, 0.8, 1.0, 0.85), 1.0)
	# врагада — красные точки
	for e in GameState.enemies:
		if is_instance_valid(e) and not e.dead and not e.is_boss:
			dot.call(e.global_position, Color(1.0, 0.3, 0.3), 1.4)
	# босс — крупная фиолетовая точка
	if GameState.current_boss and is_instance_valid(GameState.current_boss):
		dot.call(GameState.current_boss.global_position, Color(1.0, 0.2, 0.85), 3.0)
	# герой — белая точка
	if player and is_instance_valid(player):
		dot.call(player.global_position, Color(1, 1, 1), 2.2)

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
	var title := _mk_label("УРОВЕНЬ ВЫРОС — ВЫБЕРИ СИЛУ", Vector2(0, 12), 14, Color(1, 0.85, 0.3), HORIZONTAL_ALIGNMENT_CENTER)
	title.size = Vector2(480, 20)
	levelup_panel.add_child(title)
	var sub := _mk_label("клик или клавиши 1 · 2 · 3", Vector2(0, 33), 9, Color(0.72, 0.82, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	sub.size = Vector2(480, 12)
	levelup_panel.add_child(sub)

## наша карточка силы: акцентная панель с бликом, свечение иконки, чёткий текст
func _card(i: int, u: Dictionary) -> Control:
	var accent: Color = UPGRADE_ACCENTS.get(u["id"], Color(1.0, 0.8, 0.35))
	var w := 112
	var h := 140
	var root := Control.new()
	root.position = Vector2(58 + i * (w + 14), 50)
	root.size = Vector2(w, h)
	root.pivot_offset = Vector2(w / 2.0, h / 2.0)
	var p := UIPanel.new()
	p.size = Vector2(w, h)
	p.accent = accent
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(p)
	# мягкий ореол за иконкой в цвет силы (аддитивное свечение)
	var halo := TextureRect.new()
	halo.texture = load("res://assets/fx/light_warm.png")
	halo.position = Vector2(24, 2)
	halo.size = Vector2(64, 64)
	halo.modulate = Color(accent, 0.45)
	var cm := CanvasItemMaterial.new()
	cm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	halo.material = cm
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(halo)
	# иконка силы
	var icon := TextureRect.new()
	icon.texture = load(u["icon"])
	icon.position = Vector2(38, 12)
	icon.size = Vector2(36, 36)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(icon)
	# название: центр, до двух строк, в цвет акцента (обрезается строго по рамке)
	var t := _mk_label(u["name"], Vector2(3, 52), 8, accent.lightened(0.35), HORIZONTAL_ALIGNMENT_CENTER)
	t.size = Vector2(w - 6, 26)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.clip_text = true
	root.add_child(t)
	# описание: полностью видно, мелкий светлый текст (строго по рамке)
	var d := _mk_label(u["desc"], Vector2(5, 80), 7, Color(0.93, 0.9, 0.97), HORIZONTAL_ALIGNMENT_CENTER)
	d.size = Vector2(w - 10, 36)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.clip_text = true
	root.add_child(d)
	# цифра клавиши — мини-панелька внизу карточки
	var chip := UIPanel.new()
	chip.size = Vector2(24, 14)
	chip.position = Vector2(w / 2.0 - 12, h - 22)
	chip.accent = accent
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(chip)
	var hint := _mk_label(str(i + 1), Vector2(w / 2.0 - 12, h - 21), 9, Color(1, 1, 1), HORIZONTAL_ALIGNMENT_CENTER)
	hint.size = Vector2(24, 12)
	root.add_child(hint)
	# интерактив: наведение — рост и блик, клик — выбор
	root.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_pick(i)
	)
	root.mouse_entered.connect(func():
		var hw := root.create_tween()
		hw.tween_property(root, "scale", Vector2.ONE * 1.07, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		p.set_hover(1.0)
	)
	root.mouse_exited.connect(func():
		var hw := root.create_tween()
		hw.tween_property(root, "scale", Vector2.ONE, 0.15)
		p.set_hover(0.0)
	)
	return root

func _build_gameover() -> void:
	gameover_panel = Control.new()
	gameover_panel.visible = false
	add_child(gameover_panel)
	gameover_panel.add_child(_dim(Color(0.04, 0, 0, 0.8)))
	# СВОЯ панель по центру (рубиновый акцент смерти)
	var p := UIPanel.new()
	p.position = Vector2(131, 36)
	p.size = Vector2(218, 196)
	p.accent = Color(1.0, 0.42, 0.45)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gameover_panel.add_child(p)

func _build_win() -> void:
	win_panel = Control.new()
	win_panel.visible = false
	add_child(win_panel)
	win_panel.add_child(_dim(Color(0.06, 0.05, 0, 0.65)))
	# СВОЯ панель по центру (золото победы)
	var p := UIPanel.new()
	p.position = Vector2(131, 42)
	p.size = Vector2(218, 184)
	p.accent = Color(1.0, 0.82, 0.35)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	win_panel.add_child(p)

func _build_pause() -> void:
	# пауза = СВОЯ панель настроек: всё переключается прямо во время игры (клик/1-5)
	pause_panel = Control.new()
	pause_panel.visible = false
	add_child(pause_panel)
	pause_panel.add_child(_dim(Color(0, 0, 0.04, 0.68)))
	var p := UIPanel.new()
	p.position = Vector2(143, 50)
	p.size = Vector2(194, 156)
	p.accent = Color(0.55, 0.8, 1.0)   # ледяная сталь настроек
	pause_panel.add_child(p)
	var title := _mk_label("НАСТРОЙКИ", Vector2(143, 58), 12, Color(0.85, 0.95, 1), HORIZONTAL_ALIGNMENT_CENTER)
	title.size = Vector2(194, 14)
	pause_panel.add_child(title)
	_settings_rows.clear()
	_mk_setting_row("opt_manual_aim", "Ручная стрельба (ЛКМ)", 80)
	_mk_setting_row("opt_minimap", "Мини-карта", 100)
	_mk_setting_row("opt_slowmo", "Слоу-мо боссов", 120)
	_mk_setting_row("sfx", "Звуковые эффекты", 140)
	_mk_setting_row("music", "Музыка", 160)
	var hint := _mk_label("ESC — назад · клик или 1-5 — переключить", Vector2(143, 186), 8, Color(0.7, 0.9, 1), HORIZONTAL_ALIGNMENT_CENTER)
	hint.size = Vector2(194, 12)
	pause_panel.add_child(hint)

## строка-переключатель настроек: [№] название ... {таблетка ВКЛ/ВЫКЛ}
func _mk_setting_row(key: String, text: String, y: float) -> void:
	var idx := _settings_rows.size()
	var row := Control.new()
	row.position = Vector2(153, y)
	row.size = Vector2(174, 16)
	pause_panel.add_child(row)
	# номер клавиши — мини-панелька
	var chip := UIPanel.new()
	chip.size = Vector2(14, 14)
	chip.position = Vector2(0, 1)
	chip.accent = Color(0.55, 0.8, 1.0)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(chip)
	var num := _mk_label(str(idx + 1), Vector2(0, 2), 8, Color(1, 1, 1), HORIZONTAL_ALIGNMENT_CENTER)
	num.size = Vector2(14, 12)
	row.add_child(num)
	var name_l := _mk_label(text, Vector2(20, 2), 8, Color(0.92, 0.9, 0.96))
	name_l.size = Vector2(108, 12)
	row.add_child(name_l)
	# таблетка состояния (зелёная/красная)
	var pill := UIPanel.new()
	pill.size = Vector2(44, 14)
	pill.position = Vector2(130, 1)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(pill)
	var state_l := _mk_label("ВКЛ", Vector2(130, 2), 8, Color(0.75, 1, 0.75), HORIZONTAL_ALIGNMENT_CENTER)
	state_l.size = Vector2(44, 12)
	row.add_child(state_l)
	row.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_toggle_setting(idx)
	)
	row.mouse_entered.connect(func():
		name_l.label_settings.font_color = Color(1, 0.95, 0.6)
		pill.set_hover(0.7)
	)
	row.mouse_exited.connect(func():
		name_l.label_settings.font_color = Color(0.92, 0.9, 0.96)
		pill.set_hover(0.0)
	)
	_settings_rows.append({"key": key, "state": state_l, "pill": pill, "name": name_l})
	_refresh_setting(idx)

func _setting_on(idx: int) -> bool:
	match String(_settings_rows[idx]["key"]):
		"opt_manual_aim": return GameState.opt_manual_aim
		"opt_minimap": return GameState.opt_minimap
		"opt_slowmo": return GameState.opt_slowmo
		"sfx": return SFX.enabled
		"music": return SFX.music_enabled
	return false

func _refresh_setting(idx: int) -> void:
	var on := _setting_on(idx)
	var rowd: Dictionary = _settings_rows[idx]
	var l: Label = rowd["state"]
	l.text = "ВКЛ" if on else "ВЫКЛ"
	l.label_settings.font_color = Color(0.7, 1, 0.7) if on else Color(1, 0.62, 0.6)
	rowd["pill"].accent = Color(0.5, 1, 0.5) if on else Color(1, 0.5, 0.5)
	rowd["pill"].refresh()

## переключить настройку: мгновенно применяется, не снимая паузу
func _toggle_setting(idx: int) -> void:
	match String(_settings_rows[idx]["key"]):
		"opt_manual_aim": GameState.opt_manual_aim = not GameState.opt_manual_aim
		"opt_minimap": GameState.opt_minimap = not GameState.opt_minimap
		"opt_slowmo": GameState.opt_slowmo = not GameState.opt_slowmo
		"sfx": SFX.enabled = not SFX.enabled
		"music": SFX.set_music_enabled(not SFX.music_enabled)
	SFX.play("click", -2.0)
	_refresh_setting(idx)
	GameState.save_profile()  # настройки запоминаются между запусками

# ---------- ГЛАВНОЕ МЕНЮ (ник вводится ВНИЗУ) ----------
# Красивости: затемнение, пульсирующий заголовок, живые факелы с аддитивным
# свечением, качающаяся СВОЯ панель, летящие искры (светятся в режиме ADD),
# каскадное появление элементов твинами.

## наша кнопка: панель с бликом + текст; наведение — рост и свечение кромки
func _mk_button(text: String, pos: Vector2, bsize: Vector2, accent: Color, cb: Callable) -> Control:
	var btn := Control.new()
	btn.position = pos
	btn.size = bsize
	btn.pivot_offset = bsize / 2.0
	var p := UIPanel.new()
	p.size = bsize
	p.accent = accent
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(p)
	var l := _mk_label(text, Vector2.ZERO, 13, Color(1, 0.93, 0.62), HORIZONTAL_ALIGNMENT_CENTER)
	l.size = bsize
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	btn.add_child(l)
	btn.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			cb.call()
	)
	btn.mouse_entered.connect(func():
		var hw := btn.create_tween()
		hw.tween_property(btn, "scale", Vector2.ONE * 1.06, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		p.set_hover(1.0)
	)
	btn.mouse_exited.connect(func():
		var hw := btn.create_tween()
		hw.tween_property(btn, "scale", Vector2.ONE, 0.14)
		p.set_hover(0.0)
	)
	return btn

## аддитивное свечение из мягкого радиального градиента (текстура света факелов)
func _mk_glow(pos: Vector2, size: float, color: Color) -> TextureRect:
	var g := TextureRect.new()
	g.texture = load("res://assets/fx/light_warm.png")
	g.position = pos
	g.size = Vector2(size, size)
	g.modulate = color
	var cm := CanvasItemMaterial.new()
	cm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	g.material = cm
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_glows.append(g)
	return g

func _build_menu() -> void:
	menu_panel = Control.new()
	menu_panel.visible = false
	add_child(menu_panel)
	menu_panel.add_child(_dim(Color(0.02, 0.01, 0.06, 0.92)))
	# живые факелы по бокам + мягкое свечение (аддитив)
	for tx in [52.0, 428.0]:
		var glow := _mk_glow(Vector2(tx - 40, 20), 80.0, Color(1, 0.6, 0.28, 0.5))
		menu_panel.add_child(glow)
		var torch := AnimLib.sprite("assets/items/torch", 6.0, true)
		torch.position = Vector2(tx, 56)
		torch.scale = Vector2.ONE * 2.0
		menu_panel.add_child(torch)
	# заголовок-маяк
	menu_title = _mk_label("DUNGEON SURVIVORS", Vector2(0, 16), 20, Color(1, 0.75, 0.3), HORIZONTAL_ALIGNMENT_CENTER)
	menu_title.size = Vector2(480, 26)
	menu_panel.add_child(menu_title)
	menu_sub = _mk_label("пиксельный данжен-survivor · Godot 4.3", Vector2(0, 42), 9, Color(0.78, 0.72, 0.88), HORIZONTAL_ALIGNMENT_CENTER)
	menu_sub.size = Vector2(480, 14)
	menu_panel.add_child(menu_sub)
	# СВОЯ висячая панель (качается как табличка на цепях): подсказки, ник, кнопка
	menu_group = Control.new()
	menu_group.position = Vector2(145, 56)
	menu_group.size = Vector2(190, 172)
	menu_group.pivot_offset = Vector2(95, 0)
	menu_panel.add_child(menu_group)
	var mp := UIPanel.new()
	mp.size = Vector2(190, 172)
	mp.accent = Color(1.0, 0.78, 0.32)   # золото главного меню
	mp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_group.add_child(mp)
	var hints := _mk_label("WASD/стрелки — движение\nSPACE — рывок!\n1/2/3 — выбор силы\nESC — пауза, настройки", Vector2(0, 12), 9, Color(0.95, 0.9, 0.95), HORIZONTAL_ALIGNMENT_CENTER)
	hints.size = Vector2(190, 48)
	menu_group.add_child(hints)
	# поле ника — сразу, без лишних надписей (ник запоминается между запусками)
	nick_edit = LineEdit.new()
	nick_edit.position = Vector2(20, 70)
	nick_edit.size = Vector2(150, 20)
	nick_edit.max_length = 14
	nick_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	nick_edit.placeholder_text = "ГЕРОЙ"
	nick_edit.text = GameState.player_name
	nick_edit.use_parent_material = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.04, 0.10)
	sb.border_color = Color(0.72, 0.55, 0.25)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 6.0
	nick_edit.add_theme_stylebox_override("normal", sb)
	nick_edit.add_theme_font_size_override("font_size", 10)
	nick_edit.add_theme_color_override("font_color", Color(0.9, 1, 1))
	nick_edit.text_submitted.connect(func(_t: String): _start_game())
	menu_group.add_child(nick_edit)
	# кнопка ИГРАТЬ — наша, с бликом и отскоком
	var btn := _mk_button("ИГРАТЬ", Vector2(47, 106), Vector2(96, 30), Color(0.65, 1, 0.6), Callable(self, "_start_game"))
	menu_group.add_child(btn)
	# мигающая подсказка под доской
	menu_hint = _mk_label("ENTER или клик — В БОЙ!", Vector2(0, 240), 10, Color(0.65, 1, 0.65), HORIZONTAL_ALIGNMENT_CENTER)
	menu_hint.size = Vector2(480, 16)
	menu_panel.add_child(menu_hint)
	var ver := _mk_label("v0.11.1", Vector2(0, 256), 8, Color(0.6, 0.6, 0.7, 0.7), HORIZONTAL_ALIGNMENT_RIGHT)
	ver.size = Vector2(472, 12)
	menu_panel.add_child(ver)
	# летящие искры-угольки (аддитивные — красиво светятся в темноте)
	embers = CPUParticles2D.new()
	embers.amount = 28
	embers.lifetime = 6.0
	embers.preprocess = 6.0  # меню открывается — искры уже летают!
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(250, 4)
	embers.position = Vector2(240, 278)
	embers.direction = Vector2(0, -1)
	embers.spread = 35.0
	embers.gravity = Vector2(0, -3.5)
	embers.initial_velocity_min = 4.0
	embers.initial_velocity_max = 11.0
	embers.scale_amount_min = 0.04
	embers.scale_amount_max = 0.1
	embers.texture = load("res://assets/fx/light_warm.png")
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0))   # рождение — прозрачно
	grad.set_color(1, Color(0, 0, 0, 0))   # смерть — растворяется
	grad.add_point(0.25, Color(1, 0.6, 0.25, 0.75))  # яркая серединка жизни искры
	embers.color_ramp = grad
	var ecm := CanvasItemMaterial.new()
	ecm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	embers.material = ecm
	menu_panel.add_child(embers)

## непрерывная анимация меню (вызывается из _process, пока меню видно)
func _menu_animate(delta: float) -> void:
	_menu_t += delta
	if _menu_intro > 0.0:
		_menu_intro = maxf(0.0, _menu_intro - delta)
		return  # идёт каскадное появление — твины сами всё двигают
	var t := _menu_t
	# заголовок дышит и переливается золотом
	menu_title.position.y = 16 + sin(t * 1.3) * 2.0
	menu_title.label_settings.font_color = Color(1.0, 0.72 + 0.14 * sin(t * 2.1), 0.28 + 0.1 * sin(t * 2.1))
	# доска покачивается на цепях
	menu_group.rotation = sin(t * 0.8) * 0.012
	# свечения факелов мерцают (в такт мерцающим факелам мира)
	for i in range(menu_glows.size()):
		var g: TextureRect = menu_glows[i]
		g.modulate.a = 0.42 + 0.1 * sin(t * 9.0 + i * 2.6) + 0.05 * sin(t * 23.0 + i)
	# подсказка дышит
	menu_hint.modulate.a = 0.55 + 0.45 * sin(t * 3.2)

func show_menu() -> void:
	nick_edit.text = GameState.player_name
	menu_panel.visible = true
	get_tree().paused = true
	SFX.play_music("music_menu")
	# каскадное появление: заголовок падает сверху, доска выезжает, свечения разгораются
	_menu_intro = 1.1
	menu_title.position = Vector2(0, -26)
	menu_title.modulate.a = 0.0
	menu_sub.modulate.a = 0.0
	menu_group.position = Vector2(145, 34)
	menu_group.modulate.a = 0.0
	menu_hint.modulate.a = 0.0
	for g in menu_glows:
		g.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(menu_title, "position", Vector2(0, 16), 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(menu_title, "modulate:a", 1.0, 0.3)
	tw.tween_property(menu_sub, "modulate:a", 1.0, 0.4).set_delay(0.25)
	tw.tween_property(menu_group, "position", Vector2(145, 56), 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.15)
	tw.tween_property(menu_group, "modulate:a", 1.0, 0.35).set_delay(0.15)
	tw.tween_property(menu_hint, "modulate:a", 1.0, 0.4).set_delay(0.6)
	for i in range(menu_glows.size()):
		tw.tween_property(menu_glows[i], "modulate:a", 0.5, 0.5).set_delay(0.3 + i * 0.1)

func _start_game() -> void:
	var nick := nick_edit.text.strip_edges()
	GameState.player_name = nick if nick != "" else "ГЕРОЙ"
	GameState.save_profile()  # ник сохранён — в следующий раз уже введён
	menu_panel.visible = false
	get_tree().paused = false
	SFX.play("click", -2.0)
	SFX.play_music(main.music_track)  # у обучалки — своя тема
	flash("ВЫЖИВИ 10 МИНУТ, %s!" % GameState.player_name, 2.8)

# ---------- ЛОГИКА ----------

func _process(delta: float) -> void:
	if menu_panel.visible:
		_menu_animate(delta)
	if player and is_instance_valid(player) and not GameState.game_over:
		hp_bar.value = 100.0 * player.hp / player.max_hp
		hp_label.text = "%d/%d" % [maxi(0, int(player.hp)), int(player.max_hp)]
		xp_bar.value = 100.0 * float(player.xp) / float(player.xp_next)
		level_label.text = "УР %d" % player.level
		var t := int(GameState.run_time)
		timer_label.text = "%02d:%02d" % [floori(t / 60.0), t % 60]
		timer_label.visible = not (levelup_panel.visible or gameover_panel.visible or win_panel.visible or menu_panel.visible)
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
	# комбо-лесенка (растёт от 4 убийств подряд)
	if GameState.combo >= 4 and not GameState.game_over:
		combo_label.text = "СЕРИЯ ×%d" % GameState.combo
		combo_label.modulate.a = 0.7 + 0.3 * sin(GameState.run_time * 8.0)
	else:
		combo_label.text = ""
	# мини-карта: видна только в бою и если включена в настройках
	var want_mm := GameState.opt_minimap and not menu_panel.visible and not gameover_panel.visible
	if minimap.visible != want_mm:
		minimap.visible = want_mm
	if minimap.visible:
		minimap.queue_redraw()
	# стрелка к боссу, когда он за экраном
	var bb = GameState.current_boss
	if bb and is_instance_valid(bb) and not menu_panel.visible:
		var scr: Vector2 = get_viewport().canvas_transform * bb.global_position
		var on_screen := Rect2(Vector2(24, 24), Vector2(432, 222)).has_point(scr)
		boss_arrow.visible = not on_screen
		if not on_screen:
			var ang := (scr - Vector2(240, 135)).angle()
			boss_arrow.rotation = ang + PI / 2.0  # стрелка нарисована вверх
			var cp := scr.clamp(Vector2(16, 16), Vector2(464, 254))
			boss_arrow.position = cp - boss_arrow.pivot_offset
			boss_arrow.modulate.a = 0.65 + 0.35 * sin(GameState.run_time * 6.0)
	else:
		boss_arrow.visible = false

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
		# каскадное выпархивание карточек сверху с отскоком
		c.modulate.a = 0.0
		var fy: float = c.position.y
		c.position.y = fy - 14
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(c, "modulate:a", 1.0, 0.22).set_delay(0.05 + i * 0.08)
		tw.tween_property(c, "position:y", fy, 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.05 + i * 0.08)
	levelup_panel.visible = true

func _pick(i: int) -> void:
	if not levelup_panel.visible or i >= _pending_upgrades.size():
		return
	levelup_panel.visible = false
	SFX.play("click", -3.0)
	main.on_upgrade_picked(_pending_upgrades[i]["id"])

func show_game_over() -> void:
	# символы из гигапака поверх нашей рубиновой панели
	var txt := AnimLib.sprite("assets/ui/game_over_text", 15.0, true)
	txt.position = Vector2(240, 64)
	txt.scale = Vector2.ONE * 0.7
	gameover_panel.add_child(txt)
	var rank_id: String = GameState.rank()
	var rank := AnimLib.sprite("assets/ui/rank_" + rank_id, 15.0, true)
	rank.position = Vector2(240, 98)
	rank.scale = Vector2.ONE * 0.65
	gameover_panel.add_child(rank)
	var t := int(GameState.run_time)
	# мини-статистика забега с иконками
	_mk_stat_row(gameover_panel, "icon_x", "Убийств: %d · Ур: %d" % [GameState.kills, player.level], 126)
	_mk_stat_row(gameover_panel, "icon_pause", "Время: %02d:%02d" % [floori(t / 60.0), t % 60], 140)
	_mk_stat_row(gameover_panel, "arrow_wood", "Путь: %d м" % int(GameState.dist_traveled / 16.0), 154)
	var fav := "Полумесяц" if GameState.slashes_used > GameState.darts_fired else "Дротики"
	var acc := int(100.0 * GameState.shots_hit / maxf(1.0, float(GameState.darts_fired)))
	_mk_stat_row(gameover_panel, "icon_circle", "%s · Точность %d%%" % [fav, acc], 168)
	var rank_lbl := _mk_label("РАНГ: " + rank_id, Vector2(0, 190), 10, Color(1, 0.85, 0.3), HORIZONTAL_ALIGNMENT_CENTER)
	rank_lbl.size = Vector2(480, 16)
	gameover_panel.add_child(rank_lbl)
	var hint := _mk_label("R — заново", Vector2(0, 208), 10, Color(0.55, 1, 0.55), HORIZONTAL_ALIGNMENT_CENTER)
	hint.size = Vector2(480, 14)
	gameover_panel.add_child(hint)
	gameover_panel.visible = true

## строка статистики: иконка слева + текст (по центру нашей панели)
func _mk_stat_row(panel: Control, icon_name: String, text: String, y: float) -> void:
	var ic := TextureRect.new()
	ic.texture = _tex(icon_name)
	ic.position = Vector2(164, y)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.use_parent_material = false
	if icon_name == "arrow_wood":
		ic.scale = Vector2.ONE * 0.3
		ic.rotation = -PI / 2.0  # стрелка вперёд-вниз = пройденный путь
		ic.pivot_offset = Vector2(8, 26)
	panel.add_child(ic)
	var l := _mk_label(text, Vector2(186, y + 2), 8, Color(0.95, 0.9, 0.9))
	l.size = Vector2(130, 12)
	panel.add_child(l)

func show_win() -> void:
	# наполняем нашу золотую панель победы
	var txt := AnimLib.sprite("assets/ui/complete_text", 15.0, true)
	txt.position = Vector2(240, 76)
	txt.scale = Vector2.ONE * 0.7
	win_panel.add_child(txt)
	var crown := AnimLib.sprite("assets/ui/crown", 15.0, true)
	crown.position = Vector2(240, 108)
	crown.scale = Vector2.ONE * 0.42
	win_panel.add_child(crown)
	var rank_id: String = GameState.rank()
	var rank := AnimLib.sprite("assets/ui/rank_" + rank_id, 15.0, true)
	rank.position = Vector2(240, 142)
	rank.scale = Vector2.ONE * 0.5
	win_panel.add_child(rank)
	var hint := _mk_label("ENTER — продолжить в режиме ва-банк", Vector2(0, 200), 10, Color(0.6, 1, 0.6), HORIZONTAL_ALIGNMENT_CENTER)
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
		elif pause_panel.visible and event.keycode in [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5]:
			_toggle_setting(event.keycode - KEY_1)
		elif levelup_panel.visible and event.keycode in [KEY_1, KEY_2, KEY_3]:
			_pick(event.keycode - KEY_1)
		elif gameover_panel.visible and event.keycode == KEY_R:
			SFX.play("click", -3.0)
			get_tree().paused = false
			get_tree().reload_current_scene()
		elif win_panel.visible and event.keycode == KEY_ENTER:
			SFX.play("click", -3.0)
			win_panel.visible = false
