extends TileMapLayer
## Обучающий слой для demo_map.tscn: рисует примеры тайлов-предметов кодом.
## В СВОЕЙ игре ты делаешь то же самое МЫШКОЙ в панели TileMap (см. раздел 2
## в TUTORIAL_MAP.md). На старте игры эти тайлы станут настоящими объектами:
## монеты/флаконы/ключи/сундуки — подбираемыми, факелы/свечи — горящими.
## Прочий декор (пьедестал, трофей) останется просто картинкой.

func _ready() -> void:
	# ряд предметов-примеров (оживут на старте):
	# 3 монеты, синий+большой синий флаконы, красный+большой красный, 2 ключа, сундук, мини-сундук
	var loot_row: Array = [
		Vector2i(6, 8), Vector2i(6, 8), Vector2i(6, 8),
		Vector2i(7, 8), Vector2i(7, 9), Vector2i(9, 8), Vector2i(8, 9),
		Vector2i(8, 8), Vector2i(9, 9), Vector2i(0, 8), Vector2i(4, 8),
	]
	for i in range(loot_row.size()):
		set_cell(Vector2i(6 + i, 5), 0, loot_row[i])
	# свечи и кубок (оживут огнём)
	set_cell(Vector2i(17, 5), 0, Vector2i(3, 9))
	set_cell(Vector2i(18, 5), 0, Vector2i(5, 9))
	set_cell(Vector2i(19, 5), 0, Vector2i(2, 9))
	# статичный декор — останется картинкой (игрок пройдёт сквозь)
	set_cell(Vector2i(20, 5), 0, Vector2i(4, 9))   # пьедестал
	set_cell(Vector2i(21, 5), 0, Vector2i(6, 7))   # трофей на цепи
	# факелы на верхней стене (оживут)
	set_cell(Vector2i(5, 3), 0, Vector2i(0, 9))
	set_cell(Vector2i(24, 3), 0, Vector2i(1, 9))
	set_cell(Vector2i(35, 3), 0, Vector2i(0, 9))
