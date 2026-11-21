shader_type spatial;
render_mode unshaded, cull_disabled;

// The chasing LED frame around the shop signboard — the colour-cycling strip
// every Bangladeshi sign shop sells by the metre. Each bar of the frame samples a
// hue from its own object-space position plus time, so all four bars drift
// through the rainbow together and the frame reads as one loop rather than four
// separate strips. Unshaded, so it is lit by nothing but itself, and bright
// enough to bloom under the glow pass.

uniform float speed : hint_range(0.0, 2.0) = 0.14;
uniform float density : hint_range(0.05, 1.0) = 0.55;
uniform float saturation : hint_range(0.0, 1.0) = 0.9;
uniform float brightness : hint_range(0.0, 4.0) = 2.1;

vec3 hsv2rgb(vec3 c) {
	vec3 rgb = clamp(abs(mod(c.x * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
	return c.z * mix(vec3(1.0), rgb, c.y);
}

void fragment() {
	float hue = fract((VERTEX.x + VERTEX.y * 0.6) * density + TIME * speed);
	vec3 col = hsv2rgb(vec3(hue, saturation, 1.0)) * brightness;
	ALBEDO = col;
	EMISSION = col;
}
