class_name SFX
extends RefCounted
## Звуковая система: пул плееров для эффектов + один плеер музыки.
## Файлы: assets/sfx/*.wav|*.mp3|*.ogg
## Вариации: shoot.wav, shoot_2.wav, shoot_3.wav… — игра сама крутит их вперемешку.
## Громкость каждого звука выверена по RMS в таблице LEVELS (тише/громче как просил).

const POOL_SIZE := 12
const SFX_DIR := "res://assets/sfx/"
const EXT: Array[String] = [".wav", ".mp3", ".ogg"]
const SUFFIXES: Array[String] = ["", "_2", "_3", "_4", "_5"]  # варианты одного звука

# базовая громкость (dB) — подобрана по измеренной громкости файлов:
# частые звуки тише, редкие и важные — заметнее.
# Ключ — имя звука ИЛИ конкретного файла-варианта (вариант важнее базы):
# "spawn": -14 действует на spawn/spawn_2, а "spawn_3": 24 — только на третий файл.
const LEVELS := {
	"shoot": -7.0,        # лазерные выстрелы громкие — придержать
	"slash": 10.0,        # мечи записаны тихо — поднять
	"hit": -3.0,
	"enemy_die": 7.0,
	"elite_die": 5.0,
	"player_hurt": 9.0,
	"player_die": 11.0,
	"player_die_2": 14.0, # смерть-призрак (Hel Circle) тише записью
	"coin": -8.0,         # монеты звенят часто
	"coin_5": -1.0,       # монета JDSherbert записана тише остальных
	"gem": -8.0,
	"flask": -13.0,       # Can_Open очень громкий
	"resurrect": 10.0,    # большой жёлтый флакон — хор воскрешения
	"key": -8.0,
	"chest": 16.0,        # сундуки записаны очень тихо
	"crate": 16.0,
	"crate_3": -8.0,      # Box Break громкий — придержать
	"levelup": -2.0,
	"boss": -4.0,
	"boss_die": -2.0,
	"gameover": -4.0,
	"win": -4.0,
	"click": -10.0,
	"click_3": -6.0,      # переключатель чуть громче блипов
	"spike": -4.0,
	"door": -2.0,
	"door_3": 24.0,       # скрип двери (Hel Circle) записан почти неслышно
	"doorbreak": 22.0,    # враг выломал дверь — крошка дерева
	"spawn": -14.0,       # телепорт громкий + спавнится много врагов
	"spawn_3": 24.0,      # мистический телепорт элиток очень тихий
	"spawn_4": -9.0,
	"spawn_5": -2.0,
	"step": 24.0,         # шаги почти неслышны в записи
	"step_4": 24.0,
	"vampire_shot": -12.0,
	"comet_hit": -6.0,
	"dash": 6.0,          # рывок — записан тихо, усилен при сборке
	"crit": -10.0,        # крит — короткий яркий звон
	"scream": 8.0,        # рык элитки при появлении (орк Minifantasy)
	"ricochet": -5.0,     # звон отскока дротика от стены
	"jump": -7.0,         # подпрыжка черепа
}
const MUSIC_DB := -14.0
# подстройка каждого трека относительно MUSIC_DB (по измеренной громкости,
# чтобы все треки звучали одинаково приятно)
const MUSIC_LEVELS := {
	"music_main": 0.0,    # haunted — эталон
	"music_menu": 2.0,    # mystery чуть тише записи — поднять
	"music_boss": 5.0,    # eglise_orgue — орган записан тише
	"music_tuto": 5.0,    # cave_tuto
	"music_win": 7.0,     # jardins самый тихий
}

static var _pool: Array = []
static var _idx := 0
static var _music: AudioStreamPlayer = null
static var _music_name := ""     # какой трек сейчас должен играть (для вкл/выкл)
static var _variants_cache := {}
static var enabled := true       # звуковые эффекты (переключатель в настройках)
static var music_enabled := true # музыка (переключатель в настройках)

const HEAR_RANGE := 340.0   # дальше этого — мировой звук не играем вовсе
const FULL_RANGE := 70.0    # до этого расстояния — звук на полной громкости

## позиционный звук: громкость падает с расстоянием до героя,
## дальние события не озвучиваются (чтобы мир жил объёмно, а не гудел)
static func play_at(sname: String, pos: Vector2, vol := 0.0, pitch := 1.0) -> void:
	var pl := GameState.player
	if pl == null or not is_instance_valid(pl):
		return
	var d: float = pos.distance_to(pl.global_position)
	if d > HEAR_RANGE:
		return
	var fade := 0.0
	if d > FULL_RANGE:
		fade = -clampf((d - FULL_RANGE) * 0.075, 0.0, 18.0)
	play(sname, vol + fade, pitch)

# вызывается из Main._ready (и после рестарта — пересоздаёт плееры на новой сцене)
static func attach(root: Node) -> void:
	for p in _pool:
		if is_instance_valid(p):
			p.queue_free()
	_pool.clear()
	for i in range(POOL_SIZE):
		var pl := AudioStreamPlayer.new()
		pl.name = "Sfx%d" % i
		# ALWAYS: щелчки кнопок слышны и на паузе (меню/выбор силы/конец игры)
		pl.process_mode = Node.PROCESS_MODE_ALWAYS
		root.add_child(pl)
		_pool.append(pl)
	if _music and is_instance_valid(_music):
		_music.queue_free()
	_music = AudioStreamPlayer.new()
	_music.name = "Music"
	# ALWAYS: музыка главного меню играет, пока игра на паузе
	_music.process_mode = Node.PROCESS_MODE_ALWAYS
	_music.volume_db = MUSIC_DB
	root.add_child(_music)

## варианты звука: список пар [имя_файла, поток]
static func _variants(sname: String) -> Array:
	if _variants_cache.has(sname):
		return _variants_cache[sname]
	var list: Array = []
	for suffix in SUFFIXES:
		for ext in EXT:
			var path := SFX_DIR + sname + suffix + ext
			if ResourceLoader.exists(path):
				list.append([sname + suffix, load(path)])
				break
	_variants_cache[sname] = list
	return list

## проиграть эффект: громкость = LEVELS[вариант или звук] + vol, вариация — случайная
static func play(sname: String, vol := 0.0, pitch := 1.0) -> void:
	if not enabled:
		return
	var list: Array = _variants(sname)
	if list.is_empty() or _pool.is_empty():
		push_warning("SFX: нет файлов для '%s'" % sname)
		return
	var p: AudioStreamPlayer = _pool[_idx]
	_idx = (_idx + 1) % _pool.size()
	var entry: Array = list[randi() % list.size()]
	p.stream = entry[1]
	p.volume_db = float(LEVELS.get(entry[0], LEVELS.get(sname, 0.0))) + vol
	p.pitch_scale = pitch * randf_range(0.94, 1.06)
	p.play()

static func play_music(sname: String) -> void:
	_music_name = sname
	if not music_enabled:
		return
	var list: Array = _variants(sname)
	if list.is_empty() or _music == null:
		return
	var stream: AudioStream = list[0][1]
	if stream is AudioStreamWAV:
		# бесшовный луп: от начала до конца файла
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		# до конца файла (через длительность — независимо от битности wav)
		stream.loop_end = int(stream.mix_rate * stream.get_length())
	elif "loop" in stream:
		stream.loop = true
	_music.stream = stream
	_music.volume_db = MUSIC_DB + float(MUSIC_LEVELS.get(sname, 0.0))
	_music.play()

static func music_off() -> void:
	if _music:
		_music.stop()

## переключатель музыки из настроек (пауза): мгновенно глушит или возвращает трек
static func set_music_enabled(on: bool) -> void:
	music_enabled = on
	if not on:
		music_off()
	elif _music_name != "":
		var keep := _music_name
		_music_name = ""    # хитрость: play_music сам запишет имя заново
		play_music(keep)

static func set_music_volume(vol_db: float) -> void:
	if _music:
		_music.volume_db = vol_db
