shader_type spatial;
// DESHI IRON GARAGE — fictional energy core (Contribution C).
//
// The chest core and the assembly-station reactor are the brightest things in
// the scene, so this shader is written as an emissive *field* rather than a lit
// surface. It composes five terms:
//
//   1. Plasma churn   3-octave fBm advected through TIME, giving the interior
//                     the slow convection of a reactor instead of a flat disc.
//   2. Containment rings  concentric bands whose spacing follows the surface's
//                     local radius, so the same material works on the disc, the
//                     sphere and the housing bezel.
//   3. Radial spokes  angular modulation locked to the rotation of the mesh,
//                     reading as the mechanical cage around the plasma.
//   4. Arc filaments  thresholded high-frequency noise that flickers on and off
//                     per-frame: the "unstable DIY" character of the prototype.
//   5. Fresnel shell  the rim bloom that makes the core read as a glowing volume.
//
// Everything is driven by four exposed parameters — glow strength, pulse speed,
// core colour and rotation speed — which the player can toggle live from the
// energy-core interaction and the graphics bench. Output feeds Godot's bloom
// threshold, so raising glow_strength visibly spills light onto the armour.
//
// Cost note: fBm plus one derivative-free ring term. Measured in
// docs/EXPERIMENTS.md, Experiment 2 (core variants) and Experiment 5.

render_mode unshaded, cull_back, depth_draw_opaque, blend_mix;

uniform vec3 core_color = vec3(0.49, 0.95, 1.0);
uniform vec3 rim_color = vec3(0.72, 0.96, 1.0);
uniform vec3 hot_color = vec3(1.0, 0.98, 0.92);
uniform float glow_strength : hint_range(0.0, 12.0) = 3.4;
uniform float pulse_speed : hint_range(0.0, 6.0) = 1.35;
uniform float pulse_depth : hint_range(0.0, 1.0) = 0.28;
uniform float ring_count : hint_range(0.0, 12.0) = 3.0;
uniform float ring_speed : hint_range(-4.0, 4.0) = 0.5;
uniform float ring_sharpness : hint_range(0.5, 40.0) = 14.0;
uniform float noise_scale : hint_range(0.5, 24.0) = 6.0;
uniform float plasma_amount : hint_range(0.0, 1.0) = 0.55;
uniform float arc_intensity : hint_range(0.0, 1.0) = 0.7;
uniform float spoke_count : hint_range(0.0, 24.0) = 8.0;
uniform float fresnel_power : hint_range(0.2, 6.0) = 2.0;
uniform float spin : hint_range(-4.0, 4.0) = 0.35;
uniform float instability : hint_range(0.0, 1.0) = 0.35;
uniform float alpha : hint_range(0.0, 1.0) = 1.0;
uniform float mode : hint_range(0.0, 2.0) = 0.0;   // 0 disc, 1 sphere volume, 2 bezel ring

varying vec3 local_pos;
varying vec3 world_pos;
varying float radius_u;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float vnoise(vec3 p) {
	// Value noise with a quintic fade, written out rather than relying on the
	// engine's noise() builtin so the shader compiles identically on every
	// driver the project is tested on.
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float n000 = hash13(i);
	float n100 = hash13(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash13(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash13(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash13(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash13(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash13(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash13(i + vec3(1.0, 1.0, 1.0));
	float x00 = mix(n000, n100, f.x);
	float x10 = mix(n010, n110, f.x);
	float x01 = mix(n001, n101, f.x);
	float x11 = mix(n011, n111, f.x);
	return mix(mix(x00, x10, f.y), mix(x01, x11, f.y), f.z);
}

float my_fbm(vec3 p) {
	float sum = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 3; i++) {
		sum += vnoise(p) * amp;
		p = p * 2.07 + vec3(11.0, 7.0, 3.0);
		amp *= 0.5;
	}
	return sum * 1.33;
}

void vertex() {
	local_pos = VERTEX;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	radius_u = length(VERTEX.xy);
}

void fragment() {
	vec2 p = local_pos.xy;
	float r = clamp(length(p) * 0.5 + 0.5, 0.0, 1.0);
	float ang = atan(p.y, p.x);

	// ---- rotation lock --------------------------------------------------
	float rot = TIME * spin;
	vec2 rp = vec2(
		p.x * cos(rot) - p.y * sin(rot),
		p.x * sin(rot) + p.y * cos(rot)
	);

	// ---- 1. plasma ------------------------------------------------------
	vec3 np = vec3(rp * noise_scale, TIME * 0.45);
	float churn = my_fbm(np);
	float fine = my_fbm(np * 2.3 + vec3(0.0, 0.0, TIME * 0.9));
	float plasma = mix(churn, fine, 0.45) * plasma_amount;

	// ---- 2. containment rings ------------------------------------------
	float ring_phase = r * ring_count * 6.2831853 - TIME * ring_speed * 6.2831853;
	float rings = abs(sin(ring_phase));
	rings = pow(rings, max(ring_sharpness, 0.5) * 0.25);

	// ---- 3. radial spokes ----------------------------------------------
	float spokes = 0.5 + 0.5 * sin(ang * max(spoke_count, 0.0) + TIME * spin * 2.0);
	spokes = pow(spokes, 3.0);

	// ---- 4. arc filaments ----------------------------------------------
	float arc_field = my_fbm(vec3(rp * noise_scale * 3.1, TIME * 2.2));
	float arc = smoothstep(0.62 - instability * 0.25, 0.86, arc_field) * arc_intensity;

	// ---- 5. fresnel shell -----------------------------------------------
	vec3 n = normalize(NORMAL);
	vec3 v = normalize(VIEW);
	float fres = pow(1.0 - clamp(dot(n, v), 0.0, 1.0), max(fresnel_power, 0.05));

	// ---- breathing pulse -------------------------------------------------
	float pulse = 1.0 + pulse_depth * sin(TIME * pulse_speed * 6.2831853);
	// a rare hard flicker: the core is a salvaged DIY build, not a factory part
	float dropout = 1.0 - instability * 0.5 * step(0.97, hash13(vec3(floor(TIME * 30.0), 1.0, 2.0)));

	// ---- mode shaping ----------------------------------------------------
	float body = 0.0;
	if (mode < 0.5) {            // flat disc face
		body = (1.0 - smoothstep(0.55, 1.0, r)) * (0.55 + plasma + rings * 0.5 + spokes * 0.35);
	} else if (mode < 1.5) {     // spherical volume
		body = 0.45 + plasma * 1.15 + rings * 0.35 + fres * 0.9;
	} else {                    // machined bezel ring
		float band = smoothstep(0.62, 0.72, r) * (1.0 - smoothstep(0.94, 1.0, r));
		body = band * (0.5 + rings * 0.9 + spokes * 0.5);
	}

	body *= pulse * dropout;
	body += arc * 1.6;

	vec3 col = mix(core_color, hot_color, clamp(body * 0.55, 0.0, 1.0));
	col = mix(col, rim_color, fres * 0.6);

	ALBEDO = col * 0.18;
	EMISSION = col * max(glow_strength, 0.0) * max(body, 0.0);
	ALPHA = alpha;
}
