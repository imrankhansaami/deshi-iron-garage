shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

// The national flag on the courtyard pole. The cloth is a subdivided plane whose
// vertices ride two travelling waves; the amplitude grows with the square of the
// distance from the hoist, so the edge bound to the pole stays put and the fly end
// moves most — which is what actually makes a flag read as cloth rather than as a
// texture on a rectangle. The pattern (bottle green field, red disc at the
// official 9/20 length with radius 1/5 of the length) arrives as a baked texture
// from the same SignCanvas pipeline every other sign uses.

uniform sampler2D flag_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float wave_speed : hint_range(0.0, 4.0) = 1.3;
uniform float wave_amp : hint_range(0.0, 0.3) = 0.075;
uniform float wave_freq : hint_range(0.0, 20.0) = 5.2;

void vertex() {
	// UV.x == 0 at the hoist (the pole side of the plane)
	float away = clamp(UV.x, 0.0, 1.0);
	float t = TIME * wave_speed;
	float wave = sin(away * wave_freq - t) * 0.62
		+ sin(away * wave_freq * 1.73 - t * 1.31 + UV.y * 2.1) * 0.38;
	float pull = away * away;
	VERTEX.z += wave * wave_amp * pull;
	// a little flap along the fly edge, and a slight droop of the whole cloth
	VERTEX.y += sin(away * 3.1 - t * 0.72) * 0.012 * pull - pull * 0.02;
}

void fragment() {
	vec4 c = texture(flag_tex, UV);
	ALBEDO = c.rgb;
	ROUGHNESS = 0.86;
	METALLIC = 0.0;
	SPECULAR = 0.2;
	// the cloth is lit from both sides: flip the normal for back faces rather than
	// leaving the reverse of the flag in shadow
	NORMAL = FRONT_FACING ? NORMAL : -NORMAL;
}
