shader_type spatial;
// DESHI IRON GARAGE — display glass for the workstation and diagnostic monitors.
//
// The screens in the garage are drawn as real Godot UI inside a SubViewport and
// sampled here. This shader is what stops them looking like pasted textures:
//
//   * horizontal scanlines at a fixed pixel pitch, so a 1080-line panel reads
//     differently from the small CRT beside it,
//   * a refresh band that crawls down the panel on a timer, matching how an
//     addressable LCD/CRT actually repaints,
//   * per-channel chroma offset at grazing angles, approximating the aperture
//     grille of the old CRT the inventor salvaged,
//   * a coarse brightness flicker and a static term used during the boot
//     sequence, driven by the `power` parameter the computer system animates.
//
// Unshaded on purpose: a display is a light source in this scene, and its glow
// is supplied by a separate OmniLight so it also illuminates the desk.

render_mode unshaded, cull_back, depth_draw_opaque;

uniform sampler2D screen_texture : filter_linear_mipmap;
uniform vec3 tint = vec3(1.0);
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.22;
uniform float scanline_pitch : hint_range(1.0, 800.0) = 260.0;
uniform float refresh_speed : hint_range(0.0, 4.0) = 0.55;
uniform float refresh_width : hint_range(0.01, 0.6) = 0.12;
uniform float flicker_amount : hint_range(0.0, 0.5) = 0.05;
uniform float chroma_amount : hint_range(0.0, 0.05) = 0.0035;
uniform float vignette : hint_range(0.0, 1.0) = 0.35;
uniform float glow : hint_range(0.0, 6.0) = 1.35;
uniform float static_amount : hint_range(0.0, 1.0) = 0.0;
uniform float power : hint_range(0.0, 1.0) = 1.0;
uniform float bezel_curve : hint_range(0.0, 1.0) = 0.25;
uniform vec3 off_color = vec3(0.02, 0.025, 0.03);

vec2 curve_uv(vec2 uv) {
	// A cheap barrel term: the salvaged CRT bulges slightly at the centre.
	vec2 c = uv - 0.5;
	float r2 = dot(c, c);
	return uv + c * r2 * bezel_curve * 0.35;
}

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p.yx + 34.5);
	return fract(p.x * p.y * (p.x + p.y));
}

void fragment() {
	// Godot's shading language forbids `return` inside a processor function, so
	// the powered-off case is an else branch rather than an early exit.
	if (power < 0.02) {
		ALBEDO = off_color;
		EMISSION = off_color * 0.2;
		METALLIC = 0.0;
		ROUGHNESS = 0.15;
	} else {
		vec2 uv = curve_uv(UV);
		vec2 suv = clamp(uv, vec2(0.0), vec2(1.0));

		// ---- chroma split -----------------------------------------------
		vec3 rgb;
		rgb.r = texture(screen_texture, suv + vec2(chroma_amount, 0.0)).r;
		rgb.g = texture(screen_texture, suv).g;
		rgb.b = texture(screen_texture, suv - vec2(chroma_amount, 0.0)).b;

		// ---- scanlines ---------------------------------------------------
		float sl = 0.5 + 0.5 * sin(suv.y * scanline_pitch * 6.2831853);
		rgb *= 1.0 - scanline_strength * sl;

		// ---- refresh band -------------------------------------------------
		float band_pos = fract(TIME * refresh_speed);
		float band = 1.0 - smoothstep(0.0, max(refresh_width, 0.01), abs(suv.y - band_pos));
		rgb += band * 0.06 * tint;

		// ---- static (boot / signal loss) ----------------------------------
		if (static_amount > 0.001) {
			float n = hash21(vec2(floor(suv.x * 180.0), floor(suv.y * 120.0 + TIME * 30.0)));
			rgb = mix(rgb, vec3(n), static_amount * 0.85);
		}

		// ---- flicker ------------------------------------------------------
		float flick = 1.0 - flicker_amount * (0.5 + 0.5 * sin(TIME * 47.0) * sin(TIME * 9.13));
		rgb *= flick * power;

		// ---- vignette -----------------------------------------------------
		vec2 vc = suv - 0.5;
		float vig = 1.0 - dot(vc, vc) * vignette * 2.4;
		rgb *= clamp(vig, 0.0, 1.0);

		// ---- edge glow of the panel glass ---------------------------------
		float edge = smoothstep(0.42, 0.5, length(vc));
		rgb += edge * 0.02 * tint;

		ALBEDO = rgb * tint;
		EMISSION = rgb * tint * glow;
		METALLIC = 0.0;
		ROUGHNESS = 0.12;
	}
}
