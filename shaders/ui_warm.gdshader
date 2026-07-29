shader_type canvas_item;
## Тёплый шейдер наших панелей/кнопок: пробегающий блик по диагонали
## и янтарное свечение кромки, усиливающееся при наведении (hover 0..1).
uniform vec4 accent : source_color = vec4(1.0, 0.80, 0.35, 1.0);
uniform float hover : hint_range(0.0, 1.0) = 0.0;
uniform float speed : hint_range(0.0, 3.0) = 0.55;
uniform float phase = 0.0;

void fragment() {
	vec4 c = COLOR;
	// диагональный блик, медленно ползущий через панель
	float diag = UV.x + UV.y * 0.7;
	float band = fract(diag * 0.5 - TIME * speed * 0.25 - phase);
	float d = abs(band - 0.5) * 2.0;
	float sheen = pow(1.0 - d, 8.0) * (0.09 + hover * 0.26);
	// свечение по кромке (сильнее при наведении)
	float edge = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	float glow = (1.0 - smoothstep(0.0, 0.10, edge)) * (0.08 + hover * 0.42);
	c.rgb += accent.rgb * (sheen + glow) * c.a;
	COLOR = c;
}
