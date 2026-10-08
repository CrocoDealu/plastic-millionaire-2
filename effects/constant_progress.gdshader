shader_type canvas_item;

const vec4 ACTIVE_COLOR = vec4(0.35, 0.85, 1.0, 1.0);
const vec4 HIGHLIGHT_COLOR = vec4(0.8, 1.0, 1.0, 1.0);

void fragment() {
	float stripe = step(0.5, fract((UV.x - UV.y * 0.35 + TIME * 0.45) * 7.0));
	vec4 color = mix(ACTIVE_COLOR, HIGHLIGHT_COLOR, stripe);
	COLOR = vec4(color.rgb, color.a * COLOR.a);
}
