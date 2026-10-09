shader_type canvas_item;

// Repeating two-colour bands (CSS repeating-linear-gradient). angle in degrees, 90 = vertical bands.
uniform vec4 color_a : source_color = vec4(0.96, 0.77, 0.09, 1.0);
uniform vec4 color_b : source_color = vec4(0.08, 0.08, 0.09, 1.0);
uniform float band = 8.0;
uniform float angle = 135.0;
uniform vec2 rect_size = vec2(130.0, 12.0);

void fragment() {
	vec2 p = UV * rect_size;
	float a = radians(angle - 90.0);
	float d = p.x * cos(a) + p.y * sin(a);
	COLOR = mod(floor(d / band), 2.0) < 1.0 ? color_a : color_b;
}
