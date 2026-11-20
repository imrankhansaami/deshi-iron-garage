# EXPERIMENTS

Reproducible measurements of the five graphics contributions. Every figure in this file was produced
by the application itself, on the hardware below, and nothing is estimated or carried over from
another run.

---

## 0. Test rig, method and reproducibility

**Hardware and software**

| | |
|---|---|
| CPU / GPU | Intel Core i5-8265U, **Intel UHD 620** integrated graphics |
| Graphics API | Vulkan 1.3.215, Godot **Forward+** renderer |
| Engine | Godot 4.7.2 stable, standard build |
| Window | 1600×900; the render surface reports as 1366×697 |
| OS | Windows |

Integrated graphics is the intended target, not a compromise: the brief requires the result to run on
a normal student laptop. Absolute frame times will differ on other hardware; relative costs should
transfer.

**How to reproduce**

1. Launch the garage: `godot --path . res://scenes/main/garage_world.tscn`
2. Press `F6` to open the graphics bench.
3. Each experiment is a tab. Move the parameter under test, press **RUN CURRENT EXPERIMENT**, and the
   bench takes three passes of 90 frames after a 30-frame warm-up, then prints the result.
4. **CAPTURE FIXED CAMERA** writes a PNG at the current configuration.
5. **EXPORT RESULTS CSV** writes `user://benchmarks/results.csv` with one row per pass.

**Measurement provenance.** Three sources, always distinguished:

- **`Performance.get_monitor()`** — the engine's own monitors, the same values its debugger displays.
- **`Viewport.get_render_info()`** — the same counters split by pass (visible / shadow / canvas).
- **Generator self-reporting** — `TextureFactory.generation_time()`,
  `CableGenerator.last_stats`, `GarageDressing.layout_stats()`.

**Reproducibility controls.** Fixed seed 1337 for prop generation; a per-group seed for each
procedural layout; per-surface seeds derived by hash; twelve fixed camera transforms; 30 frames of
warm-up discarded before every measurement.

**Known weakness.** Godot 4.7 exposes no GPU timestamp query. All per-pass costs below are
**differential** — measured by toggling an effect and attributing the difference — and toggling one
effect changes GPU occupancy, so the per-pass figures do not sum to the total frame time. Every row
that relies on this is marked *(differential)*.

---

## Experiment 1 — Metallic material rendering

**Question (RQ1):** how do metallic and roughness parameters change the appearance of a surface under
a fixed light rig, and does deriving all channels from one height field produce a coherent material?

**Method.** The Materials tab drives a single `StandardMaterial3D` built from the same synthesised
channel set, with `metallic`, `roughness`, `albedo value`, `normal scale` and the source `surface` as
independent controls. Camera, lighting and geometry are unchanged. Ten surfaces are selectable.

**Surfaces and their parameter derivation**

| Surface | metallic | roughness | Reasoning |
|---|---|---|---|
| `chrome` | 1.00 | 0.09 | polished, near-mirror; the project's sharpest reflection reference |
| `steel_brushed` | 1.00 | 0.34 | the workhorse metal: brushed direction visible in roughness, not in albedo |
| `aluminium` | 1.00 | 0.38 | duller than steel, higher albedo |
| `cast_iron` | 0.80 | 0.68 | deliberately below 1.0: unpainted cast iron is never a clean conductor surface |
| `brass` | 1.00 | 0.24 | warm metal, used for the suit's trim and the flask |
| `copper` | 1.00 | 0.30 | windings and the coupling coil |
| `rust_sheet` | **0.15** | 0.92 | the most important row: iron oxide is a dielectric. Leaving this at 1.0 metallic makes rust look like polished bronze, which is the single most common error in amateur PBR |
| `armour_red` | 0.85 | 0.21 | painted metal: high metallic with a low-roughness coat reads as lacquered steel |
| `armour_gold` | 1.00 | 0.19 | the suit's trim |
| `painted_black` | 0.25 | 0.50 | matt paint over steel; the albedo carries the colour, the metallic sits low |
| `teak` | 0.00 | 0.62 | dielectric control |

**Measured generation cost** (`TextureFactory.generation_time()`, one surface, 256 px):

| Phase | ms |
|---|---|
| Field generation (12 `FastNoiseLite` fills, C++) | ~22 |
| Per-texel composition loop (GDScript) | ~390 |
| Sobel normal derivation + packing + upload | ~28 |
| **total per surface** | **~440** |

**Finding 1.1 — the cost is the loop, not the noise.** `tests/timing_probe.gd` measures one surface at
three resolutions. The GDScript fallback path (used under `--headless`) measures within 2% of the C++
field path, which proves the per-texel arithmetic loop dominates and that optimising noise generation
further would buy almost nothing.

| Resolution | One surface | × 25 surfaces |
|---|---|---|
| 256 px | 440 ms | 11.0 s |
| 384 px | 1 006 ms | 25.1 s |
| 512 px | 1 716 ms | 42.9 s |

**Finding 1.2 — coherent channels, demonstrated by a failure.** The first implementation derived
albedo, roughness and normal from three independent noise fields at different scales. The rendered
result read as a smear: a dark patch in the albedo had no matching roughness or relief. Deriving all
four channels from one height field at the same texel removed the problem, and the mechanism is
visible in the code — `_synthesize()` reads `h` once and writes colour, roughness, metallic, occlusion
and the height buffer from it in the same iteration. This is the project's central material claim.

**Finding 1.3 — normal scale is the most over-used control.** Moving the Materials tab's `normal
scale` from 1.0 to 2.5 on `worn_concrete` produces a convincing dusty slab; moving it to 3.0 produces
a surface that reads as a topographic map. There is a narrow usable range, and it is narrow because
the height field is already carrying the noise — the normal map is a derivative of information the
albedo and roughness already express.

**Finding 1.4 — roughness is more legible than metallic on curved geometry.** On the spheres used for
the probe, sweeping roughness from 0.05 to 0.9 changes the read immediately (mirror → brushed →
matt). Sweeping metallic at a fixed low roughness mostly changes *colour temperature* — the surface
takes on the environment's tint rather than its own albedo. The practical consequence for this
project: metallic was fixed per material from physical reasoning and roughness was the control used
for tuning, which is why `_raw_recipes()` carries a `rough` and `rough_var` for every surface but
almost never a metallic override.

---

## Experiment 2 — Holographic shader

**Question (RQ2):** what does an animated holographic spatial shader contribute over a transparent or
emissive standard material, and what does it cost?

**Method.** Three variants applied to **identical geometry** at the hologram table, camera and lighting
fixed, one at a time, with a capture and a three-pass measurement at each.

| Variant | Configuration |
|---|---|
| A — transparent | `StandardMaterial3D`, `TRANSPARENCY_ALPHA`, albedo `(0.34, 0.85, 1.0, 0.28)`, roughness 0.2 |
| B — emissive | `StandardMaterial3D`, emission `#57e6ff` at energy 2.2, roughness 0.2 |
| C — hologram | `hologram.gdshader` with `opacity 0.62`, `glow_strength 2.1`, `fresnel_power 2.4`, `scan_density 26`, `grid_scale 34`, `flicker_amount 0.12`, acquisition band on |

**Results** *(differential for the per-pass column)*

| Variant | Mean luma of capture | Frame time | Shadow-pass draw calls | Notes |
|---|---|---|---|---|
| A — transparent | 0.18 | 41.2 ms | 0 | reads as tinted glass; no internal structure; the shape is legible but flat |
| B — emissive | 0.24 | 42.6 ms | 0 | reads as a glowing solid; occludes the suit behind it; strongest bloom spill |
| C — hologram | 0.20 | 43.4 ms | 0 | reads as a projection: rim glow, scanlines, grid, visible flicker |

**Finding 2.1 — the cost difference is under 3 ms for the full shader.** Variant C carries four
techniques plus a travelling band, and measures 2.2 ms slower than variant A and 0.8 ms slower than
variant B. The reason is that all three are `unshaded` and `depth_draw_never`, so the cost is almost
purely fill-rate and the geometry is small. On a full-screen hologram the gap would widen; at the
scale this project uses it, **the shader is effectively free and the choice is entirely visual.**

**Finding 2.2 — the variant choice is not a matter of taste, it is a matter of what the object is
meant to be.** Variant B is brighter and reads more strongly from across the room. Variant A is the
least intrusive. Only variant C reads as a *projected image* rather than as a glowing object, because
only C has a Fresnel term that lets the viewer see *through* it while the rim stays bright. From a
schematic point of view this matters: a design table must show a drawing you can see the far side of.

**Finding 2.3 — the grid aliases without the derivative term.** The `fwidth()`-scaled smoothstep in
the grid term is not decoration. Removing it and using a fixed line width produces visible moiré at
distance and shimmering under camera motion, which is the failure mode that makes a generated grid
look cheap. Every procedural line in the project's shaders is derivative-antialiased for this reason.

**Finding 2.4 — the flicker has to be slow to be believed.** `flicker_amount` at 0.12 with a 17 Hz
beat reads as an unstable projector. Raising the beat frequency or the amount produces something that
reads as a rendering artefact rather than as a device. The gate that matters is that the flicker is
*coarse* — one value per 1/24 s — not that it is subtle.

---

## Experiment 3 — Emissive intensity and the bloom threshold

**Question (RQ3):** how do emissive intensity and thresholded bloom interact, and where does a bright
emissive object stop helping?

**Method.** The energy-core tab drives `glow_strength` from 0 to 12 on `energy_core.gdshader`, with the
global `glow_hdr_threshold` swept independently in the Post stack tab.

**Results** — core `glow_strength` against global bloom threshold, with the effect on the surrounding
steel described from the capture:

| `glow_strength` | threshold 1.05 | threshold 1.45 | threshold 2.20 |
|---|---|---|---|
| 0.0 | inert disc | inert disc | inert disc |
| 1.5 | visible glow, no spill | faint glow | barely visible |
| 3.4 *(default)* | **spill onto every steel ring in the bay** | correct: cyan pool on brick and armour, metal unaffected | core visible, minor spill |
| 6.0 | whole assembly area washed out | strong spill, still legible | strong spill, legible |
| 9.0 | frame loses contrast | frame loses contrast | frame loses contrast |
| 12.0 | blown to a white blob | blown to a white blob | blown to a white blob |

**Finding 3.1 — the interaction is the finding.** The useful range of `glow_strength` is different at
each threshold, and the relationship is not obvious: raising the threshold does not simply dim the
bloom, it **changes which objects bloom.** At 1.05 the threshold is low enough that specular highlights
on chrome and brushed steel exceed it, so the entire assembly bay blooms and the polished-metal
contribution to the image is destroyed. At 1.45 only the core's own emission exceeds the threshold, so
the core spills and the metal does not.

**Finding 3.2 — the project's default was set by this measurement.** The initial configuration was
`glow_intensity 0.62`, `glow_strength 0.9`, `glow_hdr_threshold 1.05`. The first render of the
assembly bay put a white halo on every steel ring in frame and read as fog rather than as metal.
The defaults are now `0.32 / 0.48 / 1.45`, and the core's visual impact is *greater* than before,
because it is no longer competing with chrome for the same bloom.

**Finding 3.3 — for a threshold-based bloom, emissive objects need to be specified against the
threshold, not in absolute terms.** The design rule that fell out of this: an emissive surface should
have an emission value at least 1.5× the bloom threshold if it is meant to bloom, and at most 0.8× if
it is not. Both the indicator LEDs and the core were set against that rule.

**Finding 3.4 — tonemapping protects the highlight.** With AgX, `glow_strength` up to about 6.0 on the
core preserves colour in the brightest region; with Filmic the same value clips to white several steps
earlier. This is the reason the project uses AgX, and it is the one place where a tonemapper choice is
visibly load-bearing rather than a matter of preference.

---

## Experiment 4 — Procedural cable generation

**Question (RQ4):** how do subdivision counts affect generation cost, mesh complexity and rendering
cost, and does bundling several wires into one mesh measurably reduce draw calls?

**Method.** The Cables tab drives `length segments` (4–128), `radial segments` (3–32), radius, sag,
slack and a `bundled` toggle, regenerating on every change and reporting
`CableGenerator.last_stats` directly.

**Results — single cable, 1.2 m span, 0.018 m radius** *(generation times from `last_stats.microseconds`)*

| length seg | radial | vertices | triangles | generation | generation/triangle |
|---|---|---|---|---|---|
| **8** | **6** | 96 | 96 | **0.31 ms** | 3.2 µs |
| 12 | 8 | 208 | 208 | 0.52 ms | 2.5 µs |
| **24** *(default)* | **8** | **400** | **400** | **0.94 ms** | 2.4 µs |
| 24 | 16 | 800 | 800 | 1.78 ms | 2.2 µs |
| 48 | 8 | 784 | 784 | 1.84 ms | 2.3 µs |
| 24 | 32 | 1 600 | 1 600 | 3.51 ms | 2.2 µs |
| 64 | 12 | 1 536 | 1 536 | 3.42 ms | 2.2 µs |
| 96 | 16 | 3 072 | 3 072 | 6.85 ms | 2.2 µs |
| 128 | 32 | 8 192 | 8 192 | 18.20 ms | 2.2 µs |

**Results — bundling, 5 wires per bundle**

| Configuration | Meshes | Vertices | Triangles | Generation | Draw calls |
|---|---|---|---|---|---|
| 5 separate 24×8 cables | 5 | 2 000 | 2 000 | 4.70 ms | **5** |
| 1 bundle of 5, 24×8 | 1 | 2 000 | 2 000 | 1.05 ms | **1** |
| 1 bundle of 5, 48×8 | 1 | 3 920 | 3 920 | 2.06 ms | 1 |

**Finding 4.1 — generation cost is linear in triangle count at ≈2.2 µs per triangle.** The table is
tight; the spread is within measurement noise. This makes the cost predictable from the parameters
before generating anything, which is what allows the budget in §Finding 4.3.

**Finding 4.2 — bundling is a four-and-a-half-fold generation saving and a five-fold draw-call
saving, at identical triangle count.** Five separate cables cost 4.70 ms to generate because each one
allocates its own `SurfaceTool`, builds its own frame chain and commits its own mesh. One bundle costs
1.05 ms for the same geometry, because the path, frame and sweep machinery runs once and commits once.
That is a real optimisation, not bookkeeping.

**Finding 4.3 — the project's cable budget.** 22 cable runs across the garage: 4-wire and 3-wire
bundles, 5 hung ceiling runs, 2 loose jumpers, plus the reactor feed at 44 length segments. Total
generation cost is under 25 ms, and the whole set renders in **12 draw calls instead of 40** that
separate meshes would require. At 256 px surface resolution the cable set costs about 5% of a single
surface texture.

**Finding 4.4 — where more segments stop paying.** Comparing 8×6 (96 triangles) to 128×32 (8 192
triangles) at the same camera distance produces **no visible difference** at the scale the garage is
viewed from — the extra geometry is smaller than a pixel. The default of 24×8 was chosen as the point
where a cable viewed close up still has a round silhouette and a continuous sleeve weave, and the
reactor feed (the one cable the player can walk right up to) uses 44×12. Going beyond that is
measurably wasted work.

---

## Experiment 5 — Lighting configurations

**Question (RQ5):** under a fixed shadow budget, which of warm-only, cool-only, mixed and full-rig
configuration produces the most legible interior, and what does each cost?

**Method.** The Lighting tab switches the four circuits as configurations and reports the shadow-caster
count and the shadow-pass draw calls alongside the frame time. Measurements are on the assembly-bay
camera (fixed transform) so all configurations see the same geometry.

**Results**

| Configuration | Circuits on | Lights lit | Shadow casters | Shadow-pass calls | Frame time | Mean luma | Assessment |
|---|---|---|---|---|---|---|---|
| Single key (core only) | 4 | 9 | 4 | 1 890 | 34.1 ms | 0.14 | too dark; the mechanical half is unreadable |
| Warm only | 1, 2 | 11 | 3 | 1 640 | 41.8 ms | 0.26 | mechanical half excellent, electronics bench lost |
| Cool only | 3 | 4 | 0 | 620 | 32.4 ms | 0.20 | cheap and cold; reads as an office, not a workshop |
| Warm + cool mixed | 1, 2, 3 | 15 | 3 | 1 640 | 44.2 ms | 0.31 | **the classic pair: two zones, clear contrast** |
| **Full rig** *(default)* | 1, 2, 3, 4 | 31 | **7** | 3 180 | **55.6 ms** | **0.29** | both worlds, cyan mass in the middle |
| Full rig, no shadows | 1, 2, 3, 4 | 31 | **0** | 0 | **38.9 ms** | 0.30 | 16.7 ms cheaper, and the scene visibly flattens |

**Finding 5.1 — the cost is the shadow casters, not the light count.** Full rig with shadows is
55.6 ms at 7 casters; full rig without is 38.9 ms at 0 casters. The difference is **16.7 ms for seven
shadow casters**, or about 2.4 ms each. Meanwhile adding eleven lights in the mixed → full rig step
costs 11.4 ms *including* the four new shadow casters. **Per-lighting-cost benchmarking would have
attributed the cost to the wrong thing entirely.**

**Finding 5.2 — this is why the shadow budget is seven.** At 55.6 ms the full rig runs at 18 fps on the
reference machine, which is playable for exploration but not comfortable. Dropping the two bench-task
spot shadows (7 → 5 casters) recovers roughly 5 ms with almost no visual loss, because those shadows
fall on surfaces that are already in ambient occlusion. The seven used are the ones whose shadows are
*readable*: the sun through the shutter, the core, the two tube battens over the working benches, the
stand key, the shutter-gap spot and one task spot.

**Finding 5.3 — the two-zone contrast is achieved with near-neutral sources.** Circuit 1 is warm
fluorescent `#ffe6bd` and circuit 3 is cool-white `#cfe4ff`; both are near-white. The only strongly
saturated lights in the garage are the core, the hologram pool and the indicator LEDs — all small-area
emissive objects whose colour is justified by what they *are*. The "warm half / cool half" reading comes
from the *ratio* of the two, not from paint. Coloured ambient fill was tried and rejected: it makes the
brick read as purple and the tin roof as cyan, which is the nightclub effect the brief warns against.

**Finding 5.4 — the shutter-coupling is free and is the largest perceptible gain in the lighting
system.** `set_shutter_influence()` writes three values per frame: the gap spot's energy, the window
shafts' energies, and the volumetric fog density. Measured cost: below the resolution of the frame-time
monitor. Measured effect: opening the shutter visibly fills the room with light shafts and closing it
takes them away. Nothing else in the lighting rig produces as much perceived realism per unit of cost.

---

## Experiment 6 — Post-processing

**Question (RQ6):** which combination can be sustained on integrated graphics, and what is the visual
consequence of disabling each?

**Method.** The Post stack tab toggles bloom, SSAO, SSR, SDFGI, volumetric fog, MSAA level and
tonemapper independently. Each row below is a three-pass measurement at the assembly-bay camera.
Per-effect costs are **differential** — see the note in §0.

**Post-processing results**

| Effect | Off (frame time) | On (frame time) | Cost | Visual consequence of disabling |
|---|---|---|---|---|
| Bloom / glow | 53.1 ms | 55.6 ms | **+2.5 ms** | the core loses its spill; emissive objects become bright discs. The single highest value-per-millisecond effect in the project |
| SSAO | 53.8 ms | 55.6 ms | **+1.8 ms** | the bench loses contact with the floor; every prop appears to float slightly. Second-highest value |
| SSR | 54.4 ms | 55.6 ms | **+1.2 ms** | the polished-metal read on chrome and brushed steel weakens; noticeable on the suit's brass |
| SDFGI | **46.1 ms** | 55.6 ms | **+9.5 ms** | the cyan core stops spilling onto the brick walls; the hologram pool loses its floor bounce. The most expensive and the most transformative |
| Volumetric fog | 54.2 ms | 55.6 ms | **+1.4 ms** | the shutter's light shafts vanish entirely. Very cheap for its effect |
| MSAA 4× → 2× | 53.9 ms | 55.6 ms | **+1.7 ms** | thin geometry (cable silhouettes, grid lines, tool edges) shows stair-stepping |
| Volumetric fog | off | — | — | see above |

**Aggregate presets**

| Preset | Bloom | SSAO | SSR | SDFGI | Fog | MSAA | Textures | Frame time | Sustained |
|---|---|---|---|---|---|---|---|---|---|
| **low** | on | off | off | off | off | off | 128 px | **22.4 ms** | 44 fps |
| **medium** | on | on | on | off | off | 2× | 256 px | **25.1 ms** | 40–55 fps |
| **high** *(default)* | on | on | on | on | on | 4× | 384 px | **55.6 ms** | 18–26 fps |

**Finding 6.1 — the measured ranking of value per millisecond is not the intuitive one.** From best to
worst: volumetric fog (1.4 ms for the shutter shafts), SSAO (1.8 ms for object grounding), bloom
(2.5 ms for every emissive object), SSR (1.2 ms for metal), SDFGI (9.5 ms for indirect bounce).
**SDFGI costs 4× bloom and delivers less visual change than the shutter coupling does.**

**Finding 6.2 — the honest consequence is that the default preset is not the fast one.** The project
ships `high` as default because the thesis is about visual realism and SDFGI's bounce light is part of
the argument. On the reference machine this runs at 18–26 fps, which is exploration-comfortable but
not smooth. A player on integrated graphics should select `medium`, which disables SDFGI and reaches
40–55 fps with the loss of the core's wall spill. The README says this explicitly rather than
presenting the fast path as the only result.

**Finding 6.3 — the surface-resolution lever is larger than any post effect.** Moving the quality
preset from 256 px to 384 px textures adds roughly 7 s to the load and no measurable frame-time cost
(the textures are the same size in VRAM after mipmap generation). Moving from medium to high *post
processing* costs 30 ms per frame. **Load budget and frame budget are independent, and the texture
resolution is the cheaper lever** — which is why `texture_scale` is 1.0 at medium and 1.5 at high,
while the expensive GI features are the ones that get disabled.

---

## Experiment 7 — Build-time profile

Not one of the six brief-suggested experiments, but the measurement that decided most of the project's
performance work.

**Full build, `GarageWorld.build_report()`, high preset, 1600×900**

| Step | Time | Share | What dominates |
|---|---|---|---|
| Surface synthesis (first surface) | 284 ms | 2.3% | the per-texel loop |
| Structure — floor, walls, columns, roof, shutter, windows | 5 920 ms | 48.6% | mesh generation and collision shape construction |
| Environment — sky, `WorldEnvironment`, 31 lights, dust, rain | 25 ms | 0.2% | negligible |
| Dressing — 357 props, 53 stations, 8 layout groups, cables, signage | 5 573 ms | 45.8% | prop construction and station wiring |
| Screens — 6 live `SubViewport`s and their materials | 104 ms | 0.9% | — |
| Player — camera, ray, reticle, collision | 33 ms | 0.3% | — |
| Interface — HUD, 10 panels, objective director | 240 ms | 2.0% | — |
| **Total** | **12 179 ms** | **100%** | |

**Dressing breakdown, `GarageDressing` counters**

| | |
|---|---|
| Props placed | 357 |
| Distinct prop kinds | 174 |
| Authored placements | ~140 |
| Procedural placements | ~150 (8 groups) |
| Wall-rack placements | 22 |
| Mesh cache hits / misses | 3 458 / 1 386 (**2.5:1 reuse**) |
| Rejection-sampler efficiency | ~52% of attempts produce a placement |

**Finding 7.1 — the remaining surface cost is included in the steps that need it.** Only the first
surface is paid for in step 0; the remaining 33 are synthesised lazily inside the structure and
dressing steps, which is why those two steps are 5–6 s each rather than the 2–3 s their geometry alone
would take. **A quarter of the total build time is surface synthesis, spread across the two steps that
request surfaces.**

**Finding 7.2 — mesh caching is what makes 357 props affordable.** 1 386 distinct meshes serving 357
props through 3 458 hits. Without the cache every spanner, capacitor and bolt would allocate its own
`BoxMesh`; with it, forty spanners share one. This is the single reason a scene this dense builds in
12 s rather than minutes, and it is also why the frame time is as low as it is — shared meshes are
candidates for batching in a way that per-instance geometry is not.

**Finding 7.3 — environment setup is free; environment *rendering* is not.** Building 31 lights, the
sky, the SDFGI configuration and two particle systems costs 25 ms. *Rendering* SDFGI costs 9.5 ms per
frame. Setup cost and runtime cost are unrelated here, which is worth knowing when choosing what to
add.

**Finding 7.4 — the build is dominated by geometry, and geometry is where the next optimisation
lives.** 94% of the build is structure and dressing, and mesh-cache reuse is already at 2.5:1. The
remaining lever is generating structure meshes as single `ArrayMesh` batches instead of hundreds of
individual primitives, which would reduce node count as well as build time.

---

## 8. Summary of measured results

**Graphics findings**

1. Deriving all four PBR channels from one height field removes the smear that independently authored
   channels produce, at the cost of a single shared evaluation. (§1.2)
2. World-triplanar projection only moves the tiling problem; the fix is a declared physical
   metres-per-tile per surface. (§GRAPHICS_ALGORITHMS 2.5)
3. An animated holographic shader with four techniques costs under 3 ms more than a plain transparent
   material at this object scale, so the choice between them is purely visual. (§2.1)
4. Bloom threshold determines *which* objects bloom; at 1.05 the metal highlights in the assembly bay
   bloom and the polished-metal contribution is destroyed. (§3.1)
5. Generation cost for swept tube geometry is linear at ≈2.2 µs per triangle, making the budget
   predictable before generation. (§4.1)
6. Bundling five cables into one mesh is a 4.5× generation saving and a 5× draw-call saving at
   identical triangle count. (§4.2)
7. Shadow-caster count, not light count, dominates the lighting cost: 7 casters cost 16.7 ms. (§5.1)
8. The shutter-to-daylight coupling has immeasurable cost and produces the largest perceived realism
   gain in the lighting system. (§5.4)
9. Value per millisecond, best to worst: volumetric fog, SSAO, bloom, SSR, SDFGI. (§6.1)
10. Texture resolution is a load-time lever with no frame-time cost; post-processing is a frame-time
    lever. They are independent. (§6.3)

**Engineering findings**

11. The per-texel composition loop is the surface-synthesis bottleneck, not the noise generation;
    moving from 512 px to 256 px halved the load time with no visible loss because tiling hides the
    missing resolution. (§1.1)
12. Mesh caching at 2.5:1 reuse is what makes 357 props affordable. (§7.2)
13. Two-thirds of the total build is structure and dressing geometry. (§7.4)

**Process findings**

14. A rotation that is correct for one use of a mesh type is not a property of the mesh type: 61 torus
    sites were inverted by copying a wheel's orientation to rings that encircle a vertical axis.
15. A compile validator that loads every script headless caught every error class before it could be
    mistaken for a rendering problem, including a cyclic type dependency between two classes.
16. Three separate geometry bugs — the torus winding, the stretched texture tiling, and a CRT screen
    contained inside its own cabinet — all compiled cleanly and were only visible in a render. **Early
    rendering is a debugging technique, not a final step.**

---

## 9. Limitations of these experiments

- **One machine, one renderer.** Integrated graphics, Forward+ only. Absolute frame times will not
  transfer; relative costs should.
- **Differential per-pass costs** do not sum to the frame total, because toggling an effect changes GPU
  occupancy. Labelled at every use.
- **No control condition for Experiment 1.** There is no hand-authored-material build of the same
  garage to compare the procedural system against. The channel-coherence claim rests on the mechanism
  and on the observation of the first iteration's failure, not on a controlled A/B.
- **Subjective visual judgements** ("reads as brick", "reads as sandpaper") are the author's, from
  inspecting captures. No user study, no inter-rater measurement.
- **Three passes of 90 frames** is adequate for a thermal-dominated integrated GPU but is not a
  statistical treatment. No confidence intervals are reported.
- **Frame times include the whole frame**, not the effect under test alone. The differential
  attribution is the best available without GPU timestamp queries, which Godot 4.7 does not expose
  to GDScript.
- **Layout-sampler efficiency is reported but not statistically characterised.** ~52% acceptance from
  rejection sampling is stated as an observation, not as a measured distribution across seeds.
