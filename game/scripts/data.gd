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
}

# ---------- СНАРЯДЫ ----------
const PROJECTILES := {
	# дротик игрока — 8 цветов = уровни прокачки урона
	"dart": {"fps": 12.0, "face_left": true, "life": 1.7, "hit_fx": "assets/effects/impact_yellow", "hit_fx_scale": 0.24},
	"slash": {"fps": 14.0, "face_left": false, "life": 0.32, "hit_fx": ""},
	# вражеские
	"orb_violet": {"dir": "assets/bullets/orb/violet", "fps": 12.0, "face_left": false, "life": 3.0, "speed": 95.0, "hit_fx": "assets/effects/impact_blue", "hit_fx_scale": 0.22},
	"comet_red": {"dir": "assets/bullets/comet/red", "fps": 10.0, "face_left": false, "life": 3.4, "speed": 105.0, "hit_fx": "assets/bullets/fire_explosion/red", "hit_fx_scale": 1.0},
}

# цвета дротика по уровню урона (все 8 листов пака!)
const DART_COLORS := ["gold", "amber", "orange", "green", "blue", "violet", "magenta", "red"]
const SLASH_COLORS := ["gold", "amber", "orange", "green", "blue", "violet", "magenta", "red"]

# ---------- УЛУЧШЕНИЯ НА УРОВЕНЬ ----------
const UPGRADES := [
	{"id": "dart_rate", "name": "Пылающие руны", "desc": "Скорострельность дротиков +25%", "icon": "assets/bullets/dart/gold/000.png", "max": 6},
	{"id": "dart_dmg", "name": "Горячие стрелы", "desc": "Урон дротиков +30% (новый цвет пламени!)", "icon": "assets/bullets/dart/amber/000.png", "max": 7},
	{"id": "dart_count", "name": "Веер дротиков", "desc": "+1 дротик за выстрел", "icon": "assets/bullets/dart/blue/000.png", "max": 4},
	{"id": "slash", "name": "Огненный полумесяц", "desc": "Полумесяц: +40% урона и шире дуга", "icon": "assets/bullets/slash/gold/001.png", "max": 7},
	{"id": "boots", "name": "Сапоги ветра", "desc": "Скорость бега +12%", "icon": "assets/items/flask_blue/000.png", "max": 5},
	{"id": "heart", "name": "Сердце титана", "desc": "+25 к макс. HP и лечение", "icon": "assets/items/flask_red/000.png", "max": 7},
	{"id": "magnet", "name": "Магнит душ", "desc": "Радиус сбора монет +45%", "icon": "assets/items/coin/001.png", "max": 5},
	{"id": "regen", "name": "Тихое пламя", "desc": "Регенерация +0.6 HP/сек", "icon": "assets/effects/heal_red/004.png", "max": 5},
]

# ---------- ДИРЕКТОР ВОЛН ----------
# состав спавна по минутам: [от_сек, [тип, вес], ...]
const WAVE_TABLE := [
	[0.0,   [["skeleton1", 100]]],
	[60.0,  [["skeleton1", 55], ["goblin", 30], ["skull", 15]]],
	[180.0, [["skeleton1", 30], ["goblin", 25], ["skull", 20], ["skeleton2", 25]]],
	[360.0, [["skeleton2", 30], ["skull", 20], ["vampire", 25], ["goblin", 25]]],
	[540.0, [["vampire", 35], ["skeleton2", 35], ["skull", 30]]],
]
const BOSS_SCHEDULE := [
	{"time": 120.0, "type": "demon", "hp_mult": 1.0},
	{"time": 360.0, "type": "blood", "hp_mult": 1.0},
	{"time": 540.0, "type": "demon", "hp_mult": 2.2},
]
const WIN_TIME := 600.0
