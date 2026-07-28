class_name SFX
extends RefCounted
## Звуковая система: пул плееров для эффектов + один плеер музыки.
## Файлы: assets/sfx/*.wav|*.mp3|*.ogg
## Вариации: shoot.wav, shoot_2.wav, shoot_3.wav… — игра сама крутит их вперемешку.
## Громкость каждого звука выверена по RMS в таблице LEVELS (тише/громче как просил).

const POOL_SIZE := 12
const SFX_DIR := "res://assets/sfx/"
const EXT := [".wav", ".mp3", ".ogg"]

# базовая громкость (dB) — подобрана по измеренной громкости файлов:
# частые звуки тише, редкие и важные — заметнее.
const LEVELS := {
	"shoot": -7.0,        # лазерные выстрелы громкие — придержать
	"slash": 10.0,        # мечи записаны тихо — поднять
	"hit": -3.0,
	"enemy_die": 7.0,
	"elite_die": 5.0,
	"player_hurt": 9.0,
	"player_die": 11.0,
	"coin": -8.0,         # монеты звенят часто
	"gem": -8.0,
	"flask": -13.0,       # Can_Open очень громкий
	"key": -8.0,
	"chest": 16.0,        # сундуки записаны очень тихо
	"crate": 16.0,
	"levelup": -2.0,
	"boss": -4.0,
	"boss_die": -2.0,
	"gameover": -4.0,
	"win": -4.0,
	"click": -10.0,
	"spike": -4.0,
	"door": -2.0,
	"spawn": -14.0,       # телепорт громкий + спавнится много врагов
	"step": 24.0,         # шаги почти неслышны в записи
	"vampire_shot": -12.0,
	"comet_hit": -6.0,
}
const MUSIC_DB := -14.0

static var _pool: Array = []
static var _idx := 0
static var _music: AudioStreamPlayer = null
static var _variants_cache := {}
static var enabled := true

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

static func _variants(sname: String) -> Array:
	if _variants_cache.has(sname):
		return _variants_cache[sname]
	var list: Array = []
	for suffix in ["", "_2", "_3", "_4", "_5"]:
		for ext in EXT:
			var path := SFX_DIR + sname + suffix + ext
			if ResourceLoader.exists(path):
				list.append(load(path))
				break
	_variants_cache[sname] = list
	return list

## проиграть эффект: громкость = LEVELS[звук] + vol, вариация — случайная
static func play(sname: String, vol := 0.0, pitch := 1.0) -> void:
	if not enabled:
		return
	var list: Array = _variants(sname)
	if list.is_empty() or _pool.is_empty():
		push_warning("SFX: нет файлов для '%s'" % sname)
		return
	var p: AudioStreamPlayer = _pool[_idx]
	_idx = (_idx + 1) % _pool.size()
	p.stream = list[randi() % list.size()]
	p.volume_db = float(LEVELS.get(sname, 0.0)) + vol
	p.pitch_scale = pitch * randf_range(0.94, 1.06)
	p.play()

static func play_music(sname: String) -> void:
	var list: Array = _variants(sname)
	if list.is_empty() or _music == null:
		return
	var stream: AudioStream = list[0]
	if stream is AudioStreamWAV:
		# бесшовный луп: от начала до конца файла
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		# до конца файла (через длительность — независимо от битности wav)
		stream.loop_end = int(stream.mix_rate * stream.get_length())
	elif "loop" in stream:
		stream.loop = true
	_music.stream = stream
	_music.volume_db = MUSIC_DB
	_music.play()

static func music_off() -> void:
	if _music:
		_music.stop()

static func set_music_volume(vol_db: float) -> void:
	if _music:
		_music.volume_db = vol_db
