# RESEARCH METHODOLOGY

## 1. Research questions

The project is framed as an implementation and integration study rather than as an algorithmic
discovery. Its questions are therefore about the behaviour of known techniques under a specific,
constrained combination.

**RQ1 — Channel coherence.** Does deriving albedo, roughness, occlusion and normal from a single
shared height field produce a measurably more coherent surface than independently authored channels,
and at what generation cost?

**RQ2 — Holographic representation.** What does an animated holographic spatial shader contribute
visually over a transparent or emissive `StandardMaterial3D`, and what does it cost?

**RQ3 — Emissive scale.** How do emissive intensity and threshold-based bloom interact, and at what
intensity does an emissive object stop reading as a light source and start destroying the metal
around it?

**RQ4 — Procedural curve geometry.** How do subdivision count and radial segment count affect the
generation cost and rendering cost of procedurally swept tube geometry, and does merging several tubes
into one mesh measurably reduce draw calls?

**RQ5 — Interactive lighting.** Under a fixed shadow budget, which of warm-only, cool-only, mixed and
full-rig configurations produces the most legible interior, and what does each cost?

**RQ6 — Post-processing cost.** Which combination of bloom, ambient occlusion, screen-space
reflections, global illumination, volumetric fog and anti-aliasing can be sustained on integrated
graphics, and what is the visual consequence of disabling each?

A seventh question runs underneath all of them, and is the reason the project exists in this setting:

**RQ7 — Procedural sufficiency.** Is it possible to build a visually credible, culturally specific,
interactive indoor environment with **no imported 3D model, no photographic texture and no audio
library**, on a normal student laptop, and what are the specific techniques that make that possible?

## 2. Method

### 2.1 Design of the artefact

A **design-and-build** methodology. The artefact is the instrument: it must be complete enough to be
measured, and instrumented enough to measure itself.

That second requirement shaped the architecture. The graphics bench is not a debug panel bolted on at
the end; it is a first-class scene in the application, with six tabs, 34 live parameters and 18 real
performance monitors, because a research question about material parameters requires those parameters
to be *addressable at runtime* for the comparison to be possible at all. A hard-coded material cannot
answer RQ1.

The same reasoning applies to the lighting: four independently switchable circuits exist as an
architectural feature precisely so that RQ5's configurations are selectable without recompiling.

### 2.2 Instrumentation

Three independent measurement sources, deliberately not mixed:

**Engine performance monitors** — `Performance.get_monitor()`. FPS, process time, physics time, draw
calls, objects in frame, primitives in frame, video memory, texture memory, buffer memory, node count,
orphan node count, resource count, pipeline compilation counts. These are the same values Godot's own
debugger displays, so they are directly comparable to any other Godot project.

**Per-pass render information** — `Viewport.get_render_info(type, info)`. The same counters split by
pass (visible, shadow, canvas), which is how the shadow cost is isolated from the total. This is the
only way to attribute draw calls to the shadow pass specifically rather than inferring it.

**Generator self-reporting** — the three procedural systems time themselves and expose the result.
`TextureFactory.generation_time(key)` returns per-surface milliseconds; `CableGenerator.last_stats`
returns microseconds, vertex count, triangle count, arc length and bounding volume for the mesh just
built; `GarageDressing.layout_stats()` returns per-layout requested/placed/attempts, so the rejection
sampler's efficiency is a reported number rather than an assumption.

Every figure in `docs/EXPERIMENTS.md` comes from one of those three, with its source labelled.
**Nothing is estimated, and nothing is carried over from a previous run or a different machine.**

### 2.3 What is not measured, and how that is handled

**Per-pass GPU time is not available.** Godot 4.7 exposes no timestamp query through GDScript. Every
per-pass cost in this project is therefore an **inference from toggling**: measure the frame time with
an effect on, measure it with the effect off, attribute the difference. That is a legitimate
differential measurement but it has a known weakness — toggling one effect changes the GPU's occupancy
and can change the cost of the others, so the differences do not sum to the whole. Experiment 5
states this limitation where it applies rather than presenting the numbers as additive.

**Draw calls are counted, not attributed,** at the individual-object level. The engine reports the
total for the frame; the project can say how many draw calls the cable bundling saved (because it
builds one mesh where it would otherwise have built five) but cannot attribute the remaining calls to
specific props without per-node instrumentation the engine does not provide.

**No GPU vendor counters.** No Nsight, no RenderDoc, no vendor profiler. The reference machine is
integrated graphics with a Vulkan 1.3 driver that exposes the standard feature set; anything requiring
a vendor tool was out of scope.

### 2.4 Reproducibility controls

Four mechanisms, because an experiment that cannot be repeated is an anecdote:

**Seeded generation.** `PropFactory` takes a fixed seed (1337). Every procedural layout group carries
its own seed in `data/workshop_objects.json`. `TextureFactory` derives a per-surface seed from a hash
of the surface key plus a fixed base, so a surface is byte-identical across runs and across machines
at the same resolution. Rain, dust and footstep variation use separate seeds so changing one cannot
perturb another.

**Fixed camera positions.** Twelve declared transforms, used by both the capture harness and the
graphics bench. This is what makes two screenshots comparable between code revisions.

**Fixed warm-up.** Every measurement run discards 30 frames before sampling and then takes three
independent passes of 90 frames each, reporting all three. The first version sampled immediately and
produced numbers dominated by shader compilation; discarding the warm-up removed the largest source of
variance in the data.

**Recorded configuration.** Every measurement records the quality preset, the resolution, the renderer
and which effects were enabled, because a frame time without those is meaningless.

### 2.5 Stated hardware

All results are from one machine, and this is a limitation of the study rather than a detail:

- **CPU/GPU:** Intel Core i5-8265U with **Intel UHD 620** integrated graphics
- **API:** Vulkan 1.3.215, Forward+ renderer
- **Resolution:** 1600×900 (the engine's internal surface reports as 1366×697 at that window size)
- **OS:** Windows, Godot 4.7.2 stable

Integrated graphics is the *appropriate* target for this project, not a compromise: the brief requires
that the result run on a normal student laptop, and measuring on a discrete GPU would answer a
question nobody asked. It does mean absolute frame times will differ substantially on other hardware,
while the *relative* costs between configurations should transfer.

## 3. Evaluation design

### 3.1 Visual evaluation

Where a question is about appearance rather than cost, the evaluation is a captured image at a fixed
camera position, and the comparison is between two configurations that differ in exactly one
parameter. This is why the graphics bench exposes one slider per parameter rather than presets:
presets would make the comparison unreproducible.

Each capture is accompanied by a luminance histogram computed in the harness — mean luma, percentage
of near-black pixels, percentage of clipped pixels. Those three numbers are a crude instrument, but
they catch the failure mode that matters most and that no amount of code review reveals: **a scene
that renders almost nothing still produces a screenshot.** A mean luma below 0.02 is reported as a
warning by the harness, and a clipped percentage above a few percent indicates that bloom or exposure
needs attention. During development this check caught three real problems — an all-black first render,
an unlit garage after a material failure, and blown highlights on polished metal.

### 3.2 Cost evaluation

Three passes of 90 frames after a 30-frame discard, reported individually so variance is visible. For
configuration comparisons the frame time, the draw calls and the shadow-pass draw calls are recorded
together, because a configuration that halves the lights but raises the shadow casters will show up as
a draw-call increase even while the frame time improves.

### 3.3 Correctness evaluation

Not a research question, but necessary for the others to mean anything:

- **Compile validation:** `tests/validate_scripts.gd` loads all 37 scripts headless. Every class of
  error encountered during development — parse errors, type inference failures, wrong engine enum
  names, method-signature mismatches, duplicate function names, cyclic type dependencies — was caught
  by this before it could be mistaken for a rendering problem.
- **Full run:** the capture harness boots the real renderer, applies the whole twelve-step progression,
  and confirms every subsystem reached its end state, because a "successful" build that never powered
  the lights would otherwise pass a compile check.
- **Environment integrity:** UTF-8 validation of every source and data file, since Bengali content
  passed through several rounds of scripted edits and a silently mangled encoding would be invisible
  in a console that cannot render the script.

## 4. Threats to validity

**Single machine.** Stated above. Relative costs should transfer; absolute frame times will not.

**Single renderer.** Forward+ only. The project is configured to fall back to Mobile, but the Mobile
path was not measured, so compatibility-mode performance is unknown.

**No baseline comparison.** There is no control condition: the project does not build the same garage
with hand-authored materials to compare against. RQ1 is answered by the *coherence argument* and by
the observation of what went wrong in the first iteration, not by a measured side-by-side against a
painted-channel control. A stronger study would build that control, and this is recorded as a
limitation rather than glossed.

**Subjective visual judgement.** "Reads as brick" and "looks like sandpaper" are the author's
judgements from inspecting captures. There is no user study, no Likert rating, no inter-rater
agreement. The project reports the reasoning behind each visual decision and the measurement that
motivated it, and does not claim the decisions are optimal.

**Sample count.** Three passes of 90 frames is adequate for an integrated GPU where frame time
variance is dominated by thermal state rather than by the workload, but it is not a rigorous
statistical treatment. No confidence intervals are reported because the sample is not designed to
support them.

**Inference for per-pass GPU cost.** See §2.3. This is the weakest measurement in the study and it is
labelled wherever it appears.

**Build-time measurement includes disk I/O.** The 10.6 s build figure includes writing the generated
textures to the GPU. On a machine with a slower bus this would be higher; the *step* breakdown is more
transferable than the total.

## 5. Relationship between the artefact and the claims

The project claims implementation, integration, parametrisation and measurement — not new algorithms.
The consistency this requires is that **every claim in the documentation must be traceable to running
code.**

The traceability is explicit:

| Claim | Verification |
|---|---|
| Channel coherence from a shared height field | `TextureFactory._synthesize()` — one loop writes all four channels from `h` |
| Physical tiling density | `TextureFactory.TILE_METERS` plus `MaterialLibrary.surface()` setting `uv1_world_triplanar` |
| Four techniques in the hologram | `shaders/hologram.gdshader` — four named terms, six live uniforms |
| Five terms in the core | `shaders/energy_core.gdshader` |
| Parallel-transport framing | `CableGenerator.parallel_transport_frames()` |
| Bundling saves draw calls | `CableGenerator.generate_bundle()` — one `SurfaceTool`, one `commit()` |
| Seven shadow casters of 31 lights | `GarageEnvironment` registers 31; the bench reports the caster count |
| Shutter drives the daylight | `GarageEnvironment.set_shutter_influence()`, called from `GarageWorld._process()` |
| 352 props, 174 kinds | `GarageWorld.build_report()` |
| Screen content reads the simulation | `ScreenContent._snapshot()`, called by every screen and every panel |

Anything that is a **limitation** is listed in `README.md` §10 and `docs/GRAPHICS_ALGORITHMS.md` §9,
in the same document that states the claims. The exosuit is posed not rigged. The surface synthesis is
interpreted not parallel. SDFGI costs more than the reference machine can comfortably afford. Those
are as much a part of the method as the results are.

## 6. Development methodology

Recorded because it is the honest account of how the artefact reached its current state, and because
the failure modes are instructive.

**Validation-first.** The compile validator was written before the second system, on the principle that
a 37-script project cannot be debugged by reading error output from the game. It paid for itself within
one working session: it caught the incorrect Godot 4 function names (`sinf` for `sin`), missing engine
classes (`BaseTexture3D`), wrong enum locations (`TextureFilter` living on `BaseMaterial3D`), a
`Node.log()` name collision that shadowed a built-in, a `System.signal` keyword collision, and a cyclic
type dependency between `Station` and `GarageRuntime` that Godot refuses to compile and reports
unhelpfully.

**Render-early.** The first render was attempted as soon as the scene would boot, before the props were
complete. It was almost black, and the three subsequent iterations each surfaced a class of problem
that no amount of code reading would have found: the torus winding (§8.4 of the algorithms document),
texture tiling that stretched one brick course across thirteen metres, and a CRT whose screen was
geometrically inside its own cabinet. **Each of those compiled cleanly.**

**Differential measurement for tuning.** The texture damping pass exists because a measurement said so.
One 512 px surface cost 440 ms at 256 px and 1 716 ms at 512 px, which identified the per-texel loop as
the bottleneck and made resolution the lever. The bloom threshold moved from 1.05 to 1.45 because the
first capture showed halos on every steel ring in the assembly bay. Neither change was a matter of
taste.

**Version control after the first loss.** Four prop catalogue files were destroyed by an invalid
regular expression in a scripted edit — an unescaped `)` made the replacement throw and write an empty
file, with no backup and no repository. They were rewritten from scratch, which took a working session
and was entirely avoidable. The repository was initialised immediately afterwards and every subsequent
change was committed.

**Instrumentation over assertion.** Every time a claim was about to be made, the first attempt was to
make it measurable. "The build is fast enough" became per-step timings. "The lighting looks good"
became twelve fixed shots with luminance histograms. "The cables are efficient" became
`last_stats` with a triangle count and a draw-call count. Where a thing could not be measured it is
labelled as a judgement.
