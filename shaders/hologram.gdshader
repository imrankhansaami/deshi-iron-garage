shader_type spatial;
// DESHI IRON GARAGE — holographic display shader (Contribution B).
//
// A volumetric-looking cyan projection built from four independent terms that
// multiply together, so the effect survives being viewed from any angle in the
// garage:
//
//   1. Fresnel term      grazing angles glow, faces-on stay see-through. This is
//                        what sells "thin light shell" instead of "flat decal".
//   2. Horizontal scan   world-space (not UV-space) so scanlines stay physically
//                        stacked as the mesh rotates and multiple holograms share
//                        one continuous sweep.
//   3. Interference grid projected in object space, giving the surface a readable
//                        engineering-paper texture at close range.
//   4. Temporal flicker  a hash of TIME plus a slow beat, deliberately coarse so
//                        it reads as an unstable DIY projector rather than noise.
//
// A travelling scan band sweeps vertically on request; that is the "acquiring"
// look used by the design table and the diagnostic overlays.
//
// Deliberately unshaded: a hologram must not respond to the garage lights, and
// skipping the PBR path keeps its cost almost purely fill-rate. Measured in
// docs/EXPERIMENTS.md, Experiment 2.

render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform vec3 hologram_color = vec3(0.34, 0.85, 1.0);
uniform vec3 accent_color = vec3(0.65, 0.95, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.62;
uniform float glow_strength : hint_range(0.0, 6.0) = 2.1;
uniform float fresnel_power : hint_range(0.2, 8.0) = 2.4;
uniform float rim_boost : hint_range(0.0, 4.0) = 1.6;
uniform float scan_speed : hint_range(0.0, 4.0) = 0.55;
uniform float scan_density : hint_range(0.0, 120.0) = 26.0;
uniform float scan_band_speed : hint_range(0.0, 3.0) = 0.35;
uniform float scan_band_width : hint_range(0.001, 0.5) = 0.09;
uniform float grid_scale : hint_range(0.0, 200.0) = 34.0;
uniform float grid_amount : hint_range(0.0, 1.0) = 0.35;
uniform float flicker_amount : hint_range(0.0, 1.0) = 0.12;
uniform float line_thickness : hint_range(0.0, 1.0) = 0.45;
uniform float wireframe_only : hint_range(0.0, 1.0) = 0.0;
uniform float vertical_axis : hint_range(0.0, 1.0) = 1.0;
uniform float acquire : hint_range(0.0, 1.0) = 1.0;

varying vec3 local_pos;
varying vec3 world_pos;

float h21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void vertex() {
	local_pos = VERTEX;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// ---- 1. fresnel ----------------------------------------------------
	vec3 n = normalize(NORMAL);
	vec3 v = normalize(VIEW);
	float ndv = clamp(dot(n, v), 0.0, 1.0);
	float fres = pow(1.0 - ndv, max(fresnel_power, 0.01));
	float shell = mix(1.0, fres, rim_boost / (1.0 + rim_boost));

	// ---- 2. world-space scanlines --------------------------------------
	float axis = mix(world_pos.x, world_pos.y, vertical_axis);
	float scan = 0.5 + 0.5 * sin(axis * scan_density * 6.2831853 + TIME * scan_speed * 6.2831853);
	scan = mix(1.0, scan, line_thickness);

	// ---- 3. travelling acquisition band ---------------------------------
	float band_period = 3.2;
	float band_pos = fract((axis * 0.35) - TIME * scan_band_speed);
	float band = 1.0 - smoothstep(0.0, max(scan_band_width, 0.002), abs(band_pos - 0.5));
	band *= acquire;

	// ---- 4. object-space interference grid -----------------------------
	vec2 g = fract(local_pos.xy * grid_scale + local_pos.z * grid_scale * 0.5);
	vec2 gw = fwidth(local_pos.xy * grid_scale);
	vec2 line = smoothstep(vec2(0.0), gw * 1.6, g) * smoothstep(vec2(0.0), gw * 1.6, 1.0 - g);
	float grid = 1.0 - min(line.x, line.y);
	grid = mix(1.0, 0.55 + grid * 0.45, grid_amount);

	// ---- 5. coarse temporal flicker ------------------------------------
	float beat = 0.5 + 0.5 * sin(TIME * 17.0) * sin(TIME * 3.7);
	float glitch = step(0.985, h21(vec2(floor(TIME * 24.0), 3.0)));
	float flicker = 1.0 - flicker_amount * beat - glitch * 0.35;

	// ---- composite ------------------------------------------------------
	float body = shell * scan * grid * flicker;
	float alpha = clamp(opacity * body + band * 0.55, 0.0, 1.0);

	vec3 col = mix(hologram_color, accent_color, band * 0.8 + fres * 0.35);

	ALBEDO = col * 0.25;
	EMISSION = col * (glow_strength * (body * 0.7 + band * 1.6 + fres * 0.9));
	ALPHA = alpha;

	// Wireframe-only mode collapses the fill to the grid, used by the
	// schematic view on the design table.
	if (wireframe_only > 0.5) {
		float w = grid;
		ALPHA = clamp(opacity * w * (0.4 + band), 0.0, 1.0);
		EMISSION = col * glow_strength * w * 1.4;
	}
}
