shader_type spatial;
// DESHI IRON GARAGE — machined metal with emissive seams (Contribution A/E).
//
// Built for the futuristic hardware that the inventor fabricated himself:
// brushed alloy bodies with a glowing seam where two hand-formed plates meet,
// and an edge-wear term that exposes brighter metal along panel boundaries.
//
// Unlike the StandardMaterial3D surfaces this shader stays in the lit path, so
// the garage's warm fluorescent lamps and the core's cyan light both show up as
// specular highlights on the same object. That is the visual argument of the
// whole project: one material catching two different eras of lighting.
//
// Terms:
//   * anisotropic brushing  directional noise stretched along U, perturbing
//     roughness per-texel rather than via a texture lookup,
//   * seam emission        UV-gap mask, pulsed and phase-offset per instance,
//   * edge wear            a high-frequency mask that lifts metallic toward 1
//     and roughness toward 0 where paint has been rubbed away,
//   * grime gradient       dust settling in the lower half of the object,
//     which is what keeps DIY hardware from looking factory-fresh.

render_mode cull_back, diffuse_lambert, specular_schlick_ggx;

uniform vec3 base_color = vec3(0.42, 0.45, 0.48);
uniform vec3 seam_color = vec3(0.35, 0.9, 1.0);
uniform vec3 wear_color = vec3(0.78, 0.8, 0.82);
uniform float metallic : hint_range(0.0, 1.0) = 0.95;
uniform float roughness : hint_range(0.0, 1.0) = 0.34;
uniform float brush_strength : hint_range(0.0, 1.0) = 0.35;
uniform float brush_scale : hint_range(1.0, 400.0) = 90.0;
uniform float seam_energy : hint_range(0.0, 8.0) = 2.2;
uniform float seam_width : hint_range(0.0, 0.4) = 0.06;
uniform float seam_pulse_speed : hint_range(0.0, 6.0) = 1.1;
uniform float seam_phase : hint_range(0.0, 6.28) = 0.0;
uniform float seam_amount : hint_range(0.0, 1.0) = 1.0;
uniform float edge_wear : hint_range(0.0, 1.0) = 0.35;
uniform float grime : hint_range(0.0, 1.0) = 0.4;
uniform float panel_u : hint_range(0.0, 12.0) = 3.0;
uniform float panel_v : hint_range(0.0, 12.0) = 2.0;
uniform vec3 emission_color = vec3(0.0);
uniform float emission_energy : hint_range(0.0, 8.0) = 0.0;

float hash12(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	return mix(
		mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x),
		mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

void fragment() {
	vec2 uv = UV;

	// ---- brushing: stretched high-frequency noise -----------------------
	float brush = vnoise2(vec2(uv.x * brush_scale * 8.0, uv.y * brush_scale));
	float brush2 = vnoise2(vec2(uv.x * brush_scale * 21.0 + 7.0, uv.y * brush_scale * 3.0));
	float rough_local = roughness + (brush - 0.5) * brush_strength * 0.5 + (brush2 - 0.5) * brush_strength * 0.25;

	// ---- panel seam mask -------------------------------------------------
	vec2 gp = fract(uv * vec2(max(panel_u, 0.001), max(panel_v, 0.001)));
	vec2 gwidth = fwidth(uv * vec2(panel_u, panel_v));
	vec2 seam_lines = smoothstep(vec2(0.0), gwidth * 1.5 + vec2(seam_width), gp)
		* smoothstep(vec2(0.0), gwidth * 1.5 + vec2(seam_width), 1.0 - gp);
	float seam = 1.0 - min(seam_lines.x, seam_lines.y);

	float pulse = 0.65 + 0.35 * sin(TIME * seam_pulse_speed * 6.2831853 + seam_phase);
	// seams collect dust, so they read darker when unpowered
	float seam_lit = seam * seam_amount * pulse;

	// ---- edge wear -------------------------------------------------------
	float wear_field = vnoise2(uv * 42.0 + vec2(3.0, 11.0));
	float wear = smoothstep(0.62, 0.86, wear_field) * edge_wear;

	// ---- grime in the lower half -----------------------------------------
	float height_grad = clamp((WORLD_VERTEX.y - floor(WORLD_VERTEX.y)) , 0.0, 1.0);
	float grime_mask = grime * (1.0 - smoothstep(0.15, 0.75, fract(WORLD_VERTEX.y * 0.9 + uv.y * 0.4)));

	vec3 col = base_color;
	col = mix(col, wear_color, wear);
	col = mix(col, col * vec3(0.55, 0.5, 0.44), grime_mask);
	col = mix(col, seam_color, seam_lit * 0.35);

	ALBEDO = col;
	METALLIC = clamp(metallic + wear * 0.05 - grime_mask * 0.35, 0.0, 1.0);
	ROUGHNESS = clamp(rough_local + grime_mask * 0.35 - wear * 0.18 + seam * 0.12, 0.03, 1.0);
	SPECULAR = 0.6;
	EMISSION = seam_color * seam_lit * seam_energy + emission_color * emission_energy;
	// Seams read as recessed through a roughness and AO shift rather than a
	// normal-map write: the mesh normals on hand-built geometry are already
	// uneven, and stacking a synthetic perturbation on top of that made the
	// plates look moulded rather than welded.
	AO_LIGHT_AFFECT = 0.4;
	AO = 1.0 - seam * 0.35 - grime_mask * 0.2;
}
