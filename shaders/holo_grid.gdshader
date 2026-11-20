shader_type spatial;
// DESHI IRON GARAGE — holographic floor projection.
//
// The light cone that falls out of the design table and the assembly reactor
// onto the garage floor. It is a screen-space-independent projected grid: cells
// are derived from world XZ so the pattern stays locked to the room while the
// emitter above it rotates, and a radial sweep ring travels outward on a timer.
//
// Three things make it read as light rather than paint:
//   * distance fade to zero at the projection radius (no hard quad edge),
//   * additive-style falloff inside the alpha term so overlapping cones brighten,
//   * a dust-scatter term driven by the same flicker as the hologram shader,
//     which ties the two effects together temporally.
//
// depth_draw_never + no_depth_test ordering keeps it from punching through the
// workbench legs it is projected onto.

render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform vec3 grid_color = vec3(0.31, 0.85, 1.0);
uniform vec3 sweep_color = vec3(0.75, 0.95, 1.0);
uniform float cell_size : hint_range(0.05, 4.0) = 0.5;
uniform float line_width : hint_range(0.001, 0.2) = 0.02;
uniform float glow : hint_range(0.0, 6.0) = 1.6;
uniform float fade_radius : hint_range(0.5, 20.0) = 3.2;
uniform float sweep_speed : hint_range(0.0, 3.0) = 0.28;
uniform float sweep_width : hint_range(0.01, 1.0) = 0.22;
uniform float pulse : hint_range(0.0, 4.0) = 1.0;
uniform float dust : hint_range(0.0, 1.0) = 0.25;
uniform float tick_density : hint_range(0.0, 40.0) = 12.0;
uniform float opacity : hint_range(0.0, 1.0) = 0.85;

varying vec3 world_pos;
varying vec3 local_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	local_pos = VERTEX;
}

void fragment() {
	vec2 plane = local_pos.xz;
	float dist = length(plane);
	float fall = 1.0 - smoothstep(fade_radius * 0.45, max(fade_radius, 0.6), dist);
	if (fall <= 0.001) {
		discard;
	}

	// ---- world-locked cell grid ----------------------------------------
	vec2 wp = world_pos.xz / max(cell_size, 0.05);
	vec2 gf = fract(wp);
	vec2 gw = fwidth(wp);
	vec2 lines = smoothstep(vec2(0.0), gw * 1.4 + vec2(line_width), gf)
		* smoothstep(vec2(0.0), gw * 1.4 + vec2(line_width), 1.0 - gf);
	float grid = 1.0 - min(lines.x, lines.y);

	// ---- travelling sweep ring -----------------------------------------
	float ring_phase = fract(dist / max(fade_radius, 0.6) - TIME * sweep_speed);
	float ring = 1.0 - smoothstep(0.0, max(sweep_width, 0.01), ring_phase);
	ring *= ring * 2.2;

	// ---- perimeter ticks ------------------------------------------------
	float ang = atan(plane.y, plane.x);
	float ticks = pow(0.5 + 0.5 * sin(ang * max(tick_density, 0.0) + TIME * 0.6), 8.0);
	float tick_band = smoothstep(0.86, 0.94, dist / max(fade_radius, 0.6));

	// ---- dust scatter ---------------------------------------------------
	float flick = 0.85 + 0.15 * sin(TIME * 13.7) * sin(TIME * 2.3);
	float dust_field = dust * (0.35 + 0.65 * fract(sin(dot(world_pos.xz, vec2(12.9, 78.2))) * 43758.5453)) * flick;

	float body = (grid * 0.75 + ring * 1.3 + ticks * tick_band * 1.1 + dust_field * 0.25) * fall * pulse;

	vec3 col = mix(grid_color, sweep_color, clamp(ring * 0.8 + ticks * tick_band, 0.0, 1.0));

	ALBEDO = col * 0.1;
	EMISSION = col * glow * body;
	ALPHA = clamp(opacity * (body * 0.9 + 0.02), 0.0, 1.0);
}
