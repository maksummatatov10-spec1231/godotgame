class_name SFX
extends RefCounted
## Звуковая система v2: ВСЕ эффекты синтезированы кодом специально для игры
## (мягкие, приятные уху, без клипов; 22050 Гц моно). Музыка — файлы, которые
## делает игрок на генераторе; если файла нет — просто тишина, БЕЗ ошибок.
## Громкость эффектов и музыки настраивается в паузе (живёт в профиле).

const POOL_SIZE := 14
const SFX_DIR := "res://assets/sfx/"
const EXT: Array[String] = [".wav", ".ogg", ".mp3"]

static var _pool: Array = []
static var _idx := 0
static var _music: AudioStreamPlayer = null
static var _music_name := ""
static var _variants_cache := {}
# громкость 0..1 (настройки на паузе бегают с шагом 25%); музыка тише эффектов
static var sfx_volume := 0.75
static var music_volume := 0.45
static var music_enabled := true   # авто-выкл, когда громкость музыки = 0

const HEAR_RANGE := 340.0   # дальше этого мировой звук не играем (экономим плееры)
const FULL_RANGE := 70.0

## позиционный звук: дальние события тише, очень дальние — пропускаем
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

# вызывается из Main._ready (и после рестарта): плееры живут на сцене
static func attach(root: Node) -> void:
	for p in _pool:
		if is_instance_valid(p):
			p.queue_free()
	_pool.clear()
	for i in range(POOL_SIZE):
		var pl := AudioStreamPlayer.new()
		pl.name = "Sfx%d" % i
		# ALWAYS: щелчки кнопок слышны и на паузе
		pl.process_mode = Node.PROCESS_MODE_ALWAYS
		root.add_child(pl)
		_pool.append(pl)
	if _music and is_instance_valid(_music):
		_music.queue_free()
	_music = AudioStreamPlayer.new()
	_music.name = "Music"
	_music.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(_music)

## только первый файл по имени (вариантов больше нет — всё синтезировано одиночно)
static func _find(sname: String) -> AudioStream:
	if _variants_cache.has(sname):
		return _variants_cache[sname]
	var stream: AudioStream = null
	for ext in EXT:
		var path := SFX_DIR + sname + ext
		if ResourceLoader.exists(path):
			stream = load(path)
			break
	_variants_cache[sname] = stream
	return stream

static func _db(vol01: float) -> float:
	if vol01 <= 0.001:
		return -80.0
	return linear_to_db(vol01)

## проиграть эффект (vol — сдвиг в dB от автора кода, pitch — вокруг 1.0)
static func play(sname: String, vol := 0.0, pitch := 1.0) -> void:
	if sfx_volume <= 0.001:
		return
	var stream: AudioStream = _find(sname)
	if stream == null or _pool.is_empty():
		return
	var p: AudioStreamPlayer = _pool[_idx]
	_idx = (_idx + 1) % _pool.size()
	p.stream = stream
	p.volume_db = _db(sfx_volume) + vol
	p.pitch_scale = pitch * randf_range(0.94, 1.06)
	p.play()

## музыка: если трека нет — пробуем music_main, иначе тишина (главное — без ошибок!)
static func play_music(sname: String) -> void:
	_music_name = sname
	if not music_enabled or music_volume <= 0.001:
		return
	var stream: AudioStream = _find(sname)
	if stream == null and sname != "music_main":
		stream = _find("music_main")
		_music_name = "music_main"
	if stream == null or _music == null:
		return
	if stream is AudioStreamWAV:
		# бесшовный луп на весь файл
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.mix_rate * stream.get_length())
	elif "loop" in stream:
		stream.loop = true
	_music.stream = stream
	_music.volume_db = _db(music_volume)
	_music.play()

static func music_off() -> void:
	if _music:
		_music.stop()

## громкость из настроек: звук
static func set_sfx_volume(v01: float) -> void:
	sfx_volume = clampf(v01, 0.0, 1.0)

## громкость из настроек: музыка (на 0 глушит, при возврате поднимает трек обратно)
static func set_music_volume(v01: float) -> void:
	music_volume = clampf(v01, 0.0, 1.0)
	music_enabled = music_volume > 0.001
	if not music_enabled:
		music_off()
	else:
		if _music:
			_music.volume_db = _db(music_volume)
		if (_music == null or not _music.playing) and _music_name != "":
			var keep := _music_name
			_music_name = ""
			play_music(keep)

## старые вызовы из кода — оставлены для совместимости
static var enabled := true
static func set_music_enabled(on: bool) -> void:
	music_enabled = on and music_volume > 0.001
	if not music_enabled:
		music_off()
	elif _music_name != "":
		var keep := _music_name
		_music_name = ""
		play_music(keep)

static func set_music_volume_db(_vol_db: float) -> void:
	pass
