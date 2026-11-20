# ASSET LICENSES

Every asset in this project is either generated at runtime from code, or a font under the SIL Open
Font License. **No 3D model, texture image, or audio file was downloaded or imported.** This document
records exactly what came from where, and under what terms.

---

## 1. Summary

| Category | Count | Origin | Licence |
|---|---|---|---|
| 3D meshes | 1 123 distinct, 180 placed | **Generated at runtime** by `ShapeKit` and the prop catalogues | Original work, same licence as the source |
| Texture images | 34 surface sets × 3 channels = 102 images | **Synthesised at runtime** by `TextureFactory` | Original work |
| Supplied photograph | 1 image (127 KB) | **Provided by the project's author** — the workshop banner hung on the north wall | Author's own work, used with the author's permission |
| Audio | 22 clips | **Synthesised at runtime** by `AudioSynth` | Original work |
| Shaders | 6 files | Written for this project | Original work |
| Fonts | 4 families | Google Fonts repository | SIL Open Font License 1.1 |
| UI icon | 1 SVG | Written for this project | Original work |
| Reference photographs | 11 | Project brief (research reference only) | **Not distributed, not used as assets** |

---

## 2. Generated assets — the substance of the project

### 2.1 Geometry

No mesh file (`.obj`, `.gltf`, `.fbx`, `.blend`) exists anywhere in the repository. Every mesh is
produced at runtime by constructors in `scripts/procedural/shape_kit.gd` and the four prop
catalogues.

Two mechanisms are used:

**Engine primitives, parameterised.** Godot's `BoxMesh`, `CylinderMesh`, `SphereMesh`, `TorusMesh`,
`PlaneMesh` and `CapsuleMesh` are configured per prop and cached by dimensions. 1 123 distinct
configured meshes serve 180 placed props through 1 770 cache hits in the shipped room.

**Geometry generated from parameters.** Where a primitive is insufficient, the mesh is built with
`SurfaceTool` or `ArrayMesh` from parameters:

| Generator | File | Produces |
|---|---|---|
| `lathe()` | `shape_kit.gd` | surfaces of revolution from a 2D profile: glasses, bottles, funnels, cans, hubs |
| `gear()` | `shape_kit.gd` | involute-approximating spur gears from tooth count and module |
| `coil()` | `shape_kit.gd` | helices swept as tubes |
| `chain()` | `shape_kit.gd` | interleaved torus links |
| `bolt()`, `plate()`, `frame_tube()` | `shape_kit.gd` | compound assemblies |
| `generate()`, `generate_bundle()` | `cable_generator.gd` | swept tube geometry along catenary paths |
| `ExosuitFactory.build()` | `exosuit_factory.gd` | the 14-part exosuit, entirely from shapes above |

Engine primitive types are used under Godot's MIT licence; the parameterisation, composition and
generated meshes are original work.

### 2.2 Textures

No `.png`, `.jpg`, `.tga`, `.exr` or `.hdr` texture exists in `assets/`. Every surface is synthesised
at load by `scripts/procedural/texture_factory.gd` from 34 recipes, producing an albedo, an ORM
(occlusion/roughness/metallic) and a tangent-space normal per surface.

The noise foundation is `FastNoiseLite`, a Godot engine class (MIT). The author's own noise functions
in `scripts/procedural/noise.gd` — integer hashing, bicubic-interpolated value noise, FBM, ridged FBM,
Worley F1, and domain warping — are original implementations of published algorithms (Perlin 1985,
Worley 1996) and are documented as such.

The composition logic — how height, mottle, grain and pattern fields combine into four coherent PBR
channels — is original work and is described in `docs/GRAPHICS_ALGORITHMS.md` §2.

### 2.3 Audio

No `.wav`, `.ogg` or `.mp3` exists in the repository. All 22 sounds are synthesised as PCM at first
use by `scripts/procedural/audio_synth.gd` and wrapped in `AudioStreamWAV`.

| Synthesis technique | Sounds | Notes |
|---|---|---|
| Karplus-Strong delay line + inharmonic partials | `metal_clank`, `metal_thunk`, `metal_tink`, `switch_throw`, `relay` | Pluck model after Karplus & Strong (1983), original implementation |
| State-variable band-pass resonator | `servo`, `servo_slow`, `weld` | Standard SVF topology, original implementation |
| Additive phase-locked partial stack | `hum`, `core_charge`, `core_idle`, `assembly_done` | 50 Hz fundamental for the mains hum |
| Biquad-filtered noise | `fan`, `fan_fast`, `rain`, `street` | One-pole low-pass and high-pass |
| Filtered impulse train | `rain` | Drop events scheduled into a buffer |
| ADSR envelope shaping | all | Original implementation |
| Exponential decay envelopes | all | Original implementation |

Every synthesis parameter — frequencies, decay rates, partial ratios, noise seeds — is written in
this repository. Nothing is sampled from a recording.

### 2.4 Shaders

Six `.gdshader` files, all written for this project:

| File | Contribution |
|---|---|
| `hologram.gdshader` | Contribution B |
| `energy_core.gdshader` | Contribution C |
| `holo_grid.gdshader` | floor projection |
| `screen.gdshader` | CRT/LCD display glass |
| `metal_emission.gdshader` | machined metal with emissive seams |
| `cable_material.gdshader` | cable sleeve weave |

Standard techniques they implement — Fresnel approximation (Schlick), fBm, derivative-based
antialiasing via `fwidth()`, Sobel gradient — are published methods; the composition of each shader is
original. `energy_core.gdshader` contains its own `hash13`/`vnoise`/`my_fbm` rather than using the
engine's `noise()` builtin, so the visual result is driver-independent; this is noted in
`docs/GRAPHICS_ALGORITHMS.md` §4.3.

### 2.5 UI

The theme (`scripts/core/garage_theme.gd`) is built in code. The one image asset is
`assets/textures/ui/garage_icon.svg`, a hand-written SVG for the application icon: a reactor ring over
a tin roof, in the project palette.

---

## 3. Fonts

All four fonts are from the [Google Fonts](https://github.com/google/fonts) repository, used under the
**SIL Open Font License 1.1**, which permits use, modification and redistribution including in
embedded applications. The license text for each is included in `assets/fonts/`.

| File | Family | Version | Copyright | Licence file |
|---|---|---|---|---|
| `NotoSansBengali.ttf` | Noto Sans Bengali | `[wdth,wght]` variable | The Noto Project Authors | `NotoSansBengali-OFL.txt` |
| `Rubik.ttf` | Rubik | `[wght]` variable | The Rubik Project Authors | `Rubik-OFL.txt` |
| `Oswald.ttf` | Oswald | `[wght]` variable | The Oswald Project Authors | `Oswald-OFL.txt` |
| `JetBrainsMono.ttf` | JetBrains Mono | `[wght]` variable | The JetBrains Mono Project Authors | `JetBrainsMono-OFL.txt` |

**Why Noto Sans Bengali.** Bengali requires correct conjunct (যুক্তাক্ষর) formation and matra
positioning, both of which need a shaping engine rather than glyph-by-glyph rendering. Noto Sans
Bengali is the reference implementation for the script in the Google Fonts collection and covers the
full Bengali block (U+0980–U+09FF) plus the required conjuncts. All Bengali text in the project is
rendered through Godot's text stack, which uses HarfBuzz, and is therefore shaped correctly rather
than assembled from isolated glyphs.

**Assignment within the project**

| Theme role | Font | Used for |
|---|---|---|
| `latin` | Rubik | UI body text, signage subtitles |
| `display` | Oswald | headings, titles, the component crate tags |
| `mono` | JetBrains Mono | technical readouts, system logs, telemetry, telemetry-style labels |
| `bangla` | Noto Sans Bengali | **all** Bengali strings, in-world and in UI |

---

## 4. Reference photographs

The project brief included eleven reference photographs of Bangladeshi motorcycle workshops,
electronics repair shops, computer-repair lanes and related environments, together with two production
stills from a motion picture used as tonal reference.

**Status: reference only. Not distributed, not embedded, not derived from.**

No photograph is used as a texture, a decal, a background image or a normal-map source anywhere in the
project. Their influence is at the level of *design vocabulary* — which objects appear in a workshop of
this kind, how they are arranged, what materials they are made from — and that vocabulary is then
implemented as procedurally generated geometry and synthesised materials.

The specific observations taken from the reference set and their implementation:

| Observation from the references | Implementation |
|---|---|
| Motorcycle engine blocks with cooling fins, partially disassembled | `MechProps.engine_block()`, `cylinder_head()`, `piston()` |
| Wire-spoked bicycle and rickshaw wheels leaned against workshop walls | `MechProps.wheel_rickshaw()` with 24 generated spokes |
| Dense wall-hung tool arrangements, tools by habit rather than by size | `GarageDressing._wall_racks()` with three explicit ordered tool lists |
| Tin-roofed sheds with visible steel trusses and purlins | `GarageStructure._build_roof()` and `_truss()` |
| Stacks of dead CRT monitors and opened tubes with the anode attached | `ElecProps.crt_guts()` |
| Piles of circuit board fragments on benches | `ElecProps.pcb_stack()` |
| Component drawers, multimeters, solder stations, tangled cable masses | `ElecProps` catalogue, plus `CableGenerator` for the lacing |
| Bengali-language signage, printed posters and free promotional calendars | `SignageBaker` with real Bengali strings, `wall_calendar()`, `poster()` |
| Tea glasses and a flask as fixtures of the workspace | `DailyProps.tea_glass()`, `flask()` |
| A repurposed industrial space converted to improvised fabrication | the whole World A / World B contrast |
| Suit and armour shapes used as tonal reference, not as a model to copy | `ExosuitFactory` — see §5 |

### 4.1 The one supplied image

There is exactly one photograph in the build: `assets/textures/user/imran_banner.jpeg`, a workshop
banner supplied by the project's author and hung on the workshop's north wall at his request
(`DailyProps.wall_banner()`, placed by `GarageDressing._area_assembly()`). The subject is the author's
own promotional banner for "Imran International Airlines", naming him as founder and owner.

It is used with the author's permission, it is his own work, and it is the only file in the project
that is not generated by code or a font. It is loaded at runtime with `Image.load_from_file()` rather
than through the editor's import pipeline, so a checkout runs without an `.import` step;
`MaterialLibrary.banner_print()` degrades to a plain panel with a warning if the file is absent.
Godot warns on every load that this path "will not work on export" — correct, and deliberate: the
project is submitted and run from source, and an exported build would instead ship the image as an
imported resource. Nothing about the project's procedural claim depends on it: remove the one
`_place()` call and the garage is 100% generated again.

---

## 5. Deliberate originality — the exosuit

The exosuit is original work and is **not** a reproduction of any copyrighted character design. The
design differences are structural, not cosmetic, and are documented in `docs/PROJECT_OVERVIEW.md` §5:

- asymmetric shoulders — a layered pauldron on the right, an open ring on the left
- exposed hydraulics at every joint rather than continuous armour
- unpainted brass and bare steel wherever a plate was hand-formed
- a horizontal visor slit with an external jaw guard, not a faceplate
- a chest core set in a salvaged brake-drum bezel
- proportions computed for a 1.86 m figure, not traced from any reference

The design vocabulary of "metallic powered armour" is a genre convention. No texture, silhouette,
marking, insignia or proportion is copied from any specific work.

---

## 6. Note on the Bengali strings in the project brief

The design brief that seeded this project supplied three sample Bangla signs. **Two contained
orthographic errors**, and they have been corrected in the implementation rather than reproduced:

| Brief's text | Corrected to | Problem |
|---|---|---|
| স্বপ্নের গরেজ | **স্বপ্নের গ্যারেজ** | missing the `্যা` matra in `গ্যারেজ` |
| নিজের প্রযুক্তি নিজের শক্ত | **নিজের প্রযুক্তি, নিজের শক্তি** | `শক্ত` lacks the final `ি`; the comma was also added |
| পরীক্ষামূলক গবেষণাগার | পরীক্ষামূলক গবেষণাগার | correct as supplied; used unchanged |

The reasoning: the brief requires *proper Unicode Bengali fonts with verified glyph support* and
instructs against producing malformed Bangla text. Rendering a misspelled sign perfectly would satisfy
the letter of the font requirement and violate the intent, so the strings were normalised to standard
Bengali orthography.

All 25 Bengali strings used in the project are listed in `data/workshop_objects.json` under
`bangla_labels`, with the signage and screen strings additionally visible in
`GarageDressing._sign_spec()`, `_plate_spec()`, `_danger_spec()`, `_calendar_spec()`,
`_notebook_spec()`, `_poster_spec()` and `ScreenContent`.

**Encoding verification.** Every source and data file was validated as UTF-8 with no replacement
characters after each round of scripted edits, because the Bengali content passed through several
automated text-replacement passes and a silent encoding fault would be invisible in a console that
cannot render the script.

---

## 7. Engine and dependencies

| Component | Version | Licence |
|---|---|---|
| Godot Engine | 4.7.2 stable (standard build, not .NET) | MIT |
| `FastNoiseLite` | bundled with Godot | MIT (part of the engine) |
| HarfBuzz (text shaping) | bundled with Godot | MIT |
| TextServer Advanced | bundled with Godot | MIT |

**No third-party plugins, addons or GDExtensions are used.** The project has no `addons/` directory
and no external dependency of any kind. It opens and runs in a stock Godot 4.7.x editor with no
installation step beyond the engine itself.

---

## 8. Licence of this project's original work

All content authored for this project — GDScript source, shader source, JSON data, the SVG icon, and
all eight documents in `docs/` — is original work. Where a third-party algorithm or technique is
implemented, it is cited at the point of use in the source comments and in
`docs/GRAPHICS_ALGORITHMS.md`.

The generated runtime content (meshes, textures, audio) is derived entirely from that original source
code and from the four OFL-licensed fonts. It therefore carries no separate licence and no attribution
requirement beyond this document.

---

## 9. Verification

To confirm the claims in §2 mechanically:

```bash
# no binary asset files of any kind
find . -type f \( -name "*.obj" -o -name "*.gltf" -o -name "*.fbx" -o -name "*.blend" \
  -o -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.tga" -o -name "*.exr" \
  -o -name "*.wav" -o -name "*.ogg" -o -name "*.mp3" \) -not -path "./.godot/*"
# expected: nothing except the .import files Godot generates for the four fonts

# the only assets directory contents
ls -R assets/
# expected: assets/fonts/ (4 TTF + 4 OFL), assets/textures/ui/garage_icon.svg
```
