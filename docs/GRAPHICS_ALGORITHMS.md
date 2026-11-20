# GRAPHICS ALGORITHMS AND IMPLEMENTATION

This document covers the five graphics contributions the project claims, plus two supporting systems.
Each section states plainly whether the work is a **built-in feature configured**, a **built-in
feature extended**, or a **custom implementation**, because the difference matters and blurring it
would be the easiest way to overstate the project.

---

## 1. Summary of claims

| # | Contribution | Kind | Where |
|---|---|---|---|
| A | Physically based workshop rendering from a shared height field | **Custom implementation** | `scripts/procedural/texture_factory.gd`, `scripts/core/material_library.gd` |
| B | Holographic projection shader | **Custom implementation** | `shaders/hologram.gdshader` |
| C | Energy-core emissive shader | **Custom implementation** | `shaders/energy_core.gdshader` |
| D | Procedural cable geometry | **Custom implementation** | `scripts/procedural/cable_generator.gd` |
| E | Interactive lighting | **Built-in features, extended by a control system** | `scripts/garage/garage_environment.gd` |
| F | Runtime audio synthesis *(supporting)* | **Custom implementation** | `scripts/procedural/audio_synth.gd` |
| G | Procedural prop and layout generation *(supporting)* | **Custom implementation** | `scripts/procedural/props_*.gd` |

**Explicitly not claimed as original:** the microfacet BRDF and its sampling, the Fresnel
approximation, `FastNoiseLite`'s noise generation, mipmapping and anisotropic filtering, SDFGI,
SSAO, SSR, volumetric fog, glow, AgX tonemapping, `SurfaceTool` and `ArrayMesh`, `SubViewport`
rendering, or any Godot material property. Where these appear below they are named as engine features
being configured or driven.

---

## 2. Contribution A — Physically based workshop rendering

### 2.1 The problem with painting three maps

The conventional way to author a surface is to paint an albedo map, paint a roughness map, and
generate a normal map from a height map — often from three separate sources, at three different
scales, by three different processes. The result *usually* looks plausible, and fails in a specific
way: **the channels disagree about where the surface has structure.** A dark pore in the albedo does
not necessarily coincide with a rough patch in the roughness map or a recess in the normal map, so
the eye reads a smear of texture rather than a material with a surface.

The obvious fix, and the one this project takes, is to make all four channels **read from the same
height field at the same texel**. A pore is then simultaneously darker, rougher and geometrically
recessed, because all three are consequences of one number.

### 2.2 Field generation

For a surface with recipe parameters — base and tint colours, grain amplitudes and scales, roughness
and metallic ranges, and optional wear, pitting, streak and pattern passes — the factory generates
scalar fields as `Image`s and reads them back as `PackedByteArray`:

| Field | Source | Purpose |
|---|---|---|
| `mottle` | `FastNoiseLite` simplex-smooth, 5 octaves | broad colour and height variation |
| `grain` | `FastNoiseLite` value noise, 2 octaves | mid-frequency surface break-up |
| `fine` | `FastNoiseLite` simplex-smooth, 3 octaves | high-frequency micro-detail |
| `wear` | `FastNoiseLite` cellular | corrosion / paint-loss mask |
| `front` | `FastNoiseLite` simplex-smooth | the corrosion *front* itself |
| `pit` | `FastNoiseLite` cellular | pitting and cracks |
| `streak`, `along` | value and simplex | vertical grime runs |
| `scratch` | value noise, stretched | micro-scratches on metal |
| `pat_a`, `pat_b`, `pat_c` | per-pattern | pattern layers (brick bond, PCB traces, tiles) |

**Why the engine's noise and not a hand-written noise function.** The first implementation evaluated
noise per texel in GDScript. Measured, one 512 px surface took **7.8 seconds**, of which the noise
itself was most of it. Moving field generation to `FastNoiseLite` — which fills the whole image in C++
— and reducing the per-texel loop to byte-index arithmetic on precomputed fields brought the same
surface to **1.7 seconds**, a 4.5× improvement, with the noise quantitatively similar.

The hand-written noise in `scripts/procedural/noise.gd` is retained only for the cases
`FastNoiseLite` cannot express cheaply in bulk: integer hashing for scatter decisions, Worley F1 for
pitting, a ridged variant for corrosion, and domain warping. Under `--headless` the bulk path returns
an empty image and the GDScript path is used as a fallback so the project still builds in CI.

### 2.3 Per-texel composition

For each texel, in order:

1. **Base.** Height `h = 0.62·mottle + 0.16·grain + 0.10·fine`. Colour lerps from `base` toward
   `tint_a` and `tint_b` by the mottle value, weighted by a grain factor. Roughness is
   `rough_base + mottle·rough_var·0.6 + grain·rough_var·0.4`.

   The weights are not arbitrary. An earlier set used `0.5 / 0.28 / 0.22` with the grain fields at
   four times the frequency; the render came out looking like sandpaper, because high-frequency noise
   carrying a third of the height amplitude produces features at 12 mm that the eye integrates as
   static rather than reading as material. The current weighting puts the coarse layer clearly in
   charge and the fine layers in support.

2. **Pattern layer**, if the recipe declares one:
   - `brick` — stretcher bond with alternate courses offset by half a brick, mortar joints narrowed by
     the local derivative, per-brick tint from an integer hash so bricks differ but stay stable.
   - `corrugation` — a sine profile in one axis, for tin sheets.
   - `weave` — a crossed pair of sine profiles, for fabric, plywood and rattan.
   - `wood_grain` — a warped ring function plus a lengthwise fibre term.
   - `circuit` — solder mask, copper traces on 45° bends, pads at cell corners, silkscreen ticks.
   - `panel_lines` — narrow recessed gaps, for concrete panels and sheet seams.
   - `tile_grid` — offset tiles with joints.

3. **Corrosion / paint loss.** A threshold on the `front` field set by the `wear` parameter, gated by
   the per-texel wear mask. Crossing the threshold lerps colour toward the corrosion tint, lifts
   metallic toward 1, raises roughness, drops height slightly and darkens occlusion. This is the pass
   that makes painted metal look used rather than dirty.

4. **Pitting.** Inverted Worley F1, so damage sits in cell centres; depth, roughness and darkening
   all scale with the `pits` parameter.

5. **Vertical streaks.** Rain and oil running down: a value-noise band along one axis combined with an
   FBM profile down the other, darkening colour, lowering roughness slightly (wet), raising height
   slightly.

6. **Micro-scratches**, on metals only. A stretched value-noise field thresholded to thin lines,
   lowering roughness and raising height a touch. Cheap, and the single detail that most persuades the
   eye that a metal surface has been handled.

### 2.4 Channel packing and normal derivation

Colour, occlusion, roughness and metallic are written into two `PackedByteArray`s in RGB8 layout and
uploaded with one `Image::create_from_data` each. The first implementation used `set_pixel()` per
texel; that alone was a measurable share of the 7.8 s original.

The tangent-space normal is derived by **Sobel gradient on the wrapped height field**:

```
dx = (h[x+1,y-1] + 2·h[x+1,y] + h[x+1,y+1]) − (h[x-1,y-1] + 2·h[x-1,y] + h[x-1,y+1])
dy = (h[x-1,y+1] + 2·h[x,y+1] + h[x+1,y+1]) − (h[x-1,y-1] + 2·h[x,y-1] + h[x+1,y-1])
n  = normalize(−dx·s, −dy·s, 1)
```

with `s = bump · 1.6`, then encoded as `n·0.5 + 0.5` into RGB8. The **index wrap** matters: sampling
at `(x−1+size) mod size` keeps the map tileable, which is required because every wall in the garage
repeats its texture between two and six times across its extent. A non-tiling normal map produces a
visible seam on every repeat.

### 2.5 Physical tiling and world-triplanar projection

This is the part that took a rendered screenshot to get right, and it is worth stating as a finding.

Primitive meshes in Godot carry 0..1 UVs. Scaling a `BoxMesh` to span a whole wall and applying a
texture therefore stretches exactly **one** texture repeat across it. The first render of the garage had
a single brick course painted over a 13 m elevation, which read as grey camouflage.

The solution has two halves.

**World-triplanar projection.** `BaseMaterial3D` exposes `uv1_triplanar` with `uv1_world_triplanar`,
which derives UVs from the object's world position instead of its mesh UVs. With that enabled,
`uv1_scale` stops meaning "repeats across the mesh" and starts meaning **"repeats per metre"** — so
the texture tiles at a genuine physical density regardless of the geometry.

**A declared metres-per-tile per surface.** Each recipe carries a physical tile size, stated once, in
metres, in `TextureFactory.TILE_METERS`, derived from the feature it represents:

| Surface | Tile size | Basis |
|---|---|---|
| `brick_wall` | 3.0 m | a 110 mm course, so 27 courses per tile: legible at wall distance |
| `concrete_block` | 4.0 m | a 400 mm block, 10 per tile |
| `cement_plaster` | 4.5 m | trowel-scale variation |
| `worn_concrete` | 6.0 m | a slab-scale pour |
| `corrugated_tin` | 2.6 m | a corrugation pitch of roughly 65 mm |
| `teak` | 1.9 m | grain-scale, since plank width is what matters |
| `circuit_board` | 0.34 m | a PCB is a small object; its traces must be fine |

`triplanar_sharpness` is raised to 2.4 above the default so the three projections do not smear at
corners, which is the usual giveaway of triplanar use.

The transferable finding: **triplanar projection without a declared physical scale only moves the
problem.** The change that fixed the garage was not the projection mode but deciding, per surface,
how many metres one repeat should cover, and then deriving the projection scale from that number.

### 2.6 The two-stage damping pass

The initial recipes were authored at 512 px with the assumption of roughly one repeat per metre. The
surface budget (below) forced 256 px, while the tile sizes above moved to three metres — so each texel
went from covering 2 mm to covering 12 mm, and the high-frequency fields became noise.

Rather than hand-correct 28 literals across the recipe table and risk missing one, the correction is
applied once, to every recipe, in `TextureFactory.recipes()`:

```
grain_scale × 0.45      noise features become 2.2× physically larger
height_amp  × 0.60      the height field stops competing with the albedo
bump        × 0.60      and the derived normal is correspondingly calmer
```

The eight architectural surfaces that carry the most screen area — brick, plaster, block, the three
concretes, earth, tin — are listed in `HAND_TUNED` and excluded, because their values are already
derived from the physical feature size above. What is left for the damping pass is the small props,
where a slightly noisy steel or plastic surface is a feature rather than a defect.

### 2.7 The surface budget, measured

`tests/timing_probe.gd` measures one surface at three resolutions. On the reference machine:

| Resolution | One surface | Extrapolated to 25 surfaces |
|---|---|---|
| 256 px | 440 ms | 11.0 s |
| 384 px | 1 006 ms | 25.1 s |
| 512 px | 1 716 ms | 42.9 s |

The cost is **not** dominated by noise: the C++ field generation and the GDScript fallback path
measure almost identically, which identifies the per-texel arithmetic loop as the bottleneck. It is
also linear in texel count, which is why 256 px is the default:

- `low` preset: `texture_scale 0.5` → 128 px
- `medium` preset: `texture_scale 1.0` → 256 px
- `high` preset: `texture_scale 1.5` → 384 px

Tiling hides the low resolution, because every wall repeats its map several times anyway and the
normal map carries the perceived detail.

**The honest limitation:** an interpreted per-texel loop for 65 536 texels is the wrong tool. Moving
this composite to a compute shader or a `RenderingDevice` shader pass is the single largest available
optimisation in the project, and it was not done. It is recorded as future work, not as a completed
claim.

---

## 3. Contribution B — Holographic projection shader

`shaders/hologram.gdshader`, `render_mode unshaded, cull_disabled, depth_draw_never, blend_mix`.

### 3.1 Composition

Four independent terms multiplied together, so the effect survives being viewed from any angle:

**Fresnel shell.**
```
fres  = pow(1 − dot(n, v), fresnel_power)
shell = mix(1, fres, rim_boost / (1 + rim_boost))
```
Grazing angles glow, faces-on stay transparent. This is what sells a thin light shell rather than a
flat decal, and it is the term that does most of the work.

**World-space scanlines.**
```
scan = 0.5 + 0.5·sin(axis·scan_density·2π + TIME·scan_speed·2π)
```
Critically, `axis` is taken from `world_pos`, not from UV. Scanlines therefore stay physically stacked
as the mesh rotates, and two holograms in the same room share one continuous sweep instead of each
carrying its own local pattern.

**Object-space interference grid.**
```
g    = fract(local_pos.xy·grid_scale + local_pos.z·grid_scale·0.5)
gw   = fwidth(local_pos.xy·grid_scale)          ← antialiased against the derivative
line = smoothstep(0, gw·1.6, g) · smoothstep(0, gw·1.6, 1−g)
grid = 1 − min(line.x, line.y)
```
The `fwidth` term is what stops the grid from aliasing into moiré at distance — without it the
hologram shimmers badly when the camera moves, which is the most common failure of grid-based effects.

**Temporal flicker.** A coarse hash of `floor(TIME·24)` combined with a slow 17 Hz × 3.7 Hz beat,
deliberately low-frequency so it reads as an unstable DIY projector rather than as noise. This is the
term that ties the effect to the project's premise: the hologram is improvised equipment.

**Travelling acquisition band.** `fract(axis·0.35 − TIME·scan_band_speed)` shaped by a smoothstep,
scaled by an `acquire` uniform so the band can be switched off for a static blueprint view.

### 3.2 Design decision: unshaded

The shader is `unshaded`. A hologram must not respond to the garage's fluorescent lights — a projection
that darkened when a lamp was switched off would break the illusion instantly. Skipping the PBR path
also means its cost is almost purely fill-rate, which is what Experiment 2 measures.

### 3.3 Six live parameters

`opacity`, `glow_strength`, `fresnel_power`, `scan_density`, `grid_scale`, `flicker_amount` are all
exposed as uniforms and all driven live from the graphics bench, together with a `wireframe_only` mode
that collapses the fill to the grid alone. Three evaluation variants are switchable for Experiment 2:
a plain transparent `StandardMaterial3D`, an emissive one, and this shader.

### 3.4 Where it is used

- The design table's hologram volume: a wireframe shell, three rotating rings, a projected floor grid,
  and a 14-piece miniature of the suit built from the *same* `ExosuitFactory.home_offset()` values the
  assembly uses, so the schematic and the built object cannot diverge.
- Three Bengali/English billboarded label plates.
- The reactor housing's diagnostic ring.
- The assembly platform's indicator strips and pod lenses (via a plain emissive material rather than
  the full shader, since those are small).

---

## 4. Contribution C — Energy-core emissive shader

`shaders/energy_core.gdshader`, also `unshaded`, with opaque depth so it can be occluded correctly.

### 4.1 Five terms

**Plasma churn.** Two 3-octave value-noise fBm evaluations, the second at 2.3× frequency and advected
through `TIME` at a different rate, mixed 55/45. The interior of the core therefore convects slowly
rather than being a flat glowing disc.

**Containment rings.** `abs(sin(r·ring_count·2π − TIME·ring_speed·2π))` raised to a sharpening power.
Because the ring phase is derived from the surface's local radius, the *same material* works on the
flat disc, the spherical body and the machined bezel ring without per-mesh adjustment.

**Radial spokes.** Angular modulation locked to the mesh's rotation, reading as the mechanical cage
around the plasma.

**Arc filaments.** Thresholded high-frequency noise that flickers per frame, scaled by an
`instability` uniform. This is the "salvaged, not factory" character.

**Fresnel shell.** The rim bloom that makes the core read as a glowing volume rather than a bright
flat shape.

### 4.2 The breathing pulse and dropout

```
pulse    = 1 + pulse_depth·sin(TIME·pulse_speed·2π)
dropout  = 1 − instability·0.5·step(0.97, hash13(floor(TIME·30)))
```

The rare hard dropout is a single hash comparison. It costs almost nothing and it is the detail that
makes the core read as improvised: a perfect sine pulse reads as a screensaver.

### 4.3 Noise implementation note

The shader contains its own `hash13`, `vnoise` and `my_fbm` rather than using the engine's `noise()`
builtin. The reason is portability of the visual result: `noise()` maps to a backend-dependent
implementation, and a shader whose appearance is the subject of an experiment should compile to the
same output on every driver it is tested on.

### 4.4 Effect on the rest of the scene

`glow_strength` is the parameter that matters most, because it feeds **bloom**, and bloom is
threshold-based at `glow_hdr_threshold = 1.45`. Below that threshold the core is a bright object; above
it, it spills a cyan halo onto the surrounding workbench, the brick wall and the suit's armour. All
four player-facing parameters — `glow_strength`, `pulse_speed`, `core_color`, `spin` — are exposed in
both the energy-core interaction panel and the graphics bench, and each drives a matching
`OmniLight3D` whose energy is animated alongside the shader so the emitted light and the visible
surface agree.

---

## 5. Contribution D — Procedural cable geometry

`scripts/procedural/cable_generator.gd`.

### 5.1 Why cables are worth generating

Cables are the highest visual-value-per-triangle content in an indoor workshop scene, and the slowest
to model by hand in a DCC package: a single loom run can take longer to author than a workbench. They
also have to change whenever the objects they connect move, which in a procedurally dressed garage is
always. Generation is therefore not a convenience here; it is the only practical approach.

### 5.2 Path construction

Cables are described by four physical parameters rather than by control points: **span** (start and
end), **sag** (midpoint drop), **slack** (arc-length inflation) and **sideways** (lateral bow).

```
p(t) = lerp(start, end, t) − up·sag·sin(πt) + lateral·sideways·sin(πt) − up·slack·sin(2πt)·0.5
```

The `sin(πt)` shaping keeps both endpoints exactly on their anchors while the middle sags, which is
what makes an anchor look attached. A hanging run of a *given* length is solved for the sag that
produces it by nine bisection steps against the polyline length — this is how the loose jumper cables
and the ceiling runs are generated, and it means a hang can be specified by "two metres of cable
between these two points" rather than by a sag value.

### 5.3 Parallel-transport framing

A tube needs a normal frame at every path sample. The obvious approach — take the tangent and cross it
with world up — **fails visibly**: wherever the tangent passes near the reference axis the frame flips
180°, producing a twisted seam and inverted UVs halfway along the cable.

The generator instead transports each frame from the previous one by the shortest rotation:

```
axis = normalize(prev_tangent × current_tangent)
angle = acos(dot(prev_tangent, current_tangent))
normal = normal.rotated(axis, angle)
binormal = current_tangent × normal
normal = binormal × current_tangent
```

This keeps the ribbing continuous along the whole run, which is exactly what the sleeve shader's weave
depends on. Without it, the weave breaks at every direction change.

### 5.4 Surface construction

Rings of `radial` vertices are emitted per path sample with **analytic** normals — the radial offset
minus a small tangent bias — rather than normals generated from the triangles. Generated normals on a
low-segment tube flatten the silhouette and destroy the weave alignment. The tube is closed with two
caps so a cut cable does not show a hollow interior.

`taper` narrows the tube quadratically along its length. It is a small parameter with a
disproportionate effect: perfectly constant-radius tubes read as extruded plastic, and real wire is
never constant.

### 5.5 Bundling as an optimisation

Several wires sharing a route are swept into **one** `ArrayMesh`. The loom from the switchboard to the
mechanical bench is four wires in one draw call; the workstation loom is four more in one. This is a
real draw-call reduction and Experiment 4 measures it.

### 5.6 Where it is used

Switchboard-to-bench loom (4 wires, 1 mesh), workstation loom (4 wires), IPS battery leads (3 wires),
the labelled reactor feed (a single thick conduit, 44 length segments), five ceiling runs hung between
beams, two loose jumper cables draped over shelves, plus coils, hoses and springs throughout the prop
catalogue which reuse the same sweep routine.

---

## 6. Contribution E — Interactive lighting

### 6.1 Kind of work

This is **built-in rendering features, extended by a control system**. Godot implements every light
type, shadow filter and global-illumination effect used here. What the project contributes is the
organisation: four independently switchable circuits with an explicit shadow budget and a coupling
between a moving architectural element and the interior lighting. That framing is what makes
Experiment 5 possible.

### 6.2 Circuit organisation

| Circuit | Contents | Purpose |
|---|---|---|
| 0 | Sun, courtyard bounce, window shafts, shutter-gap spot | always on |
| 1 | Five tube battens over World A and the store | warm, sequential energisation |
| 2 | Three task spots on bench, grinder and electronics bench | focused work light |
| 3 | Cool electronics pool, scope glow, store bulb, desk lamps | cool pool, contrast with circuit 1 |
| 4 | Core light, stand key, stand rim, holo pool, 4 pods, gantry, console glows | the futuristic zone |

`GarageRuntime.set_power()` brings them up **in sequence with 80 ms offsets**, and then replays two
false strikes on circuit 1: the tube lights reach 55% of target, drop to zero, reach 80%, drop to
zero, then hold. That is what a failing fluorescent starter does, it costs 0.4 s of Tween time, and it
does more for the room's believability than any amount of material work.

### 6.3 The shadow budget

**Seven of the thirty-one lights cast shadows.** The brief's constraint — *avoid hundreds of
real-time shadow-casting lights* — is applied as an explicit rule: the directional sun (4-split
cascades to 34 m), the core light (cube), the two tube battens over the working benches (cube), the
stand key spot, the shutter-gap spot and one task spot. Everything else is unshadowed.

The reasoning is that a shadow is only *readable* where there is a visible occluder and a surface to
receive it; filling the room with shadow casters raises cost and reduces clarity simultaneously.
Experiment 5 quantifies the cost difference.

### 6.4 Coupling shutter position to daylight

`GarageEnvironment.set_shutter_influence(amount)` is called every frame from
`GarageWorld._process()` with the runtime's current shutter amount, and it drives three things:

1. The shoot-gap spot's energy, `3.4 × amount`.
2. The two window shafts, `base × (0.55 + 0.45 × amount)`.
3. The volumetric fog density, `0.016 × (1 − 0.45 × amount)`.

The effect is that opening the shutter **fills the room with visible light shafts** and closing it
takes them away. This is the single most effective "this is a real room" cue in the project and it
costs one function call — the volumetric fog is already there, and the coupling just makes it
meaningful.

### 6.5 Two-zone contrast without neon

The design brief says the garage *should not look like a nightclub.* The rule applied here: the
futuristic zone is lit by **warm industrial key light plus the cyan core**, never by saturated coloured
fill. Circuit 1 is warm fluorescent (`#ffe6bd`) and circuit 3 is cool-white (`#cfe4ff`), both
near-white; the only strongly saturated sources are the energy core (`#7cf3ff`), the hologram pool and
the indicator LEDs, all of which are small-area emissive objects whose colour is *justified by what
they are.* The result is a warm half and a cool half of one room with a cyan mass in the middle, which
is the contrast the project wants, achieved without coloured ambient light.

### 6.6 Tone and post-processing configuration

| Setting | Value | Reasoning |
|---|---|---|
| `tonemap_mode` | AgX | keeps the emissive core from clipping to a white blob, where Filmic does not |
| `tonemap_white` | 2.6 | interior range, not outdoor |
| `glow_intensity` / `strength` | 0.32 / 0.48 | reduced from 0.62/0.9 after the first render put a white halo on every steel ring in the assembly bay |
| `glow_hdr_threshold` | 1.45 | raised so only the core and the hologram bloom |
| `glow_blend_mode` | Screen | additive reads as fog at these intensities |
| `ssao_radius` / `intensity` | 0.42 / 1.15 | small radius, for contact shadows on a 3 m wall |
| `ssao_light_affect` | 0.28 | prevents AO from flattening the light rig |
| `sdfgi_energy` | 1.0, 4 cascades | the core's cyan spilling onto brick is the effect the contrast depends on |
| `volumetric_fog_density` | 0.016, shutter-coupled | see §6.4 |

The bloom reduction is worth stating as a finding: bloom thresholds and intensities that look
reasonable in isolation can destroy a scene full of polished metal, because a low threshold makes
every specular highlight bloom. Raising the threshold from 1.05 to 1.45 and halving the intensity
recovered the metal and *increased* the core's visual impact, because the core was no longer competing
with chrome for the same bloom.

---

## 7. Supporting system F — Runtime audio synthesis

All 22 sounds are generated as PCM at first use and wrapped in `AudioStreamWAV`. No library.

| Technique | Applied to |
|---|---|
| Karplus-Strong delay line + inharmonic partials + noise transient | struck steel, tools, latches (6 variants across pitch and brightness) |
| State-variable band-pass resonator | servo whine, welding arc, gear grit |
| Additive phase-locked partial stack at 50/100/150/250/300 Hz | the mains hum — 50 Hz because Bangladesh runs 230 V 50 Hz |
| Filtered impulse train over a noise floor, looped | rain on corrugated tin |
| Biquad-filtered noise with an amplitude-scheduled RMS | fan bed, street murmur |
| Inharmonic sweep + sub swell | core charge |
| Additive ADSR bell stack, minor-to-major | assembly completion |

**The loop-point problem.** A naive noise bed produces an audible click at the wrap, because the last
sample does not continue from the first. Every looping sound is therefore built with *phase-coherent*
partials whose periods divide the buffer length exactly, so sample 0 continues the last sample's
phase. The rain bed is the exception — it is built from discrete drop events scheduled into a buffer
rather than from a continuous waveform, so wrapping is inaudible by construction.

Three buses (`Ambience`, `Effects`, `Interface`) with independent volumes, a compressor and a small
room reverb on the master, and 3D voices with inverse-distance attenuation plus a widening low-pass
that darkens distant sources.

---

## 8. Supporting system G — Procedural prop and layout generation

### 8.1 Mesh caching

`ShapeKit` keys every primitive on its dimensions and reuses the mesh. The garage builds 187 props
from **1 123 distinct meshes** with **1 772 cache hits** — a 1.6:1 reuse ratio, which is the difference
between a scene that runs on integrated graphics and one that does not.

### 8.2 Generators rather than primitives

Where a primitive is not enough, the shape is generated from parameters:

- **Lathe** — a surface of revolution from a 2D profile, used for tea glasses, bottles, funnels,
  silencer cans, bulb envelopes, spark plugs, wheel hubs, shade bowls, complete with profile-tangent
  normals and optional axis caps.
- **Gear** — an involute-approximating spur gear from tooth count, module, bore and thickness, with a
  real annular bore wall rather than a filled face. One function covers a bicycle freewheel, a motor
  pinion and the reduction gear inside the exosuit's elbow.
- **Tube sweep** — shared with the cable generator.
- **Coil, chain, plate with rolled edge, bolt with hex head and shank** — compound generators used
  throughout both worlds.

This is the difference between "a bottle prop" and "a bottle generator", and it is why the catalogue
reaches 130 prop kinds in four files.

### 8.3 Three-tier placement

Documented in `docs/SYSTEM_ARCHITECTURE.md` §4. The relevant graphics point: the **procedural** tier
uses rejection sampling against a minimum spacing *and* against the authored furniture's bounding
boxes, so scattered props never intersect each other or spawn inside a bench. The result is clutter
that reads as hand-placed without being hand-placed — and is identical on every run, because each
layout group carries its own seed.

### 8.4 A finding worth recording: the torus winding

`TorusMesh` in Godot is generated in the **XZ plane**. A torus physically encircling a *vertical*
cylinder therefore needs no rotation, and one encircling a *horizontal* axis needs π/2 about X.

The first implementation applied `rotation.x = π/2` to sixty-odd tori across the prop catalogues,
having copied the pattern from the wheel case where it is correct. The consequence was that every
collar, band, bearing race, insulation wrap, pipe clamp, bamboo node and reactor bezel in the garage
became a vertical hoop — most visibly, the assembly platform grew two enormous white arches that
dominated the establishing shot and read as scenery rather than as machinery.

The fix was to classify all sixty-one sites by which axis the ring actually encircles. The transferable
lesson, and the reason it is recorded here: **a rotation that is correct for one use of a mesh type is
not a property of the mesh type.** The same reasoning applies to `ShapeKit.disc()` (edge-on, facing
+Z) versus `ShapeKit.disc_flat()` (lying down, facing +Y), which are now separate functions precisely
because conflating them put every floor stain and tabletop decal upright.

---

## 9. What is not implemented

Stated so the boundary of the work is unambiguous:

- **No GPU timestamp queries.** All timing is CPU-side frame time plus the engine's documented
  monitors. Per-pass GPU cost is inferred from toggling, and Experiment 5 labels that inference.
- **No depth-based effects beyond those named.** No depth of field, no screen-space reflections beyond
  the SSR toggle, no motion blur, no TAA.
- **No baked lightmaps.** The lighting is fully dynamic, which is a cost this project pays rather than
  hides.
- **No LOD system.** Visibility range fade is used on small props; there is no mesh LOD generation.
- **No compute-shader path for surface synthesis**, which is the largest available optimisation.
- **No occlusion culling.** The scene is one room with a clear interior, so frustum culling does most
  of the work; a multi-room environment would require baking occluders.
