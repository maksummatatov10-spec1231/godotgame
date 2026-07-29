# 🎵 Промты для генератора музыки

Три трека для Dungeon Survivors: по **минуте** каждый, **без речи/вокала**, игра сама
запустит их **по кругу**, громкость крутится в настройках паузы.
Промты на английском — генераторы понимают его лучше всего.

## 1. Боевая тема (подземелье, напряжение) → сохранить как `music_main`
```
Dark fantasy dungeon crawler game music loop, tense moody synth arpeggios with a slow
driving bass pulse, subtle taiko drums, dusty organ chords, minor key, no vocals,
no speech, instrumental only, medium intensity, seamless loop, 60 seconds
```

## 2. Битва с боссом (экшн!) → сохранить как `music_boss`
```
Epic boss battle game music loop, aggressive fast percussion, urgent staccato strings
and brass stabs, dark heroic energy, driving rhythm, minor key, no vocals, no speech,
instrumental only, high intensity, seamless loop, 60 seconds
```

## 3. Финал на 10-й минуте (выжил!) → сохранить как `music_win`
```
Triumphant victory game music loop, warm uplifting orchestral-synth theme, heroic relief
after surviving a long siege, gentle celebration melody, soft dynamics, no vocals,
no speech, instrumental only, seamless loop, 60 seconds
```

## Куда положить файлы
- Формат: **wav / ogg / mp3** — любой; лучше mp3 или ogg (меньше весят).
- Прямо в игру: скопируй 3 файла в папку **`assets/sfx/`** рядом со звуками —
  игра подхватит сама: боевая — сразу, `music_boss` при появлении босса, `music_win` на 10:00.
- Или загрузи в ветку `main` — агент запечет в следующий релиз.
- **ВАЖНО (v0.15.1+): импорт в редакторе БОЛЬШЕ НЕ НУЖЕН!** Игра читает файлы
  напрямую байтами — можно копировать новые треки в папку даже посреди забега,
  игра подхватит их за ~1.5 секунды, без единой ошибки в консоли.
- Если файла нет — игра молчит, никаких ошибок.
