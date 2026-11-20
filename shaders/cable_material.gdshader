shader_type spatial;
// DESHI IRON GARAGE — cable sleeve material (pairs with the procedural cable
// generator, Contribution D).
//
// The generator supplies the geometry; this shader supplies the reason the
// cables read as salvaged loom-sleeved wire instead of coloured tubes:
//
//   * weave ribs   UV.y bands (around the circumference) crossed with faint
//                  UV.x lengthwise fibres,
//   * dust ramp    a length-wise gradient that greys the cable where it sags
//                  toward the floor,
//   * silicone sheen a small constant SPECULAR lift so the sleeve catches the
//                  workbench lamp without going plastic-bright,
//   * marked runs  an optional helical stripe, used for the one cable the
//                  inventor labelled "reactor feed".
//
// Emission is exposed so the same shader serves the ordinary 220 V leads and the
// futuristic conduits running to the assembly platform.

render_mode cull_back, diffuse_lambert, specular_schlick_ggx;

uniform vec3 sleeve_color = vec3(0.09, 0.1, 0.11);
uniform vec3 dust_color = vec3(0.42, 0.4, 0.36);
uniform float roughness : hint_range(0.0, 1.0) = 0.62;
uniform float weave_frequency : hint_range(1.0, 120.0) = 46.0;
uniform float weave_strength : hint_range(0.0, 1.0) = 0.55;
uniform float fibre_strength : hint_range(0.0, 1.0) = 0.25;
uniform float dust_amount : hint_range(0.0, 1.0) = 0.45;
uniform float sheen : hint_range(0.0, 1.0) = 0.18;
uniform float stripe_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec3 stripe_color = vec3(0.9, 0.7, 0.2);
uniform float stripe_pitch : hint_range(0.5, 40.0) = 6.0;
uniform vec3 emission_color = vec3(0.0);
uniform float emission_energy : hint_range(0.0, 6.0) = 0.0;
uniform float kink_noise : hint_range(0.0, 1.0) = 0.3;

float hash12(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = UV;

	// ---- weave ribs around the circumference ----------------------------
	float rib = 0.5 + 0.5 * sin(uv.y * weave_frequency * 6.2831853 + sin(uv.x * 24.0) * 1.4);
	float fibre = 0.5 + 0.5 * sin(uv.x * weave_frequency * 3.1 + uv.y * 8.0);
	float scuff = hash12(floor(vec2(uv.x * 140.0, uv.y * 24.0)));

	float rough_local = roughness
		+ (rib - 0.5) * weave_strength * 0.4
		+ (fibre - 0.5) * fibre_strength * 0.25
		+ (scuff - 0.5) * kink_noise * 0.18;

	// ---- dust accumulates along the sag ----------------------------------
	float dust_mask = dust_amount * smoothstep(0.35, 0.95, uv.x) * (0.6 + 0.4 * rib);

	vec3 col = mix(sleeve_color, dust_color, dust_mask);
	col *= 0.82 + 0.18 * rib;

	// ---- helical marker stripe ------------------------------------------
	float stripe_phase = fract(uv.x * stripe_pitch + uv.y * 0.5);
	float stripe = (1.0 - smoothstep(0.0, 0.09, abs(stripe_phase - 0.5))) * stripe_amount;
	col = mix(col, stripe_color, stripe);

	ALBEDO = col;
	ROUGHNESS = clamp(rough_local, 0.05, 1.0);
	METALLIC = 0.0;
	SPECULAR = sheen;
	EMISSION = emission_color * emission_energy * (0.5 + 0.5 * rib);
}
