shader_type canvas_item;

// Solid pill of `color` with darker >>>> chevrons scrolling right (a maxed machine's bar).
uniform vec4 color : source_color = vec4(0.7255, 0.7098, 0.6667, 1.0);
uniform float period = 10.0; // px between chevrons
uniform float speed = 24.0;  // px per second
uniform float shade = 0.7;   // chevron brightness vs `color`

void fragment() {
	vec2 size = 1.0 / vec2(dFdx(UV.x), dFdy(UV.y));
	vec2 p = UV * size;
	float h = size.y * 0.5;
	float d = mod(p.x + abs(p.y - h) - TIME * speed, period);
	vec3 c = d < period * 0.5 ? color.rgb * shade : color.rgb;
	// Round the ends like the bar's fill stylebox.
	float x = clamp(p.x, h, size.x - h);
	float a = clamp(h - length(p - vec2(x, h)) + 0.5, 0.0, 1.0);
	COLOR = vec4(c, color.a * a);
}
