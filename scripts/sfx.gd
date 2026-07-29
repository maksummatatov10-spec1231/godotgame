class_name SFX
extends RefCounted
## ЗВУК ПОЛНОСТЬЮ ВЫРЕЗАН из игры по просьбе игрока (тишина вместо какофонии).
## Класс оставлен заглушкой: все методы ничего не делают, зато не нужно
## трогать сотню вызовов по всем скриптам и ничего не может сломаться.
## Хочешь вернуть звук — скажи, оживим одной правкой.

static var enabled := false        # переключателей больше нет, звука нет вообще
static var music_enabled := false

static func attach(_root: Node) -> void:
	pass

static func play(_sname: String, _vol := 0.0, _pitch := 1.0) -> void:
	pass

static func play_at(_sname: String, _pos: Vector2, _vol := 0.0, _pitch := 1.0) -> void:
	pass

static func play_music(_sname: String) -> void:
	pass

static func music_off() -> void:
	pass

static func set_music_enabled(_on: bool) -> void:
	pass

static func set_music_volume(_vol_db: float) -> void:
	pass
