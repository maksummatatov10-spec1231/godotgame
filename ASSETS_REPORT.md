# 📦 Полный анализ ассет-паков

Распаковано в `_assets_extracted/`. Всего **5 архивов** → ~5700 файлов.

Дата анализа: 28.07.2026

---

## 1. 🏰 2D Pixel Dungeon Asset Pack v2.0 → `_assets_extracted/dungeon/`

Автор: **pixel_poem** (pixel-poem.itch.io, 2018). Стиль: top-down данжен, тёмно-фиолетовая палитра, базовая плитка **16×16**.
В архиве нет файла лицензии (смотри страницу пака на itch.io).

| Файл | Размер | Что это |
|---|---|---|
| `character and tileset/Dungeon_Tileset.png` | 160×160 | Тайлсет данжена: полы, стены, двери, декор |
| `character and tileset/Dungeon_Character.png` | 112×64 (7×4 ячейки 16×16) | Герои: рыцарь, ассасин, маг, варвар и др. — по 4 кадра |
| `character and tileset/Dungeon_Character_2.png` | 112×32 (7×2) | Ещё персонажи: маг, смерть/жнец, гоблин, старик |
| `Dungeon_Tileset_at.png` / `Dungeon_Character_at.png` | 512×512 | Увеличенные/showcase-версии |
| `demonstration.png`, `Dungeon_gif.gif` | 256×256 | Примеры собранных комнат |

### Character_animation/ (idle-анимации 16×16, 4 кадра, варианты v1/v2)
- **Монстры:** skeleton1, skeleton2, skull, vampire
- **Жрецы:** priest1, priest2, priest3 (идеально для NPC/торговца!)

### items and trap_animation/ (всё 16×16, по 4 кадра)
- **Ловушки:** `peaks` (шипы), `flamethrower` (2 вида огнемётов-ловушек)
- **Лут:** `coin`, `chest` (+анимация открытия), `mini_chest` (+открытие), `keys` (2 цвета), `flasks` (зелья, 4 цвета), `box_1/box_2/mini_box_1/mini_box_2`
- **Декор/свет:** `torch` (настенный факел), `side_torch`, 2 подсвечника, `flag`, `arrow` (16×32 — стрела-снаряд)

### interface/
Стрелки (4 шт) и рамки-квадраты подсветки (left/right/up_down × варианты) — для UI выбора/инвентаря.

---

## 2. 💀 Enemy_Animations_Set → `_assets_extracted/enemy_anims/`

Полные наборы анимаций врагов, кадр **32×32**. Те же монстры, что в dungeon-паке (skeleton1, skeleton2, vampire) — это **дополнение к паку №1**!

| Монстр | attack | death | idle | movement | take_damage |
|---|---|---|---|---|---|
| skeleton1 | 9 кадров | 17 кадров | 6 | 10 | 5 |
| skeleton2 | 15 | 15 + death2 (15) | 6 | 10 | 5 |
| vampire | 16 | 14 | 6 | 8 | 5 |

Бонус: `enemies.aseprite` — исходник для Aseprite.

---

## 3. 🔥 New_All_Fire_Bullet_Pixel_16x16 (RAR) → `_assets_extracted/fire_bullet/`

- **8 спрайтшитов 640×400** = каждый 40×25 ячеек 16×16 → **~1000 спрайтов на лист, ≈8000 всего!**
- Содержимое: огненные шары, волны пламени, огненные стрелы и клинки, метеоры, фаербол-взрывы, шлейфы, импакты.
- Листы 00–07 — цветовые варианты (00 = золотой/жёлтый, 07 = красный и т.д.).
- Анимации лежат «строками» — удобно резать на анимации в Godot.

Это практически **готовая библиотека снарядов/заклинаний**.

---

## 4. ✨ Super Pixel Effects Gigapack (Free Version) v2.7.0 → `_assets_extracted/effects_gigapack/`

Автор: **Will Tice / unTied Games**. **Лицензия:** коммерческое и некоммерческое использование OK, **обязательна атрибуция** в титрах (например "Super Pixel Effects Gigapack — Will Tice / unTied Games"). Распространять сами ассеты отдельно от игры запрещено. Нельзя использовать как обучающие данные для ИИ. (см. `license.txt`)

- **91 уникальный эффект**, каждый в двух размерах → **182 спрайтшита** с метаданными `spritesheet.txt` + папки PNG покадрово (5512 файлов).
- Large = кадр **128×128**, Small = **64×64**. Рекомендованный FPS: **15**.
- Цвета: orange, yellow, red, green, violet, blue, white, brown.

| Категория | Эффектов | Примеры |
|---|---|---|
| Explosions | 6 | epic/stylized/symmetrical explosion |
| Fantasy Spells | 9 | heal, poison, absorb, attack_up, defense_up, haste, death, status_sparkling |
| Impacts | 11 | directional/symmetrical impacts (хиты в бою!) |
| Lightning | 4 | lightning_burst ×3, lightning_strike |
| Magic Bursts | 13 | heart/coin/sparkle/firework/bubble/music bursts |
| Sci-fi | 9 | muzzle_flash, charge_up, warp ×3, heartbeat ×3, spark_burst |
| Smoke Bursts | 3 | smoke, skull_smoke |
| Splatters | 4 | burst/directional splatters (кровь!) |
| Symbols | 32 | alert, level_up, game_over, complete, success, failure, crown, **ranks A–S**, places 1st–8th, thumbs up/down, question |

Метаданные `spritesheet.txt` в формате `путь = x y w h` → элементарно импортируется скриптом в Godot.

---

## 5. 😈 Tiny RPG Character Asset Pack 02 — Free Demon_A & Blood Monster_A → `_assets_extracted/tiny_rpg/`

Два **крупных монстра** (кадр 100×100, сам спрайт ~25–35 px — визуально крупнее 16×16-мобы, идеальны для боссов/элиток). Варианты «с тенью» и «без тени» + исходники `.aseprite`.

| Монстр | Idle | Walk | Attack01 | Attack02 | Death | Hurt |
|---|---|---|---|---|---|---|
| Demon_A (чёрный демон, рога, красные глаза) | 6 | 8 | 7 | 7 | 4 | 4 |
| Blood Monster_A (алая кровавая тварь) | 6 | 8 | 8 | 8 | 4 | 4 |

---

# 🎮 Вывод: что из этого собирается

Набор покрывает **полный цикл top-down action/roguelite игры**:
- ✅ Мир: тайлсет данжена + декор + ловушки (шипы, огнемёты)
- ✅ Герои: 8+ персонажей (классы: рыцарь/маг/ассасин/варвар...)
- ✅ Враги: 3 скелета/вампир с полными анимациями + череп + idle-мобы
- ✅ Боссы/элитки: Demon_A, Blood Monster_A (100×100)
- ✅ Атаки/заклинания: ~8000 огненных снарядов 16×16
- ✅ Эффекты-сок: взрывы, молнии, хиты, кровь, хил/яды/баффы, UI-символы (rank A–S, level up)
- ✅ Лут/экономика: монеты, сундуки, ключи, зелья
- ✅ NPC: 3 жреца
- ❌ Нет: звуков/музыки, шрифта UI, собственной анимации атаки у героя (решается снарядами/эффектами)

Рекомендуемый масштаб: базовый тайл 16×16, враги 32×32 = ×2, боссы/эффекты — в нативный размер поверх.
