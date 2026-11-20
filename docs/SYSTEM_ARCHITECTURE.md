# SYSTEM ARCHITECTURE

## 1. Why the garage is built in code

The garage root scene, `scenes/main/garage_world.tscn`, contains exactly one node: a `Node3D` with
`scripts/garage/garage_world.gd` attached. Everything else is constructed at runtime.

That is a deliberate architectural decision, and it needs justifying because the conventional Godot
approach is the opposite: author a `.tscn` in the editor, save the node tree, load it.

Three reasons the code path was chosen.

**The content is generated.** There is no imported mesh or texture to reference from a saved scene.
Every prop is a composition of primitives produced by a factory function. A saved `.tscn` would have
to contain the *output* of those functions — thousands of nodes with baked-in transforms — and would
be unmaintainable the moment a prop generator changed. Building in code keeps the generator as the
single source of truth.

**The build order is a dependency graph.** Materials must exist before props; the runtime needs the
structure's dimensions; the environment registers lights with the runtime; the dressing pass needs all
of them plus the baker. A saved scene has no natural place to express that ordering, and Godot's
`_ready()` order is not a guarantee anyone should rely on for this many cross-references. The explicit
sequence in `GarageWorld._build()` is both the ordering *and* its documentation.

**The load is reportable.** Each step is measured and reported, so the loading screen shows real
progress and `docs/EXPERIMENTS.md` can quote per-phase build costs. A saved scene loads opaquely.

The cost of this decision: the garage cannot be edited by placing nodes in the editor viewport, and a
regression in a generator shows up at runtime rather than at save time. `tests/validate_scripts.gd`
exists to catch the second problem, and the capture harness in `GarageWorld._capture_process()` exists
to catch the first.

---

## 2. Scene graph

```
/root
├── EventBus                     (autoload)  global signal hub
├── GameConfig                   (autoload)  JSON data: presets, components, objectives, pools
├── GameState                    (autoload)  authoritative progression + save/load
├── MaterialLibrary              (autoload)  PBR material cache over TextureFactory
├── AudioBank                    (autoload)  3 buses, pooled 2D/3D voices, looping beds
│
└── GarageWorld                  (Node3D)  scenes/main/garage_world.tscn
    │   owns the build sequence and the inline capture harness
    │
    ├── SignageBaker             (Node)     bakes SignCanvas specs to textures; owns live SubViewports
    ├── Runtime                  (Node)     GarageRuntime: power, shutter, fans, screens, core, assembly
    ├── Garage                   (Node3D)   GarageStructure: floor, walls, columns, roof, shutter frame
    ├── Environment              (Node3D)   GarageEnvironment: WorldEnvironment, 30 lights, dust, rain
    ├── Dressing                 (Node3D)   GarageDressing: 175 props, 34 stations, cables, signage
    │
    ├── area volumes ×6          (Area3D)   named rooms; group "garage_areas"
    ├── Player                   (CharacterBody3D)
    │   ├── CollisionShape3D                capsule, sized from head height
    │   └── Camera3D
    │       ├── InteractRay                  RayCast3D, mask 3, length 3.6 m
    │       └── Reticle                      InteractionReticle: bounding-box brackets
    │
    ├── Hud                      (CanvasLayer, layer 20)
    │   │   objective / status / modules / prompt / notices / crosshair
    │   └── 10 panels + BenchmarkPanel
    │
    └── Objectives               (Node)     ObjectiveDirector
```

Six named `Area3D` volumes back the player's location tracking: `entrance`, `mechanical`,
`electronics`, `assembly`, `testing`, `exterior`. They deliberately overlap at thresholds.
The player tests its own position against them rather than relying on `area_entered` signals, because
those fire inconsistently when the player spawns *inside* a volume, which would make the first
objective flicker on load.

---

## 3. Build sequence

`GarageWorld._build()` is a coroutine. Each step yields two frames, so the engine flushes queued mesh
and texture uploads before the next step allocates more, and so the loading bar advances honest
progress.

| Step | What it does | Measured (UHD 620) |
|---|---|---|
| 0 | `MaterialLibrary.ensure_built()`, first surface synthesised | 272 ms for one 256 px surface |
| 1 | `GarageStructure.build()` — floor, plinths, courtyard, walls, columns, roof, shutter frame, windows | 5 807 ms |
| 2 | `GarageEnvironment.build()` — sky, WorldEnvironment, 30 lights in 4 circuits, dust, rain | 39 ms |
| 3 | `GarageDressing.dress()` — 5 areas, 4 procedural layout groups, 2 wall racks, cables, signage | 4 038 ms |
| 4 | Area volumes | — |
| 5 | Live `SubViewport`s for 5 screens, attached to their materials | 75 ms |
| 6 | Player, camera, ray, reticle, collision, capsule sizing | 26 ms |
| 7 | HUD, all panels, `ObjectiveDirector`, `start()` | 178 ms |
| 8 | `_apply_restored_state()` — replays a saved run with `instant = true` | — |
| | **total** | **10 622 ms** |

Surfaces are synthesised **lazily**, on first request. Loading every recipe up front would cost
roughly 9.5 s for all 34 at 256 px; the garage actually touches 34 of them, so the saving is in the
ordering rather than the count — the first surface is paid for during step 0 and the rest are paid
inside the step that needs them, which spreads the cost across the loading bar instead of stalling
one step.

---

## 4. Module responsibilities

### `scripts/core/`

**`event_bus.gd`** — the only global signal hub, ~20 signals in four groups (progression, interaction,
presentation, and the panel open/close pair). Systems connect to it instead of holding references to
each other. This is what lets the HUD, the computer interface, the assembly station and the audio
bank all react to `prototype_activated` without any of them knowing the others exist.

**`game_state.gd`** — authoritative progression: shutter, power, computer, notebook, hologram,
assembly stage, collected components, inspected objects, diagnostics, visited areas, elapsed time.
It holds no scene references, which is what makes saving it a single `store_var` of a dictionary. It
also owns `completion_ratio()`, which reads nine independent facts to produce the HUD ring.

**`game_config.gd`** — typed accessors over four JSON files. Every string a player reads, every
dimension of the building, every prop in a scatter pool and every one of the twelve objectives comes
through here. Keeping it in JSON is what makes the localisation requirement real rather than
aspirational: a new location is a new preset block, not a code change.

**`material_library.gd`** — the PBR layer. `surface(key, opts)` returns a cached `StandardMaterial3D`
built from a `TextureFactory` channel set, with world-triplanar projection derived from the recipe's
declared `meters_per_tile`. It also holds the named convenience palette (`ML.steel()`, `ML.teak()`,
`ML.armour_red()`, 60-odd more) that the prop catalogues call. `_opts_signature()` keys the cache on
the option set, so `ML.teak()` and `ML.teak(1.5)` are distinct entries with distinct UV scales.

**`signage_baker.gd`** — converts a declarative `SignCanvas` spec into either a baked `ImageTexture`
(static signs, notebook pages, calendars) or a live `SubViewport` (monitors, diagnostic panels,
hologram labels). Both routes go through Godot's text stack, which is why Bengali conjuncts shape
correctly. Baking needs two rendered frames, so it is a coroutine; `apply_baked()` hands back a
placeholder immediately and swaps the real texture in when it lands, so a signboard is never
untextured and no caller has to become a coroutine to use it.

**`sign_canvas.gd`** — a `Control` that draws a spec: rectangles, rounded rectangles, polylines,
circles, arcs, polygons, progress bars, bar charts, grids, corner brackets, plus `Label` and
`RichTextLabel` layers for text. This is the drawing language shared by the in-world signage and the
graphics bench's own interface.

**`garage_theme.gd`** — builds the project `Theme` in code, so a `Label` anywhere inherits the same
four font families (`latin`, `display`, `mono`, `bangla`) and the same palette. The theme is installed
on the window root at boot.

**`enum_ref.gd`** — resolves an engine enum ordinal by label from a property's hint string. Used for
`Environment.tonemap_mode`, which is not reachable as a class constant in this build and whose ordinal
has moved between minor versions. Falling back to a named default with a warning is better than
silently selecting a different tonemapper.

**`audio_bank.gd`** — three buses with independent volumes, a compressor and a small room reverb on
the master, pooled 2D and 3D players, and named looping beds. `apply_power_state()` switches the
garage's acoustic identity: the street bed stays, the mains hum and the fans join it.

### `scripts/procedural/`

**`noise.gd`** — deterministic helpers the engine's noise classes cannot express cheaply: integer
hashing for scatter decisions, Worley F1 for pitting and cracks, a ridged variant for corrosion
fronts, and a domain-warp function that stops noise bands reading as straight stripes.

**`texture_factory.gd`** — 34 surface recipes. For each: generate the scalar fields, composite them
per texel into colour/roughness/metallic/occlusion/height, pack to RGB8 byte buffers, derive a
tangent-space normal by Sobel gradient on the wrapped height field, upload in one
`Image::create_from_data` per channel. See `docs/GRAPHICS_ALGORITHMS.md` §2.

**`shape_kit.gd`** — the primitive composition layer, and the reason 175 props is affordable. Two
ideas: a mesh cache keyed on dimensions so forty spanners share one mesh, and true generators (lathe
from a profile, gear from tooth count and module, tube sweep, coil, chain, plate) for the shapes that
are not primitives. Also `shape_aabb_local()`, `area_aabb()` and `node_bounds()`, which exist because
several engine classes do not expose bounding boxes and half the interaction system needs them.

**`cable_generator.gd`** — catenary-approximated paths, parallel-transport framing (a naive up-vector
frame flips where the tangent crosses its reference axis and the UV ribbing twists), tube sweeping
with analytic normals, and bundling of several wires into one `ArrayMesh`.

**`audio_synth.gd`** — 22 sounds from additive partial synthesis, Karplus-Strong pluck models,
filtered noise and phase-locked partial stacks. No library.

**`prop_factory.gd` + `props_mech/elec/daily/proto.gd`** — the four prop catalogues: mechanical,
electronics, everyday Bangladeshi objects, and the futuristic laboratory. `prop_factory.gd` holds the
dispatcher, disambiguation aliases and the furniture generators (bench, shelf, stool, chair, crate);
the four `props_*` modules register their own generators into the factory's dispatch table at
construction, which keeps each file to a reviewable size while the catalogue stays one lookup.

**`exosuit_factory.gd`** — the fourteen-part original exosuit, with `home_offset()` as a **static**
mirror of the instance method's positions so the assembly animation, the hologram and the diagnostic
pass can all agree on where a part lives without instantiating a factory.

### `scripts/garage/`

**`garage_structure.gd`** — the building. Two skins per wall (brick outside, plaster inside) so corners
show the right material on each face. Roof geometry derived from explicit ridge and eave heights
rather than a free-standing pitch angle; the angle-first version rotated its sheets outward-downward,
putting the ridge ends *below* the wall top, which was invisible in code and obvious in a screenshot.
Gable ends closed with stepped concrete courses. The `area_volumes()` method returns the seven named
volumes so the world and the player share one definition.

**`garage_dressing.gd`** — placement in three tiers. **Authored**: the objects that carry meaning, at
fixed transforms chosen for the sightline they create (benches, stand, workstation, three module
crates, notebook, switchboard). **Procedural**: eight layout groups from
`data/workshop_objects.json`, rejection-sampled against a minimum spacing *and* against the authored
furniture's bounding boxes. **Racks**: wall tools on explicit ordered lists, because a tool board is
organised by habit, not by chance. Also registers every station, light, fan and screen with the
runtime, so dressing is the single place where interactivity is wired.

**`garage_runtime.gd`** — the cross-cutting state machine: power, shutter, fans, screens, computer
boot, energy core, hologram, assembly, diagnostics. Thirteen thin per-object scripts would be the
conventional structure and would be wrong here, because these systems are not independent: turning on
the power changes eleven lights, two fans, four monitors, the core pulse, the hologram availability
and the room's ambience, and the assembly depends on all of them being in a known state. Thin
stations plus one owner of the truth.

**`garage_environment.gd`** — `WorldEnvironment`, four lighting circuits, dust and rain particle
systems, and the coupling of shutter position to daylight shafts and fog density.

**`screen_content.gd`** — builds the spec for every display in the garage from a single `_snapshot()`
of the simulation, so no screen can disagree with another and no separate data path has to be kept in
sync.

**`objective_director.gd`** — evaluates the twelve-objective chain against `GameState` on every
relevant event and emits the current text. Never polls.

### `scripts/interaction/`

**`interactable.gd`** — base class. An interactable is a description plus two hooks. It declares
`id`, `prompt`, `primary_action`, `inspectable`, an availability predicate and a max distance, and
exposes `interact()`, `inspect()` and `bounds()`. `from_node()` walks up the tree to resolve the owner
of a collider, so a prop of a hundred meshes is one interactable.

**`station.gd`** — the concrete implementation, with a 20-value `Kind` enum grouping behaviours by
area. It holds no state beyond the hover flag: `_primary()` switches on kind and calls the runtime.
Adding a new interactive object never requires understanding the power system.

**`interaction_reticle.gd`** — four corner brackets sized to the target's bounding box, billboarded to
the camera, animating outward on acquisition and contracting on release. Amber means the game sees the
object but you cannot use it yet; cyan means `E` will do something. Material-overlay highlighting was
rejected because it replaces the PBR shading of the object being examined.

### `scripts/player/player.gd`

`CharacterBody3D` with a per-frame raycast and one central `route_action()` input dispatcher, so
panels and the controller never contend for the same key. Head bob is driven by *distance travelled*
rather than elapsed time, so its frequency tracks walk speed and sprint without a second tuning
constant. Footsteps sample the floor material underfoot and alternate left/right with seeded pitch
variation.

### `scripts/ui/`

**`hud.gd`** — objective, status, module status, prompt, notices and crosshair, plus ten panels, all
built from `GarageTheme`. Built lazily: `_ready()` cannot build the panels because `attach()` has not
yet supplied the baker, the runtime and the director, and building against those nulls would abort the
world's build coroutine. `_build_all()` is idempotent and idempotently connects its signals.

**`benchmark_panel.gd`** — six experiment tabs driving 34 live parameters, an 18-cell metrics strip
reading real `Performance` and `Viewport` monitors, a three-pass sampling run, PNG capture and CSV
export. See `docs/EXPERIMENTS.md`.

**`main_menu.gd`** — title screen whose backdrop is drawn procedurally in `_draw()`: perspective floor
grid, three counter-rotating reactor rings with travelling gaps, a pulsing core bloom, a scanline
sweep, a tin-roof silhouette and shutter slats. Every button is functional.

---

## 5. Data flow

```
                      data/*.json
                           │
                     GameConfig (autoload)
                           │
   ┌───────────────┬───────┴────────┬─────────────────┐
   │               │                │                 │
TextureFactory  PropFactory    ObjectiveDirector   HUD panels
   │               │                │                 │
MaterialLibrary    │                │                 │
   │               │                │                 │
   └──── GarageStructure ──── GarageDressing ─────────┘
                    │                │
                    │             Station × 53 ──────┐
                    │                │               │
              GarageEnvironment   GarageRuntime ◄────┘
                    │                │
                    └──── GarageWorld ──── Player, HUD
                             │
                    EventBus ──── GameState ──── ScreenContent
                                        │
                                   save / load
```

Read direction: everything reads `GameConfig` and `GameState`. Write direction: only `GameState` is
mutated, and only through its own API. `EventBus` carries notifications in both directions but holds
no state.

The single most important invariant: **no screen, panel or prompt keeps its own copy of a fact.** The
HUD ring, the workstation console, the six in-world screens, the assembly interface and the diagnostic
readout all call `ScreenContent._snapshot()` or read `GameState` directly, which is why they cannot
disagree — a property that matters because the diagnostic figures are *derived* from the assembly
stage rather than randomised, so a loaded save reproduces the same numbers.

---

## 6. Persistence

`GameState` serialises to `user://deshi_iron_garage.save` as a versioned dictionary. On `Continue`,
`GarageWorld._apply_restored_state()` replays it against the freshly built world with `instant = true`
on every setter, so a loaded game does not play the whole boot animation again: the shutter is already
up, the power is already on, the computer is already at stage 3, the modules are already installed,
the core is already lit, and the screens are already powered with their shaders at `power = 1.0`.

The save version is checked and a mismatch is treated as no save, which is why `SAVE_VERSION` is bumped
rather than migrated — for a project of this scope a clean start is less risky than a partial
migration.

---

## 7. Decoupling and its limits

Signals where a system needs to *announce*: power, shutter, computer, component collection, assembly
stage, prototype activation, panel open/close, notifications.

Direct references where a system needs to *ask*: the dressing pass holds the runtime and the structure;
the runtime holds the props factory and the baker; the HUD holds all five.

The line is drawn at whether a caller needs an answer. `EventBus.component_collected` announces; the
HUD then asks `GameState.has_component()` for the truth. That keeps the signal payloads trivial and
the truth in one place.

The cost of the split: the HUD's constructor takes seven arguments, which is a lot, and
`GarageDressing` legitimately knows about `GarageRuntime`, `GarageStructure`, `MaterialLibrary`,
`SignageBaker` and `PropFactory`. Dressing is the integration point of the build, so that coupling is
inherent rather than accidental — but it does mean `garage_dressing.gd` is the file most likely to
need editing when a new prop or station type is added.

---

## 8. Reproducibility

Two mechanisms make runs comparable, which is what the experiments depend on.

**Seeds.** `PropFactory` takes a seed (1337). Every procedural layout group in
`data/workshop_objects.json` carries its own seed. `TextureFactory` derives a per-surface seed from
the surface key's hash plus a fixed base, so a surface is identical in the editor, in a release build
and in the capture harness. The rain, the dust and the footsteps use separate seeds so that changing
one does not perturb another.

**Fixed capture viewpoints.** The capture harness drives the progression to a known state and parks
the camera at twelve declared transforms, which is what makes the screenshots in `captures/`
comparable between code revisions. It also reports a luminance histogram per shot: the check that
matters most is the `black` percentage, because a lighting rig that renders almost nothing still
produces a screenshot and would otherwise read as success.

**The headless fallback.** Under `--headless` the `RenderingServer` is a dummy and
`FastNoiseLite.get_image()` returns an empty `Image`. `TextureFactory._field_bytes()` detects that and
falls back to a GDScript per-texel sampling path, so materials are still produced and the scene still
builds for CI validation. The fallback is 4.5× slower and is never used in the shipped game; it exists
so that `tests/validate_scripts.gd` can run in an environment with no GPU.

---

## 9. Testing

| Mechanism | What it covers |
|---|---|
| `tests/validate_scripts.gd` | Loads and compiles all 38 scripts headless; fails loudly on any parse or compile error. This is the primary guard, and it caught every error class during development. |
| `tests/timing_probe.gd` | Measures one surface at 256/384/512 px. The instrumentation that established the texture budget. |
| `tests/introspect.gd` | Engine API introspection. Used to pin exact signatures when they were uncertain rather than guessing. |
| `tests/dump_floor.gd` | Builds the world headless and lists every node within a radius of a floor point, with generated cables reported by their mesh bounds and material colour. Written to name the unidentified objects in a capture from the scene graph instead of guessing. |
| Capture harness | Boots the real renderer, drives the full progression, writes 12 PNGs plus luminance histograms and a build report. Catches the class of failure that compiles cleanly and renders nothing. |
| Graphics bench | Self-measurement at runtime, exportable to CSV, with a fixed-camera capture at each configuration. |

What is **not** tested: there is no unit test suite, no automated interaction test that drives `E`
presses, and no regression baseline for image output. The capture harness reports per-shot luminance
rather than diffing against a stored reference, so a subtle visual regression would pass.
