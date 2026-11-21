# PROJECT OVERVIEW

**DESHI IRON GARAGE — The Dream of a Bangladeshi Inventor**
Interactive real-time 3D workshop exploration · Godot 4.7.2 · typed GDScript · Forward+

---

## 1. Concept

A young Bangladeshi CSE student has an idea for a powered exosuit and no laboratory to build it in.
What he has is his family's tin-roofed repair shop, a bench that has been scarred for nineteen years,
a second-hand desktop computer repaired four times, two dead IPS batteries, a scrapped motorcycle,
and an imagination that has quietly converted all of it into something else.

The player steps into that garage. Half of it is unmistakably a working Bangladeshi workshop: brick
and plaster walls with a painted dado, a corrugated tin roof, engine blocks, a rickshaw wheel, a
pegboard of tools, tea glasses, a wall calendar in Bengali. The other half is what the student built
out of it: a circular assembly stage, four manipulator arms made from motorcycle forks, a holographic
design table, a reactor cradle whose bezel is a brake drum, and a red-and-brass exosuit standing on
its display cradle.

The task is to finish it. Restore the power. Read the notebook. Find the three modules he salvaged.
Raise the schematic. Install them. Watch the arms assemble the suit, light the core, and then run a
diagnostic pass on the thing you built.

## 2. Background

The project began from a photograph rather than a specification. Bangladeshi repair workshops — the
motorcycle lanes, the computer-repair floors of Elephant Road, the roadside bicycle stands — have a
specific visual quality that is rarely rendered: **dense, improvised, and organised by habit rather
than by design.** Every object is second-hand and every object has a second purpose. A biscuit tin
holds screws. A roof sheet becomes a fairing. A monitor chassis becomes a parts tray. The pegboard's
layout is not aesthetic; it is muscle memory.

That quality is what the project tries to render, and it turns out to be an unusually good subject
for computer graphics, for one reason: **improvisation is procedural by nature.** A workshop built
from whatever was available is a workshop whose contents can be *generated* from a set of parts and a
set of rules, because that is how it was actually built. This project has no imported 3D models, no
photographic texture set and no audio library, and the setting is the reason that constraint reads as
a method rather than as a shortage.

The Iron Man reference is deliberate but secondary. What is borrowed is the *narrative shape* — an
engineer, a garage, a suit assembled from salvaged parts, a first power-up that is more exciting than
it is sensible — and the visual grammar of a workshop in which the work is visibly in progress. The
suit is not that suit. It is an original design: asymmetric shoulders, exposed hydraulics, hand-formed
plates, a core set in a scrap brake drum. See `docs/GRAPHICS_ALGORITHMS.md` §6.

## 3. Structure of the experience

Five areas inside one room, with a deliberate sightline from the entrance straight through the
mechanical clutter to the assembly stage, so the player sees both worlds in the first second.

| Area | Contents |
|---|---|
| **1. Entrance** | Rolling shutter (interactive, animates), signboard with Bengali text, bicycle, crate stacks, scrap bin, courtyard outside |
| **2. Desi mechanical workshop** | Bench, pegboard of 17 hanging tools, toolbox, bench vice, engine block, cylinder head, piston, crankshaft, camshaft, carburettor, silencer, sprockets, rickshaw and motorcycle wheels, tube frames, cot, ceiling fan, pedestal fan, tube light, bench lamp |
| **3. Electronics repair laboratory** | Second-hand desktop (interactive), CRT and LCD (interactive), laptop shell, PCB stacks, multimeter, solder station, oscilloscope, variac, UPS and IPS batteries, battery rack with the ferrite coil, component drawers, stabilizer, printer, router, fan |
| **4. Futuristic assembly laboratory** | Circular assembly stage with lifting deck, four manipulator arms, reactor cradle, exosuit on its stand, holographic design table, wall array of salvaged panels, overhead gantry with trolley, indicator strips, conduit runs |
| **5. Prototype testing corner** | Raised deck, safety boundary, instrument console (interactive), portrait diagnostic screen, tether rig, hazard markings |

**Progression.** Twelve objectives, event-driven, in `data/objectives.json`. The chain is tolerant of
being done out of order: the director re-evaluates the whole list on every event and settles on the
first unsatisfied objective, so the guidance is always truthful about what remains. After 35 seconds
without progress it offers the objective's hint once.

**The power puzzle.** The garage starts with the main switch down. The player must inspect the IPS
bank to learn the state, work the main switch, and watch four circuits come up in sequence — tube
lights first (with two false strikes, because that is what a dying starter does), then the bench task
lamps, then the electronics pool, then the reactor zone. Five fans spin up with first-order lag.
Six screens wake. The core begins to pulse. All of it is real lights and real node animation.

## 4. The three modules

Fictional game components, each visually built from a real World A donor, described in
`data/components.json`:

**Structural frame module** — a twin-downtube spine cut from a scrapped motorcycle frame, re-welded
around a rickshaw axle bracket. 11.4 kg, 612 mm, 0.8 mm joint tolerance, from a scrap yard lot.

**Energy module** — two dead tubular IPS cells rewired into a balanced buffer pack, topped with a
ferrite coupling coil lifted from a monitor flyback. 6.9 kg, "48 V (simulated)".

**Armour shell module** — hand-formed plates beaten from a corrugated roof sheet, an old petrol can
and two motorcycle fairings, shimmed with bicycle inner-tube rubber at every contact. 9.2 kg,
1.2 mm nominal.

Each module installs a coherent body section rather than one arbitrary mesh: the frame brings the
spine, pelvis and both legs; the energy module brings the core and the back pack; the shell brings the
chest, helmet, both arms, forearms and hands.

> **Note on content.** These are fictional visual components in a game. The project contains no
> high-voltage electrical construction guidance, no battery-modification procedure and no
> powered-armour engineering instruction. The core is described in-world as a display model, and the
> diagnostic text says so on screen.

## 5. Original exosuit — design language

Fourteen named parts, each with a documented home transform shared by the assembly animation, the
holographic schematic and the diagnostic pass. The design is deliberately not a reproduction:

- **Asymmetric shoulders.** A layered pauldron on the right because the inventor had one usable
  stamping die; an open ring on the left.
- **Exposed hydraulics** at every joint instead of continuous armour — cylinders, sleeves and tie rods
  are visible, because hiding them would require machining the inventor does not have.
- **Unpainted brass and bare steel** wherever a plate was hand-formed.
- **A horizontal visor slit with an external jaw guard**, not a faceplate.
- **A chest core set in a salvaged brake-drum bezel**, bolted with six 8 mm bolts.

Posed on a static skeleton. Fourteen parts animate as transforms during assembly; there is no rig.
This is stated as a limitation in the README and in `docs/EXPERIMENTS.md`.

## 6. Bangladeshi visual identity

The identity comes from the environment rather than from flags or signage volume. Specifically:

- **Architecture**: corrugated tin gable on welded trusses with a ridge vent; brick outer skin with a
  plaster inner skin so corners show the correct material on each face; a painted dado band; a
  four-way switchboard with a weather-proof gland.
- **Vernacular objects**: rickshaw chassis with a canopy and painted decorative panel; wire-spoked
  wheels; a tea stall cart with a gas burner and glasses; a tubewell bucket; a muri tin; a gamcha
  towel on a nail; chappals by the door; a cot with a woven rope bed; a plastic chair; a gas cylinder.
- **Electrical reality**: a 50 Hz mains hum synthesised from a 50/100/150/250/300 Hz partial stack,
  because Bangladesh runs 230 V 50 Hz and that is audible; an IPS battery rack because load shedding
  is a design constraint; a voltage stabiliser because the supply in that lane swings 170–260 V.
- **Typography**: 25 Bengali strings across 12 signage and screen surfaces, drawn through the
  engine's text stack with Noto Sans Bengali so conjuncts and matras shape correctly. The wall
  calendar carries both date columns, and the garage's own signboard is hand-painted-looking tin.

The design brief that seeded this project included three sample Bangla signs; two contained
orthographic errors (`স্বপ্নের গরেজ` for `স্বপ্নের গ্যারেজ` and `নিজের প্রযুক্তি নিজের শক্ত` for
`নিজের প্রযুক্তি, নিজের শক্তি`). Those have been corrected to standard Bengali, with the reasoning
recorded in `docs/ASSET_LICENSES.md`.

## 7. Functionality summary

| System | State |
|---|---|
| First-person controller | WASD, mouse look, sprint, crouch-walk, gravity, jump, distance-driven head bob, material-aware footsteps |
| Interaction | Raycast focus with a bounding-box reticle, contextual prompts, E to operate, F to inspect |
| Interactable stations | 59 registered, across 20 behaviour kinds |
| Power | 4 circuits, sequential energisation, tube strike simulation, live circuit isolation from the MCB row |
| Workstation | 6-section `Control`-built interface reading live simulation state, with a POST → login → ready boot |
| In-world screens | 5 screen meshes, 5 live `SubViewport`s, temperature-graded CRT and LCD glass shader |
| Hologram | Interactive raise/lower, 6 live shader parameters exposed in the graphics bench |
| Energy core | Interactive activation, 6 parameters exposed, drives its own light and the suit optics |
| Assembly | 3 modules, 14 parts, one Tween chain, deck lift, arm choreography, core ignition |
| Diagnostics | 7-stage pass with live log output to the console panel and the portrait screen |
| Salvage | 3 collectable modules with world-space crates, baked tags and inventory tracking |
| Mouse carrying | Just about any loose prop can be picked up, rotated and set down with the mouse — up to 3.1 m in one dimension (workbenches, shelves, the bicycle, the holo table); placement settles onto the surface under the aim (bench tops, shelves, the platform deck, the floor) and right click returns a thing to where it came from. The gate, the windows, the flag mast, the prototype suit and the fitted platform stay put |
| Lab wall | Six honour plaques for Bangladeshi/Bengali scientists and one inventions board, engraved in Bangla from `data/scientists.json` and `data/inventions.json` through the same sign baker as every other sign, plus `F` inspection text for each |
| National corner | The national flag on a courtyard pole — the official construction (2:3, disc at 9/20 length, radius L/5) with a cloth shader that waves it — and a big brass ৫ টাকা display coin leaning on its plinth; both are inspectable, neither is real currency |
| Wall maps | Two hand-drawn sketch maps hung on the entrance walls: the country right of the gate, the Sylhet division beside the door — outline, rivers, towns and district lines drawn through the same sign baker as every other sign, with `F` text honest that they are line sketches, not survey data |
| Shop signboard | Hand-painted tin over the gate, now framed in a chasing **RGB LED strip** (its own shader) with two colour-cycling washes — all on the incoming line, so the board stays bright and the street gets its neon whatever the switchboard does |
| Keepsakes | The author's own photographs as wall art: a framed row above the mechanical bench (a Bangladesh Railway locomotive, Ali Amjad's clock, a lab batch around a CRT), the team photo leaning by the notebook, the exosuit concept poster on the wall the stand faces, and a desk flag — loaded through the same no-import `photo_print()` path as the street banner |
| Notice wall | Thirteen community-licensed (CC BY-SA 4.0) photographs of the country — rickshaws, Sadarghat market, a Khulna tea stall, the Sylhet tea gardens, the railway, boats, paddy — pinned crooked to a plywood board on the entrance wall; every file's author and source recorded in `docs/ASSET_LICENSES.md` |
| Faked wear | Flush overlays and chips that make the room read used: painted tool outlines on the pegboard, chalk dimension notes on the floor, tea rings and an old spill on the bench top, a six-row paper label strip on the component drawers, and a scatter of stickers — no props, no stations, no lights |
| Sound | Every clip synthesised as PCM at load — no sound packs. Surface-aware footsteps (concrete, steel deck, packed earth), tools, servos, the shutter's chain rattle — and an instrument-free nature ambience (wind, leaves, sparrows) as the project's music, from the title screen on |
| Armour | A whole red-and-gold armoured figure on a service base by the north wall — core lens and eye slits lit — with its spare helmet, chest plate, gauntlet and boot laid out where they are worked on; procedurally built, deliberately unbranded, every piece pickable |
| Global gloss | Every surface recipe multiplies its roughness down to 0.58, so painted steel, sealed concrete and varnished teak catch the room's lights and the SSR has something to work with |
| Auto-opening gate | The shutter's presence sensor rolls the curtain up as anyone approaches the courtyard — it starts most of the way down and the room wakes up as it lifts. It can no longer be lowered |
| Always-on bulbs | Five bare bulbs — walk lane, both benches, the testing corner, the store — are wired ahead of the switchboard to the incoming line, outside every switchable circuit: the room is never dark, even at the start, and each bulb carries its own light when you pick it up |
| Entrance | A concrete apron ramps the doorway down to the packed earth so the shop can be walked into and out of without breaking stride, and the courtyard is walled in — walking past the street wall or the neighbour walls stops you instead of dropping you out of the world |
| Adaptive resolution | The render scale moves inside 0.55–0.85 to hold the frame rate on the machine at hand; off during any measurement (F6, `perf.flag`, capture mode) so numbers stay comparable |
| Realism layer | 10 projected grime decals from one generated texture (under machinery, below wall fixtures), the author's supplied workshop banner inside, and a generated "IMRAN'S GARAGE" street banner over the facade |
| Save / load | Full run state persisted; Continue replays it against a fresh build with no boot animation |
| Settings | Quality preset, FOV, walk speed, sensitivity, invert, bloom, SSAO, shadows, rain, four volumes |
| Graphics bench | 6 experiment tabs, 34 live parameters, 18 real performance monitors, screenshot and CSV export |
| Graphics tour | 10-waypoint camera rail through the finished garage |

## 8. Where the graphics work lives

Six documents expand this; the short version of what was built and where:

| Work | File | Kind |
|---|---|---|
| Surface synthesis: albedo/ORM/normal from one height field, world-triplanar at declared metres-per-tile | `scripts/procedural/texture_factory.gd` | Custom |
| Holographic projection shader | `shaders/hologram.gdshader` | Custom |
| Energy-core emissive shader | `shaders/energy_core.gdshader` | Custom |
| Procedural cable geometry: catenary path, parallel-transport sweep, bundling | `scripts/procedural/cable_generator.gd` | Custom |
| Interactive lighting as four switchable circuits | `scripts/garage/garage_environment.gd` | Extended |
| Procedural prop generation: 4 catalogues, 140 kinds | `scripts/procedural/props_*.gd` | Custom |
| Projected grime: one generated blot texture, ten `Decal` volumes that follow geometry | `garage_dressing.gd` `_grime_decals()` | Custom |
| Runtime audio synthesis: 22 sounds, no library | `scripts/procedural/audio_synth.gd` | Custom |
| Display glass, holographic floor, machined metal, cable sleeve | `shaders/*.gdshader` | Custom |

## 9. Deliberate design positions

Three choices that will look like omissions unless stated as decisions:

**The suit never leaves the stand.** It does not walk, fly, or bear load. The in-world diagnostic text
says "standing test only — no flight, no load", and the notebook says the same. The point of the
prototype is that it exists. This is the brief's own framing, and it is also the honest boundary of
what one student can build.

**Nothing is a screenshot.** Every screen in the garage renders live Godot UI reading the simulation.
The brief is explicit about this, and it is also the harder path: it means the workstation interface
is a real UI system, not an image swap.

**The garage is themed by data, not by code.** Four location presets sit in
`data/garage_config.json`. Changing the active preset rebuilds the shell dimensions, wall and roof
style, floor material, exterior tint and all signage without touching gameplay, interaction or the
assembly sequence. That is the localisation requirement, implemented as configuration.

## 10. Measured status

On Intel UHD 620 at 1600×900, Forward+:

- Garage build: **13.7 s** in the latest run (6.3 s structure, 6.7 s dressing for 197
  placements; the same build has measured 11.0–13.7 s across earlier runs — machine load moves it;
  most of the total is surface synthesis, spread across both steps)
- Medium preset: 40–55 fps measured before the preset retune — SDFGI and volumetric fog off, SSR on,
  five shadow casters; the retune cut a further 13–27 ms of CPU frame time (`docs/EXPERIMENTS.md` §7.5)
- High preset: 18–26 fps measured before the retune, all global-illumination features on, seven casters
- 37 lights, 7 of them shadow casters, 5 live screen viewports

`docs/EXPERIMENTS.md` holds the per-experiment tables and the exact configuration for each row.
