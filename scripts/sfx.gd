class_name SFX
extends RefCounted
## Звуковая система v3.2: ВСЕ эффекты — студийный ремастер (numpy/scipy синтез:
## фильтры Баттерворта, FM-колокола, бесклиповые огибающие, реверб-хвосты, точный
## ноль DC; 44100 Гц моно PCM16). Музыка — файлы игрока.
## ЗАГРУЗКА БЕЗ ИМПОРТА: файлы читаются напрямую байтами (FileAccess), поэтому
## треки можно бросать в assets/sfx когда угодно — даже посреди забега, Godot
## НЕ требует импорта и ошибок не печатает в принципе (битый/чужой формат —
## просто молчим). Громкость эффектов и музыки настраивается в паузе.

const POOL_SIZE := 14
const SFX_DIR := "res://assets/sfx/"
const EXT: Array[String] = [".wav", ".ogg", ".mp3"]

static var _pool: Array = []
static var _idx := 0
static var _music: AudioStreamPlayer = null
static var _music_name := ""
static var _variants_cache := {}
static var _retry_at := {}         # когда можно перепроверить "отсутствующий" файл
const RETRY_MISSING_MS := 1500     # докинутый в папку трек подхватится за ~1.5 сек
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

## найти/собрать поток по имени. Формат определяем по СОДЕРЖИМОМУ байтов,
## а НЕ по расширению: переименованные .mp3/.wav/.ogg играют как ни в чём не бывало.
## MP4/AAC и прочие чужие форматы — молча null (в движке нет AAC-декодера, такие
## файлы надо КОНВЕРТИРОВАТЬ в wav/ogg/mp3 — переименование не считается :)
static func _find(sname: String) -> AudioStream:
	if _variants_cache.has(sname):
		var got: AudioStream = _variants_cache[sname]
		if got != null:
			return got
		# файла не было — перепроверяем не чаще раза в 1.5 сек (а вдруг докинули?)
		if int(_retry_at.get(sname, 0)) > Time.get_ticks_msec():
			return null
		_retry_at[sname] = Time.get_ticks_msec() + RETRY_MISSING_MS
	var stream: AudioStream = null
	for ext in EXT:
		var path := SFX_DIR + sname + ext
		if not FileAccess.file_exists(path):
			continue
		stream = _load_any(path)
		if stream != null:
			break
	_variants_cache[sname] = stream
	return stream

## медиа-детектив: смотрим первые байты и грузим по РЕАЛЬНОМУ формату
static func _load_any(path: String) -> AudioStream:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() < 8:
		return null
	if bytes[0] == 0x52 and bytes[1] == 0x49 and bytes[2] == 0x46 and bytes[3] == 0x46:
		return _parse_wav_bytes(bytes)                                     # "RIFF" = WAV
	if bytes[0] == 0x4F and bytes[1] == 0x67 and bytes[2] == 0x67 and bytes[3] == 0x53:
		return AudioStreamOggVorbis.load_from_buffer(bytes)                # "OggS" = OGG
	var is_id3 := bytes[0] == 0x49 and bytes[1] == 0x44 and bytes[2] == 0x33     # "ID3"
	var is_sync := bytes[0] == 0xFF and (bytes[1] & 0xE0) == 0xE0                # mp3-кадр
	if is_id3 or is_sync:
		var m := AudioStreamMP3.new()
		m.data = bytes
		if m.get_length() > 0.01:
			return m                                                       # MP3
	# "...ftyp" = MP4-контейнер (AAC внутри — движок его не играет), всё прочее — unknown
	return null

## WAV собираем вручную по байтам RIFF: читаем fmt/data-чанки сами,
## полностью независимо от импортёра движка. Только PCM 8/16 бит (наши такие).
static func _parse_wav_bytes(bytes: PackedByteArray) -> AudioStreamWAV:
	if bytes.size() < 44:
		return null
	if bytes[8] != 0x57 or bytes[9] != 0x41 or bytes[10] != 0x56 or bytes[11] != 0x45:
		return null   # нет "WAVE"
	var pos := 12
	var audio_format := 0
	var channels := 0
	var rate := 0
	var bits := 0
	var data_start := -1
	var data_size := 0
	while pos + 8 <= bytes.size():
		var cid := bytes.slice(pos, pos + 4).get_string_from_ascii()
		var csize := bytes.decode_s32(pos + 4)
		if csize < 0:
			return null
		if cid == "fmt ":
			audio_format = bytes.decode_u16(pos + 8)
			channels = bytes.decode_u16(pos + 10)
			rate = bytes.decode_u32(pos + 12)
			bits = bytes.decode_u16(pos + 22)
		elif cid == "data":
			data_start = pos + 8
			data_size = mini(csize, bytes.size() - data_start)
			break
		pos += 8 + csize + (csize & 1)   # чанки выровнены по 2 байта
	if audio_format != 1 or data_start < 0 or data_size <= 0 or (bits != 8 and bits != 16) \
			or rate <= 0 or channels <= 0:
		return null   # не обычный PCM (float/adpcm) или битый заголовок — молча пропускаем
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS if bits == 16 else AudioStreamWAV.FORMAT_8_BITS
	w.stereo = channels > 1
	w.mix_rate = rate
	w.data = bytes.slice(data_start, data_start + data_size)
	if w.get_length() <= 0.0:
		return null
	return w

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
