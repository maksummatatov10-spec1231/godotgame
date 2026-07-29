class_name Data
extends RefCounted
## Баланс и конфигурация игры.

# ---------- ВРАГИ ----------
# dir — папка с анимациями; no_move_anim — мобы с одной анимацией idle
const ENEMIES := {
	"skeleton1": {
		"dir": "assets/enemies/skeleton1", "speed": 40.0, "hp": 16, "dmg": 8,
		"xp": 1, "attack_range": 15.0, "attack_cd": 1.2, "radius": 9.0,
		"move_anim": ["move", 10.0], "attack_anim": ["attack", 12.0],
		"death_anim": ["death", 14.0], "hurt_anim": ["hurt", 14.0],
		"death_fx": "assets/effects/splatter_red", "coin_chance": 0.40,
	},
	"goblin": {
		"dir": "assets/enemies/goblin", "speed": 62.0, "hp": 10, "dmg": 6,
		"xp": 1, "attack_range": 12.0, "attack_cd": 0.8, "radius": 8.0,
		"move_anim": ["idle", 6.0], "no_attack_anim": true,
		"death_fx": "assets/effects/splatter_green", "coin_chance": 0.32,
	},
	"skull": {
		"dir": "assets/enemies/skull", "speed": 82.0, "hp": 8, "dmg": 5,
		"xp": 1, "attack_range": 11.0, "attack_cd": 0.7, "radius": 8.0,
		"move_anim": ["idle", 9.0], "no_attack_anim": true, "wobble": true,
		"death_fx": "assets/effects/splatter_red", "coin_chance": 0.30,
	},
	"skeleton2": {
		"dir": "assets/enemies/skeleton2", "speed": 34.0, "hp": 34, "dmg": 12,
		"xp": 2, "attack_range": 16.0, "attack_cd": 1.5, "radius": 10.0,
		"move_anim": ["move", 10.0], "attack_anim": ["attack", 13.0],
		"death_anim": ["death", 15.0], "hurt_anim": ["hurt", 14.0],
		"death_fx": "assets/effects/splatter_red", "coin_chance": 0.55,
	},
	"vampire": {
		"dir": "assets/enemies/vampire", "speed": 44.0, "hp": 46, "dmg": 10,
		"xp": 3, "attack_range": 15.0, "attack_cd": 1.4, "radius": 10.0,
		"move_anim": ["move", 10.0], "attack_anim": ["attack", 12.0],
		"death_anim": ["death", 13.0], "hurt_anim": ["hurt", 14.0],
		"death_fx": "assets/effects/skull_smoke", "coin_chance": 0.70,
		"ranged": true,
	},
	# тёмный разбойник: быстрый и наглый (у него ещё и воровская версия!)
	"dark_rogue": {
		"dir": "assets/enemies/dark_rogue", "speed": 78.0, "hp": 14, "dmg": 9,
		"xp": 2, "attack_range": 12.0, "attack_cd": 0.7, "radius": 8.0,
		"move_anim": ["idle", 8.0], "no_attack_anim": true,
		"death_fx": "assets/effects/splatter_red", "coin_chance": 0.45,
	},
	# щит-рыцарь: медленная серебряная громадина (спрайт knight из Penzilla)
	"shieldknight": {
		"dir": "assets/player/knight", "speed": 21.0, "hp": 95, "dmg": 14,
		"xp": 5, "attack_range": 17.0, "attack_cd": 1.6, "radius": 12.0,
		"move_anim": ["idle", 5.0], "no_attack_anim": true,
		"death_fx": "assets/effects/splatter_red", "coin_chance": 0.9,
	},
	# некромант: воскрешает павших врагов (спрайт sage из Penzilla)
	"necromancer": {
		"dir": "assets/player/sage", "speed": 28.0, "hp": 40, "dmg": 8,
		"xp": 6, "attack_range": 14.0, "attack_cd": 1.5, "radius": 10.0,
		"move_anim": ["idle", 6.0], "no_attack_anim": true,
		"death_fx": "assets/effects/skull_smoke", "coin_chance": 0.8,
	},
}

# ---------- БОССЫ ----------
const BOSSES := {
	"demon": {
		"dir": "assets/bosses/demon", "speed": 30.0, "hp": 380, "dmg": 16,
		"xp": 30, "attack_range": 24.0, "attack_cd": 1.6, "radius": 20.0,
		"scale": 1.6, "boss": true, "title": "ДЕМОН",
		"move_anim": ["walk", 9.0], "attack_anim": ["attack", 11.0],
		"death_anim": ["death", 7.0], "hurt_anim": ["hurt", 10.0],
		"death_fx": "assets/effects/explosion_orange",
		"volley": {"projectile": "comet_red", "count": 3, "cd": 3.6, "range": 250.0},
	},
	"blood": {
		"dir": "assets/bosses/blood", "speed": 40.0, "hp": 560, "dmg": 20,
		"xp": 45, "attack_range": 24.0, "attack_cd": 1.3, "radius": 20.0,
		"scale": 1.7, "boss": true, "title": "КРОВАВАЯ ТВАРЬ",
		"move_anim": ["walk", 10.0], "attack_anim": ["attack", 11.0],
		"death_anim": ["death", 7.0], "hurt_anim": ["hurt", 10.0],
		"death_fx": "assets/effects/explosion_violet",
		"lunge": {"cd": 4.0, "speed_mult": 4.5, "time": 0.30},
	},
	# --- НОВЫЕ БОССЫ (паки игрока: Goblin Captain + CraftPix Bosses) ---
	# капитан гоблинов: тяжёлый щитоносец, яростный рывок-таран (gif-пак, полная анимация)
	"goblin_captain": {
		"dir": "assets/bosses/goblin_captain", "speed": 36.0, "hp": 650, "dmg": 22,
		"xp": 60, "attack_range": 20.0, "attack_cd": 1.4, "radius": 16.0,
		"scale": 1.5, "boss": true, "title": "КАПИТАН ГОБЛИНОВ",
		"move_anim": ["run", 8.0], "attack_anim": ["charge", 3.0],
		"death_fx": "assets/effects/explosion_violet",
		"lunge": {"cd": 3.4, "speed_mult": 4.8, "time": 0.35},
	},
	# командир (CraftPix boss 3): пулковый снайпер — стреляет мячиками веером
	"komandir": {
		"dir": "assets/bosses/komandir", "speed": 40.0, "hp": 820, "dmg": 24,
		"xp": 75, "attack_range": 20.0, "attack_cd": 1.3, "radius": 14.0,
		"scale": 1.15, "boss": true, "title": "КОМАНДИР",
		"move_anim": ["walk", 10.0], "attack_anim": ["attack", 12.0],
		"death_anim": ["death", 8.0], "hurt_anim": ["hurt", 10.0],
		"death_fx": "assets/effects/explosion_orange",
		"volley": {"projectile": "puck", "count": 3, "cd": 2.8, "range": 240.0},
	},
	# выбивала (CraftPix boss 1, пеший): быстрый дубинщик, иногда запускает мяч
	"vybivala": {
		"dir": "assets/bosses/vybivala", "speed": 58.0, "hp": 980, "dmg": 26,
		"xp": 85, "attack_range": 21.0, "attack_cd": 1.0, "radius": 14.0,
		"scale": 1.2, "boss": true, "title": "ВЫБИВАЛА",
		"move_anim": ["walk", 12.0], "attack_anim": ["attack", 12.0],
		"death_anim": ["death", 8.0], "hurt_anim": ["hurt", 10.0],
		"death_fx": "assets/effects/explosion_orange",
		"volley": {"projectile": "puck", "count": 1, "cd": 3.6, "range": 220.0},
	},
	# стальная батарея (CraftPix boss 2): ФИНАЛЬНЫЙ — ракетный залп из 5 снарядов
	"battery": {
		"dir": "assets/bosses/battery", "speed": 26.0, "hp": 1400, "dmg": 28,
		"xp": 110, "attack_range": 26.0, "attack_cd": 1.7, "radius": 22.0,
		"scale": 1.15, "boss": true, "title": "СТАЛЬНАЯ БАТАРЕЯ",
		"move_anim": ["walk", 10.0], "attack_anim": ["attack", 14.0],
		"death_anim": ["death", 8.0], "hurt_anim": ["hurt", 10.0],
		"death_fx": "assets/effects/explosion_orange",
		"volley": {"projectile": "rocket", "count": 5, "cd": 3.0, "range": 270.0},
	},
}

# ---------- СНАРЯДЫ ----------
const PROJECTILES := {
	# дротик игрока — 8 цветов = уровни прокачки урона
	"dart": {"fps": 12.0, "face_left": true, "life": 1.7, "hit_fx": "assets/effects/impact_yellow", "hit_fx_scale": 0.24},
	"slash": {"fps": 14.0, "face_left": false, "life": 0.32, "hit_fx": ""},
	# вражеские
	"orb_violet": {"dir": "assets/bullets/orb/violet", "fps": 12.0, "face_left": false, "life": 3.0, "speed": 95.0, "hit_fx": "assets/effects/impact_blue", "hit_fx_scale": 0.22},
	"comet_red": {"dir": "assets/bullets/comet/red", "fps": 10.0, "face_left": false, "life": 3.4, "speed": 105.0, "hit_fx": "assets/bullets/fire_explosion/red", "hit_fx_scale": 1.0},
	# мяч командира/выбивалы и ракета стальной батареи (из пака боссов)
	"puck": {"dir": "assets/bullets/puck", "fps": 6.0, "face_left": false, "life": 3.2, "speed": 115.0, "hit_fx": "assets/effects/impact_yellow", "hit_fx_scale": 0.3},
	"rocket": {"dir": "assets/bullets/rocket", "fps": 8.0, "face_left": false, "life": 3.6, "speed": 130.0, "hit_fx": "assets/effects/explosion_orange", "hit_fx_scale": 0.6},
}

# цвета дротика по уровню урона (все 8 листов пака!)
const DART_COLORS := ["gold", "amber", "orange", "green", "blue", "violet", "magenta", "red"]
const SLASH_COLORS := ["gold", "amber", "orange", "green", "blue", "violet", "magenta", "red"]

# ---------- УЛУЧШЕНИЯ НА УРОВЕНЬ (усилены в 1.5 раза по просьбе игрока) ----------
const UPGRADES := [
	{"id": "dart_rate", "name": "Пылающие руны", "desc": "Темп стрельбы +37%", "icon": "assets/bullets/dart/gold/000.png", "max": 6},
	{"id": "dart_dmg", "name": "Горячие стрелы", "desc": "Урон дротиков +45%", "icon": "assets/bullets/dart/amber/000.png", "max": 7},
	{"id": "dart_count", "name": "Веер дротиков", "desc": "+1 дротик за выстрел", "icon": "assets/bullets/dart/blue/000.png", "max": 4},
	{"id": "slash", "name": "Огненный полумесяц", "desc": "Урон +60%, дуга шире", "icon": "assets/bullets/slash/gold/001.png", "max": 7},
	{"id": "boots", "name": "Сапоги ветра", "desc": "Скорость бега +18%", "icon": "assets/items/flask_blue/000.png", "max": 5},
	{"id": "heart", "name": "Сердце титана", "desc": "Макс. HP +38 · лечит", "icon": "assets/items/flask_red/000.png", "max": 7},
	{"id": "magnet", "name": "Магнит душ", "desc": "Радиус сбора +68%", "icon": "assets/items/coin/001.png", "max": 5},
	{"id": "regen", "name": "Тихое пламя", "desc": "Регенерация +0.9/сек", "icon": "assets/effects/heal_red/004.png", "max": 5},
	{"id": "nova", "name": "Огненная нова", "desc": "Кольцо огня по толпе", "icon": "assets/bullets/fire_explosion/red/000.png", "max": 5},
	# новая тройка (v0.13): крит, частый полумесяц, броня
	{"id": "crit", "name": "Взгляд ястреба", "desc": "Шанс крита +8%", "icon": "assets/bullets/dart/magenta/000.png", "max": 5},
	{"id": "blade_rate", "name": "Стальной вихрь", "desc": "Полумесяц чаще ×1.2", "icon": "assets/bullets/slash/blue/001.png", "max": 4},
	{"id": "armor", "name": "Каменная кожа", "desc": "Урон по тебе -12%", "icon": "assets/items/flask_green/000.png", "max": 4},
]

# ---------- ДИРЕКТОР ВОЛН ----------
# состав спавна по минутам: [от_сек, [тип, вес], ...]
const WAVE_TABLE := [
	[0.0,   [["skeleton1", 100]]],
	[60.0,  [["skeleton1", 55], ["goblin", 30], ["skull", 15]]],
	[180.0, [["skeleton1", 30], ["goblin", 25], ["skull", 20], ["skeleton2", 25]]],
	[360.0, [["skeleton2", 26], ["skull", 16], ["vampire", 22], ["goblin", 16],
		["dark_rogue", 14], ["shieldknight", 5], ["necromancer", 5]]],
	[540.0, [["vampire", 28], ["skeleton2", 28], ["skull", 20], ["dark_rogue", 16],
		["shieldknight", 6], ["necromancer", 6]]],
]
const BOSS_SCHEDULE := [
	{"time": 120.0, "type": "demon", "hp_mult": 1.0},
	{"time": 360.0, "type": "blood", "hp_mult": 1.0},
	# дальше — только НОВЫЕ боссы: никаких повторок!
	{"time": 450.0, "type": "goblin_captain", "hp_mult": 1.0},
	{"time": 500.0, "type": "komandir", "hp_mult": 1.0},
	{"time": 542.0, "type": "vybivala", "hp_mult": 1.0},
	{"time": 575.0, "type": "battery", "hp_mult": 1.0},
]
# мини-боссы-чемпионы: здоровенные версии обычных врагов с фиолетовой аурой.
# Выходят между боссами, дропают ларец. (Спрайты полноценных новых боссов
# ждём: игрок ищет жирный босс-пак — тогда добавим отдельные виды!)
const MINI_BOSS_SCHEDULE := [
	{"time": 90.0,  "type": "skeleton2",    "title": "КОСТЯНОЙ ГРОМИЛА",  "hp": 9.0},
	{"time": 250.0, "type": "necromancer",  "title": "АРХИНЕКРОМАНТ",     "hp": 9.0},
	{"time": 320.0, "type": "dark_rogue",   "title": "АТАМАН РАЗБОЙНИКОВ", "hp": 9.0},
	{"time": 470.0, "type": "shieldknight", "title": "СТАЛЬНОЙ КОЛОСС",   "hp": 10.0},
]
const WIN_TIME := 600.0
