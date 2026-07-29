class_name Warmup
extends Node
## ПРЕДЗАГРУЗКА РЕСУРСОВ (антилаг-система v0.15).
## Раньше PNG-кадры анимаций, звуки и иконки грузились ЛЕНИВО — прямо в кадре
## первого события (спавн босса, первый вампир, первая нова, первый сундук) —
## каждый такой кадр давал заметный фриз: диск + декод PNG + заливка в видеокарту.
## Теперь всё греется ЗАРАНЕЕ, пока игрок сидит в меню: этот узел работает
## даже на паузе и загружает очередь мелкими порциями с бюджетом времени
## на кадр (~3.5 мс), поэтому меню не дёргается, а игра потом НИ РАЗУ не ждёт диск.
## Если игрок нажал ИГРАТЬ мгновенно — догреваем в игре теми же крошечными порциями.

const FRAME_BUDGET_USEC := 3500   # бюджет прогрева на кадр — шелк, а не рывки

var _queue: Array = []   # {dir,fps,loop} | {sfx} | {tex}
var _i := 0

static func attach(root: Node) -> void:
	var w := Warmup.new()
	w.name = "Warmup"
	root.add_child(w)
	w._begin()

func _begin() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # греем даже на паузе (меню!)
	_build_queue()

# ---------- ОЧЕРЕДЬ ПРОГРЕВА (важное для ранней игры — первым!) ----------

func _build_queue() -> void:
	# 1) ЗВУКИ — самые частые события (первый выстрел, монетка, удар)
	for f in DirAccess.get_files_at("res://assets/sfx"):
		if f.ends_with(".wav") or f.ends_with(".ogg") or f.ends_with(".mp3"):
			_queue.append({"sfx": f.get_basename()})
	# музыкальные слоты тоже решаем заранее: "файл есть/нет" запоминается в кэше,
	# и при спавне босса не будет лишних тычков в дисковую систему
	for m in ["music_main", "music_boss", "music_win", "music_menu", "music_tuto"]:
		_queue.append({"sfx": m})
	# 2) стартовый бой: дротики, полумесяцы, снаряды боссов
	for col in Data.DART_COLORS:
		_queue.append({"dir": "assets/bullets/dart/" + col, "fps": 12.0, "loop": true})
	for col2 in Data.SLASH_COLORS:
		_queue.append({"dir": "assets/bullets/slash/" + col2, "fps": 15.0, "loop": false})
	for pid in Data.PROJECTILES:
		var pcfg: Dictionary = Data.PROJECTILES[pid]
		if pcfg.has("dir"):
			_queue.append({"dir": String(pcfg["dir"]), "fps": float(pcfg["fps"]), "loop": true})
	# вражеские снаряды-картинки из расписаний (пак боссов игрока)
	# 3) все враги и боссы — из data.gd (новые типы подхватываются автоматически)
	for src in [Data.ENEMIES, Data.BOSSES]:
		for tname in src:
			var cfg: Dictionary = src[tname]
			var dir_path: String = String(cfg["dir"])
			for anim_key in ["move_anim", "attack_anim", "death_anim", "hurt_anim"]:
				if cfg.has(anim_key):
					var a: Array = cfg[anim_key]
					_queue.append({"dir": dir_path + "/" + String(a[0]), "fps": float(a[1]),
							"loop": anim_key == "move_anim"})
	# демон во второй фазе меняет кадры на attack2 — греем явно
	_queue.append({"dir": String(Data.BOSSES["demon"]["dir"]) + "/attack2", "fps": 12.0, "loop": false})
	# 4) эффекты: ТОЧНО те пары (папка, fps), что зовутся из кода —
	# ключ кэша AnimLib содержит fps, греть "примерно" бесполезно
	var fx_dirs: Array = [
		["assets/effects/impact_yellow", 18.0], ["assets/effects/impact_blue", 18.0],
		["assets/effects/splatter_red", 16.0], ["assets/effects/splatter_green", 16.0],
		["assets/effects/explosion_orange", 15.0], ["assets/effects/explosion_violet", 15.0],
		["assets/effects/heal_red", 15.0], ["assets/effects/sparkle_burst", 16.0],
		["assets/effects/skull_smoke", 14.0], ["assets/effects/skull_smoke", 16.0],
		["assets/effects/coin_burst", 18.0], ["assets/effects/heart_burst", 16.0],
		["assets/effects/smoke_burst", 15.0], ["assets/bullets/cast", 12.0],
		["assets/bullets/cast", 14.0], ["assets/effects/fire_ring", 30.0],
		["assets/bullets/fire_explosion/red", 18.0], ["assets/bullets/fire_explosion/red", 22.0],
		["assets/ui/level_up", 15.0], ["assets/ui/crown", 15.0],
	]
	for fd in fx_dirs:
		_queue.append({"dir": String(fd[0]), "fps": float(fd[1]), "loop": false})
	# 5) предметы и лут
	var items_loop: Array = [
		["assets/items/coin", 8.0], ["assets/items/flask_blue", 8.0],
		["assets/items/flask_green", 8.0], ["assets/items/flask_red", 8.0],
		["assets/items/flask_yellow", 8.0], ["assets/items/key_silver", 8.0],
		["assets/items/key_gold", 8.0], ["assets/items/chest", 6.0],
		["assets/items/mini_chest", 6.0], ["assets/items/mini_chest", 5.0],
		["assets/items/box1", 5.0], ["assets/items/box2", 5.0],
		["assets/items/spikes", 4.0], ["assets/items/torch", 6.0],
		["assets/items/torch_side", 6.0], ["assets/items/candle1", 6.0],
		["assets/items/candle2", 6.0], ["assets/items/flag", 6.0],
	]
	for it in items_loop:
		_queue.append({"dir": String(it[0]), "fps": float(it[1]), "loop": true})
	_queue.append({"dir": "assets/items/chest_open", "fps": 10.0, "loop": false})
	_queue.append({"dir": "assets/items/mini_chest_open", "fps": 10.0, "loop": false})
	# 6) финальные экраны (смерть/победа/ранги) — чтобы и там без единого рывка
	var ui_dirs: Array = ["assets/ui/game_over_text", "assets/ui/complete_text",
			"assets/ui/rank_S", "assets/ui/rank_A", "assets/ui/rank_B",
			"assets/ui/rank_C", "assets/ui/rank_D", "assets/ui/rank_F"]
	for ud in ui_dirs:
		_queue.append({"dir": ud, "fps": 15.0, "loop": true})
	_queue.append({"dir": "assets/ui/crown", "fps": 15.0, "loop": true})
	# 7) иконки карточек усилений — первый левел-ап без лагов
	for u in Data.UPGRADES:
		_queue.append({"tex": String(u["icon"])})
	_queue.append({"tex": "res://assets/fx/light_warm.png"})
	_queue.append({"tex": "res://assets/ui/fantasy/arrow_wood.png"})

# ---------- ВЫПОЛНЕНИЕ (маленькие порции, бюджет на кадр) ----------

func _process(_delta: float) -> void:
	if _i >= _queue.size():
		queue_free()
		return
	var stop_at := Time.get_ticks_usec() + FRAME_BUDGET_USEC
	while _i < _queue.size():
		var item: Dictionary = _queue[_i]
		_i += 1
		if item.has("dir"):
			# строим и кладём в кэш AnimatedSprite-кадры (диск+декод — здесь, не в бою!)
			AnimLib.frames(String(item["dir"]), float(item["fps"]), bool(item["loop"]))
		elif item.has("sfx"):
			# прогрев звука: чтение файла + декод + запоминание "пусто/есть" для музыки
			SFX._find(String(item["sfx"]))
		else:
			load(String(item["tex"]))   # попадает в кэш ResourceLoader
		if Time.get_ticks_usec() >= stop_at:
			break
