shader_type canvas_item;
// Контур вокруг спрайта: цвет задаётся из кода (синий -> красный с уровнем героя)
uniform vec4 line_color : source_color = vec4(0.25, 0.60, 1.0, 1.0);
uniform float thickness = 1.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (c.a < 0.1) {
		vec2 px = TEXTURE_PIXEL_SIZE * thickness;
		float around = max(
			max(texture(TEXTURE, UV + vec2(px.x, 0.0)).a, texture(TEXTURE, UV - vec2(px.x, 0.0)).a),
			max(texture(TEXTURE, UV + vec2(0.0, px.y)).a, texture(TEXTURE, UV - vec2(0.0, px.y)).a));
		if (around > 0.1) {
			COLOR = line_color;
		} else {
			COLOR = c;
		}
	} else {
		COLOR = c;
	}
}
