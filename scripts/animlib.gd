class_name AnimLib
extends RefCounted
## Загружает анимации из папок с кадрами (000.png, 001.png, ... / frame0000.png)
## и кеширует SpriteFrames, чтобы не пересоздавать их для каждого врага.

static var _cache := {}

static func frames(dir_path: String, fps: float = 8.0, loop: bool = true) -> SpriteFrames:
	var key := "%s|%0.2f|%s" % [dir_path, fps, str(loop)]
	if _cache.has(key):
		return _cache[key]
	var sf := SpriteFrames.new()
	if not sf.has_animation("default"):
		sf.add_animation("default")
	sf.set_animation_speed("default", fps)
	sf.set_animation_loop("default", loop)
	var files: Array = []
	for f in DirAccess.get_files_at("res://" + dir_path):
		if f.ends_with(".png"):
			files.append(f)
	files.sort()
	for f in files:
		var tex: Texture2D = load("res://%s/%s" % [dir_path, f])
		if tex:
			sf.add_frame("default", tex)
	_cache[key] = sf
	return sf

static func sprite(dir_path: String, fps: float = 8.0, loop: bool = true) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.sprite_frames = frames(dir_path, fps, loop)
	s.play("default")
	return s

static func frame_count(dir_path: String) -> int:
	var n := 0
	for f in DirAccess.get_files_at("res://" + dir_path):
		if f.ends_with(".png"):
			n += 1
	return n
