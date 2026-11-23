# ASSET LICENSES

Every asset in this project is either generated at runtime from code, a font under the SIL Open
Font License, or one of two CC0 texture sets. **No 3D model or audio file was downloaded or
imported**; texture images are runtime-synthesised except two CC0 PBR sets on the armour figure
(section 2.2b). This document records exactly what came from where, and under what terms.

---

## 1. Summary

| Category | Count | Origin | Licence |
|---|---|---|---|
| 3D meshes | 1 176 distinct, 199 placed | **Generated at runtime** by `ShapeKit` and the prop catalogues | Original work, same licence as the source |
| Photographs (5) | Wall art from `assets/textures/user/` | **Supplied by the author** for in-world frames | Loaded with `Image.load_from_file()`, no import side files; the locomotive and clock images are also published on Wikimedia Commons — pin their exact licences before wider redistribution |
| Photographs (13) | The notice-wall collage, `assets/textures/wall/` | **Wikimedia Commons, CC BY-SA 4.0**, fetched through the Commons API and resized to 480 px | Every file, author and source page is listed below |
| Photographs (10) | The two smaller boards — the streets and the working country | **Openverse (Flickr originals), CC0 / CC BY 2.0 / CC BY-SA 2.0**, fetched through the Openverse API, licence-filtered, resized to 480 px | Every file, author and source page is listed below |
| Texture images | 34 surface sets × 3 channels = 102 images | **Synthesised at runtime** by `TextureFactory` | Original work |
| Texture images (2 sets, 7 maps) | The armour figure's normal detail (the sets' other maps kept in the repo), `assets/textures/armor/` | **ambientCG, CC0 1.0**, 1K JPGs resized to 512 at load | PaintedMetal009 (paint) and Metal027 (worn metal) — the sets are CC0, no attribution required, credited here anyway |
| Supplied photograph | 1 image (127 KB) | **Provided by the project's author** — the workshop banner hung on the north wall | Author's own work, used with the author's permission |
| Audio | every clip | **Synthesised at runtime** by `AudioSynth` | Original work; no recorded music and no musical instruments anywhere — the ambience is wind, leaves, sparrows, the street and the rain |
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
`PlaneMesh` and `CapsuleMesh` are configured per prop and cached by dimensions. 1 176 distinct
configured meshes serve 199 placed props through 1 839 cache hits in the shipped room.

**The notice-wall photographs.** Thirteen files from Wikimedia Commons, fetched through the Commons
API, each checked to carry a CC BY-SA 4.0 licence before download, then resized to 480 px for the
collage. Authors as named on the file pages:

| In-game file | Commons file | Author |
|---|---|---|
| `wall_01.jpg` | [Back view of Rickshaw … bd](https://commons.wikimedia.org/w/index.php?search=Back+view+of+Rickshaw+bd) (title carries Bengali script) | Bengali Wikimedia user, named on the file page |
| `wall_02.jpg` | [At Sadarghat street Market 06](https://commons.wikimedia.org/wiki/File:At_Sadarghat_street_Market_06.jpg) | Kritzolina |
| `wall_03.jpg` | [Inside bamboo frame roadside tea stall Khulna](https://commons.wikimedia.org/wiki/File:Inside_bamboo_frame_roadside_tea_stall_Khulna.jpg) | User:TanvirSdq |
| `wall_04.jpg` | [Lakkatura Tea Garden, Sylhet](https://commons.wikimedia.org/wiki/File:Lakkatura_Tea_Garden,_Sylhet.jpg) | AdibHossain999 |
| `wall_05.jpg` | [Bangladesh Railway 2](https://commons.wikimedia.org/wiki/File:Bangladesh_Railway_2.jpg) | Mahbubur |
| `wall_06.jpg` | [City point, Sylhet (cropped)](https://commons.wikimedia.org/wiki/File:City_point,sylhet_(cropped).jpg) | Abdul hadi chowdhury |
| `wall_07.jpg` | [A fishing boat at Muktaria ghat, Hatiya, Noakhali](https://commons.wikimedia.org/wiki/File:A_fishing_boat_at_Muktaria_ghat_,_Hatiya,_Noakhali,_Bangladesh._Meghna_river_on_the_left_side.(_29_February_2020)..jpg) | Salim Khandoker |
| `wall_08.jpg` | [A boat in Padma river](https://commons.wikimedia.org/wiki/File:A_boat_in_Padma_river.jpg) | Smartmsh |
| `wall_11.jpg` | [A pigeon house in a Santal village in Dinajpur district 02](https://commons.wikimedia.org/wiki/File:A_pigeon_house_in_a_Santal_village_in_Dinajpur_district_02.jpg) | Kritzolina |
| `wall_12.jpg` | [Baitul Mukarram National Mosque, Dhaka 168](https://commons.wikimedia.org/wiki/File:Baitul_Mukarram_National_Mosque,Dhaka_168.jpg) | Frameofashik |
| `wall_13.jpg` | [Bangladesh Railway Museum, Chattogram (2Q7A0322)](https://commons.wikimedia.org/wiki/File:Bangladesh_Railway_Museum,_Chattogram_(2Q7A0322).jpg) | Moheen Reeyad |
| `wall_14.jpg` | [Badshavog — ধান — Paddy — DSC00603](https://commons.wikimedia.org/w/index.php?search=Badshavog+Paddy+DSC00603) (title carries Bengali script) | ROCKY |
| `wall_15.jpg` | [A Bangladeshi Saintmartin Hyundai Bus In Dhaka Chittagong Highway](https://commons.wikimedia.org/wiki/File:A_Bangladeshi_Saintmartin_Hyundai_Bus_In_Dhaka_Chittagong_Highway.jpg) | Sabbir Siam |

Two file pages are linked through a Commons search because their titles carry Bengali script that the
fetch pipeline could not round-trip; both are CC BY-SA 4.0 and their authors are as shown on the
pages. CC BY-SA 4.0 requires attribution and share-alike for derivatives — the credits here are that
attribution, and any redistribution of the collage keeps this file with it.

**The Openverse photographs.** Ten more files for the two smaller boards, fetched through the
Openverse API (`api.openverse.org`), licence-filtered to CC0 / CC BY / CC BY-SA, then resized to
480 px. Wikimedia's WAF began refusing this machine's fetches midway through the project, so
Openverse — which indexes the same kinds of Flickr originals — is the source for this batch. Authors
and landing pages as recorded on the API's response:

| In-game file | Title | Author | Licence | Source |
|---|---|---|---|---|
| `wall_21.jpg` | Streetside scenes | -Niloy- | CC BY 2.0 | [Flickr](https://www.flickr.com/photos/63369436@N00/46729199) |
| `wall_22.jpg` | Dhaka Rickshaw | Gary Lee Todd, Ph.D. | CC0 1.0 | [Flickr](https://www.flickr.com/photos/101561334@N08/39795792142) |
| `wall_23.jpg` | After Ifter at Barista. | Andalib. | CC BY 2.0 | [Flickr](https://www.flickr.com/photos/77568842@N08/7796814912) |
| `wall_24.jpg` | Keane Bridge & Clock Of Ali Amjad | ~~ `Nostalgia' ~~ | CC BY 2.0 | [Flickr](https://www.flickr.com/photos/15433877@N07/2766696675) |
| `wall_25.jpg` | Snake Charmer | Jorge Lascar | CC BY 2.0 | [Flickr](https://www.flickr.com/photos/8721758@N06/4499194699) |
| `wall_26.jpg` | Dhaka traffic dynamics | Ahron de Leeuw | CC BY 2.0 | [Flickr](https://www.flickr.com/photos/53848312@N00/1568681602) |
| `wall_27.jpg` | On a Sundarbans Boat | Mike Prince | CC BY 2.0 | [Flickr](https://www.flickr.com/photos/70804987@N00/16571997796) |
| `wall_28.jpg` | Welcome to Ashulia brickfield | joiseyshowaa | CC BY-SA 2.0 | [Flickr](https://www.flickr.com/photos/30201239@N00/3373611632) |
| `wall_29.jpg` | Helping Khaleda, one of the survivors of Rana Plaza | DFID — UK Department for International Development | CC BY 2.0 | [Flickr](https://www.flickr.com/photos/14214150@N02/14008308964) |
| `wall_32.jpg` | A Village Farmer in Bangladesh (title carries Bengali script) | Ahsan Ovi Photography | CC0 1.0 | [Flickr](https://www.flickr.com/photos/149196903@N02/34308123365) |

CC BY and CC BY-SA require attribution; the credits here are that attribution, and any redistribution
of the boards keeps this file with them.

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

No imported texture exists in `assets/` except the seven armour maps in `assets/textures/armor/`
(section 2.2b). Every other surface is synthesised at load by `scripts/procedural/texture_factory.gd`
from 34 recipes, producing an albedo, an ORM (occlusion/roughness/metallic) and a tangent-space
normal per surface.

The noise foundation is `FastNoiseLite`, a Godot engine class (MIT). The author's own noise functions
in `scripts/procedural/noise.gd` — integer hashing, bicubic-interpolated value noise, FBM, ridged FBM,
Worley F1, and domain warping — are original implementations of published algorithms (Perlin 1985,
Worley 1996) and are documented as such.

The composition logic — how height, mottle, grain and pattern fields combine into four coherent PBR
channels — is original work and is described in `docs/GRAPHICS_ALGORITHMS.md` §2.

### 2.2b The armour texture sets (CC0)

The armour figure's materials are the one place where real photographs are used. Two PBR sets from
[ambientCG](https://ambientcg.com/) — both released under **CC0 1.0** (public domain, no attribution
required; credited here anyway) — supply the figure's normal-detail maps, with the sets' remaining
maps kept in the repository:

| Set | Asset | Maps used | Role on the figure |
|---|---|---|---|
| Paint | `PaintedMetal009` — <https://ambientcg.com/view?id=PaintedMetal009> | `armor_paint_normal.jpg` bound; `armor_paint_color.jpg`, `armor_paint_rough.jpg`, `armor_paint_ao.jpg` in the repo | The red painted plating (`armor_paint()`) — brand new off the stand: flat deep paint over a tight clearcoat, the normal map only for surface life at low scale |
| Worn metal | `Metal027` — <https://ambientcg.com/view?id=Metal027> | `armor_metal_normal.jpg` bound; `armor_metal_color.jpg`, `armor_metal_rough.jpg` in the repo | The polished underlayer and exposed machinery (`armor_dark()`) |

The brand-new finish keeps the paint bold and glossy — metallic 0.6, roughness 0.2, clearcoat 1.0 at
0.08 — so the suit catches every lamp in the room; the underlayer is polished alloy at metallic 0.85.
The worn maps (paint colour/roughness/AO, metal colour/roughness) are part of the licensed sets but
are not bound: nothing on a new suit should read as use. The downloads are 1K JPGs; each is resized
to 512 px when loaded by `MaterialLibrary._armor_map()`
(`Image.load_from_file()` + resize, no import side files — same loading path as the author's own
photographs). If a file is missing the material falls back to its flat tint and a warning is printed,
so the figure never renders untextured.

---

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
