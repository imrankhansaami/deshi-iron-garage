# DESHI IRON GARAGE — The Dream of a Bangladeshi Inventor

An interactive, real-time 3D workshop experience built in **Godot 4.7.2** with **typed GDScript**,
for an undergraduate Computer Science and Engineering computer graphics thesis.

**Genre:** first-person workshop exploration and prototype assembly
**Renderer:** Forward+ (Vulkan), with a Mobile fallback
**Target:** 45–60 fps on integrated graphics (Intel UHD 620 measured)
**Domain:** computer graphics — real-time indoor environment rendering and interaction

---

## 1. What this is

A young Bangladeshi engineering student has converted a tin-roofed repair shop into a workshop
laboratory. The player explores that garage, restores its power, reads the inventor's notebook,
salvages three components from donor machinery, raises a holographic schematic, and assembles an
original exosuit prototype on a circular assembly stage — then runs a diagnostic pass on it.

The project's argument is a graphics argument, not a story argument: **realism in a constrained
environment comes from coherent procedural material and light**, not from a large asset budget. Every
surface, prop, cable, shader and sound in the garage is generated at runtime from code. There is no
downloaded model pack, no photograph-based texture set and no audio library. That constraint is the
thesis.

It is not a rendering: it is a running application with a first-person controller, twelve objective
steps, an interactive workstation interface, and a live graphics bench that measures the renderer it
is running on.

---

## 2. How to run it

Requires **Godot 4.7.x stable** (standard build, not .NET). No plugins, no external dependencies.

```bash
# open in the editor
godot --path .

# or run directly
godot --path . res://scenes/main/main_menu.tscn

# or jump straight to the garage, skipping the title screen
godot --path . res://scenes/main/garage_world.tscn
```

The first launch builds the garage: surface synthesis, then the shell, lighting rig, 175 props,
screens and interfaces. On the reference machine (Intel UHD 620, 1600×900) the measured build is
**10.4 s**, reported on screen step by step and written to a log.

On first run the quality preset is `high`, which raises texture resolution and enables SDFGI, SSR and
volumetric fog. If the machine struggles, `medium` halves the surface work and turns off the
global-illumination features; the Settings panel switches it live.

### Capture / verification mode

Dropping an empty file named `capture.flag` next to `project.godot` puts the world into verification
mode: it drives the whole twelve-step progression, then parks the camera at twelve fixed viewpoints
and writes a PNG plus a luminance histogram for each, then quits. The files land in `user://captures/`
(`%APPDATA%\Godot\app_userdata\Deshi Iron Garage\captures\` on Windows), which is how the screenshots
quoted in `docs/EXPERIMENTS.md` were produced. It is not a shipped feature and has no effect without
the flag file.

---

## 3. Controls

| Input | Action |
|---|---|
| `W` `A` `S` `D` | move |
| Mouse | look |
| `Shift` | sprint |
| `Ctrl` | walk slowly |
| `Space` | step up / jump |
| `E` | interact with what the reticle is on |
| `F` | inspect the focused object in detail |
| `I` | recovered modules |
| `Tab` | engineering workstation console |
| `Esc` | pause, or close the open panel |
| `F1` | controls |
| `F6` | graphics bench |
| `F9` | jump the garage to its finished state (demonstration shortcut) |

The reticle shows **cyan** brackets when `E` will do something and **amber** when the object is
recognised but not yet usable — an unpowered monitor, or a module you have not salvaged.

---

## 4. The twelve-step objective chain

Defined in `data/objectives.json`, evaluated by `ObjectiveDirector`, and advanced by events rather
than by polling, so doing things out of order never strands the player.

1. Roll the shutter open
2. Restore workshop power at the main switchboard
3. Bring the workstation online
4. Read the inventor's notebook
5. Salvage the structural frame module
6. Recover the energy module
7. Lift out the armour shell module
8. Open the holographic design table
9. Install the three modules on the stand
10. Activate the prototype core
11. Run the diagnostic pass
12. Garage online — explore freely

Target playtime is 10–15 minutes. Everything is revisitable.

---

## 5. The two worlds

The garage is one room holding two visual registers, and the contrast between them is the point.

**World A — the Bangladeshi workshop.** Corrugated tin gable roof on welded trusses, brick and
plaster walls with a painted dado, a wooden bench scarred through to the grain, a pegboard of
hanging tools, a split single-cylinder motorcycle engine, a wire-spoked rickshaw wheel, a stripped
tube frame, an overhead gantry rail, tea glasses and a flask, a wall calendar with Bengali month
names, an IPS battery rack, a second-hand desktop with its side panel missing, an opened CRT with the
anode still attached.

**World B — the laboratory the student built inside it.** A circular assembly stage with a lifting
segmented deck, four two-axis manipulators built from motorcycle forks and servo boxes, a reactor
cradle whose bezel is a brake drum, a holographic design table projecting a cyan schematic, a wall
array of salvaged panels in welded bezels, and the exosuit itself.

Every World B object is visibly assembled from World A stock. That provenance is encoded in the
geometry, not asserted in text.

---

## 6. What is actually implemented

### Rendering

- **Procedural PBR channel synthesis.** 34 surface recipes, each producing an aligned
  albedo / ORM / tangent-space-normal set from a shared height field derived by Sobel gradient.
  World-triplanar projection at a declared *metres per tile*, so a brick course is 110 mm on every
  wall regardless of mesh UVs. See `docs/GRAPHICS_ALGORITHMS.md` §2.
- **Six custom spatial shaders.** Hologram (fresnel × world-space scanlines × object-space grid ×
  temporal flicker, plus an acquisition band); energy core (advected fBm plasma, containment rings,
  radial spokes, thresholded arc filaments, fresnel shell); holographic floor projection; CRT/LCD
  display glass with chroma split, scanlines and a refresh band; machined metal with emissive seams
  and edge wear; cable sleeve with weave ribs and a dust ramp.
- **A lighting rig in four switchable circuits** over one shadow-casting daylight source, with the
  shutter position continuously driving the daylight shafts and the volumetric fog density.
- Post-processing: AgX tonemapping, thresholded bloom, SSAO, SSR, SDFGI, volumetric fog, exponential
  distance fog, colour adjustment. Every one of them is a live switch in the graphics bench.

### Geometry

- **Procedural geometry throughout.** Boxes, cylinders, lathes, gears from tooth parameters,
  tube sweeps along parallel-transported frames, and compound assemblies — `ShapeKit` and the four
  prop catalogues build **175 props in 130 distinct kinds** in 4.0 s.
- **Procedural cable generation.** Catenary-approximated paths swept as tubes with
  parallel-transport framing (so the UV ribbing never twists), with bundling of several wires into
  one `ArrayMesh` — a real draw-call saving, measured in Experiment 4.
- **Seeded procedural layout.** Four placement groups distribute small clutter by rejection
  sampling against a minimum spacing and the authored furniture's bounding boxes, so the garage is
  identical on every run and the screenshots are comparable.
- **An original exosuit** of fourteen named parts with a documented home transform each, designed
  against the reference aesthetic without reproducing it: asymmetric shoulders, exposed hydraulics,
  hand-formed red plates over a recycled frame, and a core set in a brake-drum bezel.

### Interaction and systems

- First-person `CharacterBody3D` controller: distance-driven head bob, floor-material-aware
  footsteps, and one central input router so panels and the controller never fight over the same key.
- A reusable interaction system built on raycasting from the camera, resolving the hit collider up to
  the nearest `Interactable` ancestor — so a prop of a hundred meshes is still one interactable.
- Power restoration: four circuits come up in sequence with two false tube strikes before they hold.
- A workstation interface built from Godot `Control` nodes only — no screenshots, no browser windows —
  with six sections that genuinely read the simulation (assembly stage, module inventory, blueprint
  positions, derived diagnostics, circuit states, a 200-line system log).
- The five screens in the world are live `SubViewport`s sampled by the display-glass shader and
  refreshed at 12 Hz, so the monitors are showing the game's actual state, not a baked image.
- Animated assembly: one auditable `Tween` chain — deck plates rise, arms sweep, modules fly in,
  fourteen parts attach in a fixed order, the core ignites, the optics light.

### Text and localisation

All in-world text — signboards, the workshop plate, the danger notice, the wall calendar, the
notebook page, the component crate tags, and every screen — is drawn as Godot UI inside a
`SubViewport` and baked or sampled onto geometry. Bengali is therefore shaped by the engine's
HarfBuzz integration rather than assembled from glyph bitmaps, and every string is real Bengali
orthography (see `docs/ASSET_LICENSES.md` for a note on the brief's sample strings).

The garage is themed by data: `data/garage_config.json` carries four presets (Dhaka town workshop,
Sylhet hill-side garage, village repair shed, small industrial bay) that set the shell dimensions,
wall and roof style, floor style, exterior tint and signage. Switching preset rebuilds the
architecture without touching gameplay code.

### Audio

Every sound is synthesised at load by `AudioSynth` and wrapped in an `AudioStreamWAV`: Karplus-Strong
plucks with inharmonic partials for struck metal, state-variable filtered noise for rain on tin,
phase-locked partial stacks for the 50 Hz mains hum, biquad-filtered impulse trains for the saw,
additive ADSR stacks for the completion chord. Three buses (Ambience / Effects / Interface) with
independent volumes, and 3D voices with distance attenuation and a widening low-pass.

---

## 7. Measured performance

Reference machine: **Intel UHD 620 integrated graphics, 1600×900, Forward+**, captured by the
in-world graphics bench. These are the numbers the application reports about itself.

| Measurement | Value |
|---|---|
| Full garage build | 10.4 s |
| Surface synthesis, first 256 px surface | 272 ms |
| Props built | 175 (130 kinds) |
| Interactive stations | 34 |
| Registered lights | 30 (of which shadow casters: 7) |
| Live screen SubViewports | 5 |
| Mesh cache | 1684 hits, 1044 misses |
| Sustained frame rate, medium preset | 40–55 fps |
| Sustained frame rate, high preset | 18–26 fps |

Full per-experiment tables, with the exact configuration each row was measured under, are in
`docs/EXPERIMENTS.md`. Nothing in that file is estimated: every figure came from
`Performance.get_monitor()`, `Viewport.get_render_info()`, or the generators' own timers, and the
harness that produces them is in the application.

---

## 8. Repository layout

```
project.godot               # Forward+, input map, renderer settings
README.md

assets/
  fonts/                    # Noto Sans Bengali, Rubik, Oswald, JetBrains Mono (all OFL 1.1)
  textures/ui/              # project icon
data/
  garage_config.json        # four location presets: dimensions, materials, signage
  components.json           # the three prototype modules and their provenance
  objectives.json           # the twelve-step chain
  workshop_objects.json     # procedural layout groups, prop pools, Bangla label table
scenes/
  main/main_menu.tscn       # title screen (procedural animated backdrop)
  main/garage_world.tscn    # the garage root; builds everything in _build()
shaders/
  hologram.gdshader         # Contribution B
  energy_core.gdshader      # Contribution C
  holo_grid.gdshader        # floor projection
  screen.gdshader           # CRT/LCD display glass
  metal_emission.gdshader   # machined metal with emissive seams
  cable_material.gdshader   # cable sleeve
scripts/
  core/                     # EventBus, GameState, GameConfig, MaterialLibrary,
                            #   SignageBaker, SignCanvas, GarageTheme, EnumRef, AudioBank
  procedural/               # NoiseTools, TextureFactory, ShapeKit, CableGenerator,
                            #   AudioSynth, PropFactory + four prop catalogues,
                            #   ExosuitFactory
  garage/                   # GarageStructure, GarageDressing, GarageRuntime,
                            #   GarageEnvironment, GarageWorld, ScreenContent,
                            #   ObjectiveDirector
  interaction/              # Interactable, Station, InteractionReticle
  player/                   # Player
  ui/                       # Hud, BenchmarkPanel, MainMenu
tests/
  validate_scripts.gd       # headless compile check for all 38 scripts
  timing_probe.gd           # measures surface synthesis at three resolutions
  introspect.gd             # engine API introspection, used during development
  dump_floor.gd             # headless scene inspector: names what a capture shows
docs/                       # eight thesis documents
```

---

## 9. Documentation

| File | Contents |
|---|---|
| `docs/PROJECT_OVERVIEW.md` | concept, background, functionality, the two worlds |
| `docs/PROBLEM_STATEMENT.md` | the formal academic problem statement and objectives |
| `docs/SYSTEM_ARCHITECTURE.md` | scene structure, module relationships, the build order |
| `docs/GRAPHICS_ALGORITHMS.md` | the five contributions with their maths |
| `docs/RESEARCH_METHODOLOGY.md` | research questions, method, evaluation design |
| `docs/EXPERIMENTS.md` | six reproducible experiments with measured results |
| `docs/ASSET_LICENSES.md` | every asset's origin and licence |
| `docs/USER_MANUAL.md` | gameplay, controls, walkthrough, troubleshooting |

---

## 10. Honest scope

Stated plainly, because a thesis is worth less without it:

- **The exosuit is posed, not rigged.** Fourteen parts sit at authored transforms on a static
  skeleton. There is no IK, no animation blending, and the assembly sequence animates part
  *transforms*, not joints. The brief permits this; it is still a limitation.
- **The suit never leaves the stand.** No walking, no flight, no load bearing. This is a deliberate
  design position — the prototype's value is that it exists — but it is also the boundary of what was
  built.
- **SDFGI, SSR and volumetric fog are expensive on integrated graphics.** They are the reason the
  high preset runs at 18–26 fps. The medium preset disables all three and reaches 40–55 fps. This
  trade-off is measured in Experiment 5 rather than hidden.
- **Surface synthesis is single-threaded GDScript arithmetic.** The noise *fields* are generated in
  C++ by `FastNoiseLite`, but the per-texel compositing loop is interpreted, and it dominates load
  time at 272 ms per 256 px surface — 8.7 s of the 10.4 s build. Moving that loop to a compute
  shader is the single largest available optimisation and was not done.
- **Bengali text is baked through the engine's text stack, not hand-shaped.** This is the correct
  approach and produces correct conjuncts, but it means a Bengali string's first appearance costs a
  `SubViewport` render, which is why sign bakes are asynchronous.
- **No GPU timestamp queries.** The project reports frame time, draw calls and primitive counts
  through Godot's documented monitors. Per-pass GPU cost is inferred from the effect of toggling
  passes, which is what Experiment 5 does, and that inference is labelled as such.
