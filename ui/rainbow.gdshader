shader_type canvas_item;

// Recolours the grey blank sprite with the first `n` of `cols` (the unlocked box colours), scrolling as a diagonal rainbow.
// Shading is kept by dividing out the sprite's grey base. Snaps to art pixels.
uniform vec4 cols[5] : source_color;
uniform int n = 1;
uniform float speed = 0.6;   // colours per second
uniform float spread = 0.04; // colour steps per art pixel along the diagonal
const vec3 GREY = vec3(0.7255, 0.7098, 0.6667); // #b9b5aa, the blank's base

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	vec2 px = floor(UV / TEXTURE_PIXEL_SIZE);
	float f = TIME * speed - (px.x + px.y) * spread;
	int a = (int(floor(f)) % n + n) % n; // integer wrap: float mod can round up to n
	int b = (a + 1) % n;
	vec3 c = mix(cols[a].rgb, cols[b].rgb, smoothstep(0.0, 1.0, fract(f)));
	COLOR = vec4(clamp(t.rgb / GREY * c, 0.0, 1.0), t.a);
}
