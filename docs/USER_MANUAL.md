# USER MANUAL

**DESHI IRON GARAGE — The Dream of a Bangladeshi Inventor**
Interactive 3D workshop exploration · Godot 4.7.x

---

## 1. Installing and starting

### Requirements

- **Godot Engine 4.7.x stable**, standard build (not the .NET build)
- A GPU with Vulkan or OpenGL 3.3 support
- ~350 MB of disk space
- Windows, Linux or macOS

No installation step is required beyond the engine itself. The project has no plugins, no addons and no
external assets to place.

### Running

```bash
# from the project directory
godot --path .

# or directly into the garage, skipping the menu
godot --path . res://scenes/main/garage_world.tscn
```

The first launch builds the garage and shows real progress: surface synthesis, then the shell, the
lighting rig, 191 props, the screens and finally the interface. On a machine with integrated graphics
this takes around 10 seconds; on a discrete GPU it will be considerably faster. The build time is also
written to `user://captures/build.log`.

---

## 2. Controls

| Input | Action |
|---|---|
| **W** **A** **S** **D** | move |
| **Mouse** | look around |
| **Shift** | sprint |
| **Ctrl** | walk slowly |
| **Space** | step up / jump |
| **E** | interact with the object the reticle is on |
| **F** | inspect the focused object in detail |
| **Left click** | pick up a prop / place it down |
| **Wheel** | rotate the held object |
| **Right click** | put the held object back where it was |
| **I** | recovered modules |
| **Tab** | engineering workstation console |
| **Esc** | pause, or close the open panel |
| **F1** | controls reference |
| **F6** | graphics bench |
| **F9** | jump the garage to its finished state (demonstration shortcut) |

The mouse is captured while you are in the garage. Press **Esc** to release it.

### Reading the reticle

Two small brackets appear around whatever you are looking at:

- **Cyan brackets** — `E` will do something. The prompt under the crosshair tells you what.
- **Amber brackets** — the object is interactive but not usable yet. The prompt says why: `no power`,
  `workstation offline`, `missing FRAME`.

The brackets are sized to the object's bounding box and breathe gently while held, so you can tell the
game has registered it before you read the text.

---

## 3. Your first five minutes

1. **You start in the courtyard** facing a half-closed rolling shutter.
2. **Look at the shutter and press `E`.** It rolls up with a mechanical chain drive, slats curling
   around the barrel. Light floods in from outside.
3. **Walk in.** Straight ahead, past the workbenches, you can see the assembly stage and the exosuit
   standing on it in the dark. That sightline is deliberate.
4. **Turn left.** On the wall beside the entrance is the **main switchboard**. Look at it and press
   **`E`** to throw the main switch.
5. **Watch.** Four circuits come up in sequence. The tube lights over the bench strike twice before
   they hold. The fans spin up. The desktop tower's power LED lights. In the back of the room the
   energy core begins to pulse.

The garage is now alive. Everything else is available to you.

---

## 4. The twelve objectives

The current objective is always in the top-left panel. The bar underneath it is your overall
progress. If you are stuck for 35 seconds, a hint appears once in the bottom-left.

| # | Objective | Where | How |
|---|---|---|---|
| 1 | ~~Roll the shutter open~~ | — | satisfied at start: the gate rolls itself up as you arrive — its presence sensor lifts the curtain, and it can no longer be lowered |
| 2 | Restore workshop power | entrance, west wall | `E` on the switchboard. **Inspect it first with `F`** - the IPS bank beside it tells you what state the supply is in. A chain of bulbs — the walk lane, both benches, the testing corner, the store — already burns: they are wired ahead of the switchboard to the incoming line, so the room is never dark whatever you do to the switches |
| 3 | Bring the workstation online | electronics bench, east | `E` on the desktop tower. It runs a POST sequence, then a login, then the console |
| 4 | Read the inventor's notebook | mechanical bench, west | `E` on the notebook lying open on the bench |
| 5 | Salvage the structural frame module | mechanical area | `E` on the crate tagged **FRAME** |
| 6 | Recover the energy module | electronics area | `E` on the crate tagged **CORE** |
| 7 | Lift out the armour shell module | assembly area | `E` on the crate tagged **SHELL** |
| 8 | Open the holographic design table | assembly area, west of the stage | `E` on the table. A cyan schematic of the suit rises out of it |
| 9 | Install the modules on the stand | assembly stage | `E` on the stage to open the assembly interface, then install each module |
| 10 | Activate the prototype core | assembly stage | `E` on the reactor cradle at the centre of the stage |
| 11 | Run the diagnostic pass | testing corner, north-east | `E` on the instrument console |
| 12 | Garage online — explore freely | — | — |

**The order is not enforced.** If you find a crate before you find the notebook, take it. The objective
director re-evaluates the whole chain every time something changes and always points at the first thing
still outstanding, so it never asks you to do something you have already done.

---

## 5. Interacting with the garage

### Salvage crates

Three wooden crates carry baked paper tags reading **FRAME**, **CORE** and **SHELL**. Look at one and
press `E` to recover the module. The module disappears from the crate and appears in your module list
(bottom-right, and the `I` panel). The tag also lists the donor part, in the inventory panel's detail
view.

### The workstation

With the power on, press `E` on the desktop tower, or **Tab** at any time once it has booted. Six
sections:

| Section | Contents |
|---|---|
| **STATUS** | assembly stage, completion, main supply, core state, hologram state |
| **INVENTORY** | the three modules with their full descriptions and recovery state |
| **BLUEPRINTS** | all fourteen suit parts with their home transforms and which module brings each |
| **DIAGNOSTICS** | six derived readings: frame integrity, core buffer, thermal envelope, optics, shell bonding, joint backlash |
| **POWER** | the four circuits with live energise/isolate controls |
| **LOG** | up to sixty lines of the system log |

Every value on those pages is read from the running simulation, so nothing can disagree with what you
see in the room.

### Inspecting with `F`

Almost every object in the garage is inspectable. Aim at a spanner, a motor, a battery, a fan, a
poster — press **F** and you get a panel with a description, a specification table, and occasionally
history written in the inventor's voice. **Roughly nine in ten props carry real text.** This is the
main reward for looking closely, and it is where most of the Bangladeshi detail lives.

### Picking things up with the mouse

Just about anything loose can be picked up, carried and set down: tools, tins, tea glasses, stools,
tyres, drums, crates, chairs, shelves, workbenches, the bicycle, even the holographic table — up to
3.1 m in any one dimension, and big things are carried by their centre so a workbench floats in front
of you rather than towering from a point. **Every part of the prototype suit comes off one by one** —
helmet, chest, limbs, the core — and so does each piece of the shop's armour project. The few things
that stay put are the ones that depend on exactly where they are: the gate, the windows, the flag
mast, the building itself and the big fitted pieces (the assembly platform, the cable tray).

Look at a thing and a translucent
cyan box appears around it with the line `LEFT CLICK — PICK UP`; left click takes it, the wheel spins
it, left click again settles it onto the surface under your aim — bench top, shelf, crate lid, the
platform deck, the floor — and right click puts it back exactly where it came from. Nothing can be
dropped into geometry, nothing can be lost, and the object leans into your turns with a smoothed
follow rather than snapping to the crosshair.

### The holographic design table

`E` on the table raises a cyan schematic of the suit. The miniature is built from the *same* part
offsets the assembly uses, so what you see drawn is what will be built. Three label plates give part
names in Bengali and English.

While the schematic is up, the **Schematic** panel lets you drive six shader parameters live —
fresnel power, scanline density, acquisition band speed, grid scale, flicker amount and glow strength —
plus a wireframe-only mode. This is the same shader the graphics bench exposes under Experiment 2.

### The energy core

`E` on the reactor cradle pulses the core on and off. The **Core** tab of the graphics bench drives
its six parameters and its colour.

### The assembly interface

`E` on the stage opens it. Three slots, one per module, each showing the recovered state and which
parts it will install:

- **FRAME** → spine, pelvis, left leg, right leg
- **CORE** → the chest core, the back plate and its buffer pack
- **SHELL** → chest, helmet, both arms, forearms and hands

Install them in order (the interface enforces it, because the frame is what everything else bolts to),
then press **START ASSEMBLY SEQUENCE**.

You can also use the stand itself: `E` on the suit runs the diagnostic pass once it is complete.

### The diagnostic console

In the testing corner, bordered by a hazard rail. `E` on the console runs a seven-stage diagnostic
pass: each line prints to the system log, appears as a notification, and updates the portrait screen
beside it. The readings are derived from the build state, so a save you load later reproduces the same
numbers.

---

## 6. What to look at

If you have fifteen minutes and want to see everything:

**The mechanical half (west).** The bench with its pegboard and tool rail of hanging tools, the
toolbox, the vice, the grindstone. On the bench: an engine block, cylinder head, piston with its
wrist pin, carburettor, a brake drum, bearings, and the inventor's open notebook. On the floor: a
rickshaw chassis with its canopy, a motorcycle frame, a scrap bin, a tyre, a cable reel, a steel
drum. On the walls: a wall calendar with Bengali month names, an inspection clipboard, a poster.

**The electronics half (east).** The bench with a CRT whose tube face is visible and an LCD beside
it. A gutted laptop with ribbon cables. Stacks of circuit board fragments, heatsinks, capacitors, RAM
sticks. A multimeter with its leads coiled. A solder station with the iron in its holder. An
oscilloscope, a variac, a voltage stabiliser, a printer, a speaker. On the floor below: a battery
rack with two tubular cells and a ferrite coupling coil, a UPS unit, a parts cabinet. Above the
instrument bench, the **scientists' corner** — six honour plaques and the inventions board.

**The futuristic half (north).** The circular assembly stage with its eight lifting deck plates and
four arm mounts. Four manipulators built from motorcycle forks and servo boxes. The reactor cradle at
the centre, its bezel a brake drum. The overhead gantry with its trolley and hoist. A wall array of
two salvaged panels in welded steel bezels, the owner's airline banner on the brick beside them.
Conduit runs with glowing seams at the joints. The exosuit on its stand.

**The testing corner (north-east).** A raised deck inside a hazard rail, an instrument console with
three gauges, six toggle levers and a mushroom emergency stop, a portrait diagnostic screen.

**Outside.** Step back out through the gate — it has rolled itself up, and it does that for anyone who
walks up: the presence sensor over the lintel lifts the curtain as you approach (there is nothing to
press; the shutter station only tells you about it). Above the gate, the shop's tin signboard is
framed in a chasing RGB LED strip with two colour-cycling washes — always on, like the bulbs inside,
so the street side of the garage is never dark either. The way in and out is a concrete apron that
ramps the doorway down to the yard, so you walk in without breaking stride whichever way you come.
The courtyard itself is walled in — the street wall and the neighbour walls are solid, and the packed
earth runs right up to them. On the walls of the entrance: **a hand-drawn map of Bangladesh** right
of the gate and **its Sylhet division** beside the door — sketch maps, and their `F` text says so.
There is a courtyard with a tea
stall cart, a bicycle, a rickshaw wheel, a roof antenna, and a neighbour's wall. Puddles on the
packed earth, a gold-on-navy street banner over the left pier reading **IMRAN'S GARAGE** with the
shop's Bangla name underneath, and by the gate the national corner: the **flag of Bangladesh** on
its pole — bottle green, the red disc at nine-twentieths of the length with a radius of one-fifth,
waving in a cloth shader — and a big brass **৫ টাকা display coin** leaning on its plinth. Press `F`
on either; the coin's text is honest that it is an ornament, not money.

**The Bengal wall.** Above the instrument bench: six plaques for জগদীশ চন্দ্র বসু, সত্যেন্দ্রনাথ বসু,
কুদরত-এ-খুদা, কাজী মোতাহার হোসেন, জামাল নজরুল ইসলাম and মাকসুদুল আলম, under a header reading
**বিজ্ঞানীদের কর্নার**, and beside them a board titled **এই মাটির আবিষ্কার** — oral rehydration
therapy first proven in a Dhaka laboratory in 1968, the jute genome, the first satellite, the Padma
bridge, the solar home programme — closing on **নিজের মাথা, নিজের হাতে**. Press `F` on any plate to
read it.

**The Bengali signage.** The signboard over the shutters reads **স্বপ্নের গ্যারেজ** — *dream garage* —
with the tagline **নিজের প্রযুক্তি, নিজের শক্তি**, *own technology, own strength*. Inside there is a
workshop plate reading **পরীক্ষামূলক গবেষণাগার** (*experimental laboratory*), a yellow danger notice
by the switchboard, and Bengali annotations in the notebook, with the twelve month names on the
calendar. Every one of those strings is shaped by the engine's text stack with Noto Sans Bengali, so
the conjuncts form correctly.

**The notebook.** On the mechanical bench. Reading it opens a four-page panel: the original sketch
with construction lines and dimensions, the parts list, a page of design constraints written in the
inventor's voice, and a short letter. The sketch's dimensions are the ones the stand actually uses.

**The photographs.** The garage keeps the owner's pictures where a working shop keeps them: a framed
row above the mechanical bench — a Bangladesh Railway locomotive, Ali Amjad's clock in Sylhet, and an
older batch of students around a half-stripped television — the team photo leaning by the notebook,
the exosuit concept poster on the wall the assembly stand faces, and a desk flag on the electronics
bench. At the entrance, a plywood board pins thirteen pictures of the country itself — rickshaws,
markets, tea gardens, boats, paddy — the community-licensed set whose credits are listed in
`docs/ASSET_LICENSES.md`; two more boards hang in the assembly bay and by the testing corner with ten
more licensed pictures of the streets and the working country. And the room keeps the marks of work:
painted tool outlines on the
pegboard, chalk notes on the floor, tea rings on the bench top, paper labels on the drawers, a
grease handprint on the apron, a paint-test board, stickers — and a whole red-and-gold armoured
figure on a service base by the north wall, its spare plates laid out where they are worked on.
`F` on any of the pictures for the story.

---

## 7. The graphics bench (`F6`)

Seven tabs. All of them drive the running scene and all of them measure the running scene.

**Metrics strip** — 18 live readings: FPS, frame time, physics time, draw calls, objects in frame,
primitives, shadow-pass draw calls and primitives, video memory, texture memory, buffer memory, node
count, orphan node count, resource count, registered lights, shadow casters, props built, pipeline
compilations.

**Tabs**

| Tab | Drives | Experiment |
|---|---|---|
| Materials | metallic, roughness, albedo value, normal scale, source surface (10 options) | 1 |
| Hologram | variant (transparent / emissive / hologram) and six shader parameters | 2 |
| Energy core | six core parameters plus core colour and on/off | 3 |
| Lighting | six configurations, exposure, ambient, sun energy, bloom intensity, SDFGI/SSR/fog toggles | 5 |
| Cables | length segments, radial segments, radius, sag, slack, bundle toggle, with live mesh statistics | 4 |
| Post stack | bloom, SSAO, SSR, SDFGI, MSAA level, tonemapper, glow threshold, SSAO radius and intensity, shadow blur | 6 |

**Buttons**

- **RUN CURRENT EXPERIMENT** — discards 30 frames, then takes three independent passes of 90 frames.
- **CAPTURE FIXED CAMERA** — writes a PNG of the current view.
- **EXPORT RESULTS CSV** — writes `user://benchmarks/results.csv`.
- **CLEAR CAPTURES** — removes the PNG files and the sample buffer.
- **REGENERATE SURFACE TEXTURES** — empties the material cache and resynthesises, reporting the total
  cost.

Results are written to `user://benchmarks/` (on Windows,
`%APPDATA%\Godot\app_userdata\Deshi Iron Garage\benchmarks\`).

---

## 8. Settings

Reachable from the pause menu or from the main menu.

**Controls** — mouse sensitivity, walk speed, field of view, invert vertical look.

**Graphics**

| Setting | Effect |
|---|---|
| **quality preset** | `low` (128 px surfaces, no SSAO/SSR/SDFGI/fog, 3 shadow casters) · `medium` (256 px, SSAO + SSR + light shafts, no SDFGI, 5 casters) · `high` (384 px, everything including SDFGI, 7 casters) |
| bloom | emissive objects spill light; the energy core loses most of its presence without it |
| ambient occlusion | contact shadows; without it every prop appears to float slightly |
| shadows | the shadow-casting lights, capped by the preset's budget |
| rain | rain on the tin roof, visually and audibly |

**Adaptive resolution** runs on top of whichever preset you pick, and it is how the build avoids lag
on a machine it was not tuned for: once a second it looks at the worst steady frame and moves the
render scale inside 0.55–0.85 — smaller when frames run long, back up when there is headroom — with
the picture upscaled by FSR 2 throughout. You never need to touch it; it switches itself off during
any measurement (the F6 bench, the perf harness, capture mode) so those numbers stay comparable.

**Audio** — master, ambience, effects and interface volumes, independently. Ambience carries the
**nature bed** — wind, leaves and sparrows, the project's music, and deliberately instrument-free:
there is no recorded music and no musical instrument anywhere in the game — plus the street, the
rain on the tin, the mains hum and the fans. Effects carries the **surface-aware footsteps**
(concrete, the steel deck, packed earth), tools, servos and the core; interface carries the UI blips.
The mains hum is a synthesised 50 Hz stack, which is the actual supply frequency in Bangladesh.

**Speed** — `medium` is the recommended preset on integrated graphics: it drops the SDFGI cascades,
keeps the light shafts, and leans on adaptive resolution, which is what makes it the comfortable
choice. The default is `high`, which keeps everything including the global illumination and lets
adaptive resolution find whatever the machine can hold.

---

## 9. Saving

Your progress saves automatically at `user://deshi_iron_garage.save` (on Windows,
`%APPDATA%\Godot\app_userdata\Deshi Iron Garage\`).

**Start** clears the save and begins fresh. **Continue** loads it and replays it against a freshly
built garage with every animation set to instant, so you resume exactly where you were — shutter up,
power on, modules installed, core lit — without sitting through the boot sequences again.

The save is versioned. If the version does not match, it is treated as absent and a new run begins
rather than risking a partial migration.

**Garage Tour** on the main menu loads the garage in its *completed* state — even on a fresh install —
and flies the camera along a ten-waypoint rail through all five areas with captions. This is the mode
for showing the finished project to someone without playing through it. Press **Esc** at any time to
take control.

---

## 10. Troubleshooting

**The garage builds but the room is dark.**
The main switch is down. Press `E` on the switchboard by the entrance. If the switchboard says
`no power`, then check that you are looking at the *switchboard* and not the MCB row beside it — the
MCB row isolates individual circuits and will not energise the supply.

**An interactive object shows amber brackets and `no power`.**
That object is on a circuit that is not energised. The switchboard brings up all four circuits at once;
the MCB row isolates them individually. If a single circuit has been isolated in the workstation's
POWER page, re-energise it from there.

**The monitors are black.**
The monitors need both power *and* the computer to have booted. The tower takes about three seconds:
POST, then a login, then the console. The CRT beside it shows the same process with a static burst at
the start.

**Frame rate is poor.**
Open Settings and select the `medium` quality preset. This disables SDFGI, SSR and volumetric fog,
which together account for roughly 30 ms of the frame on integrated graphics. If it is still
uncomfortable, `low` disables ambient occlusion and MSAA as well.

**The build takes a long time.**
Surface synthesis dominates. Setting the quality preset to `low` before starting reduces the surface
work by 75% and cuts the build roughly in half.

**Text appears as boxes or as separated characters.**
The font failed to load. Confirm that all four `.ttf` files exist in `assets/fonts/` and that Godot
has imported them (they should have `.import` files beside them, generated automatically on first
open). Bengali specifically requires `NotoSansBengali.ttf`.

**The game will not start, or reports a parse error.**
Run the compile validator to find out which script:

```bash
godot --headless --path . -s res://tests/validate_scripts.gd
```

It loads all 37 scripts and reports any that fail to compile.

**`user://` files cannot be found.**
On Windows they are at `%APPDATA%\Godot\app_userdata\Deshi Iron Garage\`. On Linux,
`~/.local/share/godot/app_userdata/Deshi Iron Garage/`. On macOS,
`~/Library/Application Support/Godot/app_userdata/Deshi Iron Garage/`.

---

## 11. Accessibility and comfort notes

- **Head bob** is driven by distance travelled rather than time, so it scales with your speed. There
  is no option to disable it. Holding **Ctrl** to walk slowly reduces it to near zero.
- **Field of view** is adjustable from 65° to 100°.
- **Mouse sensitivity** is adjustable and **vertical look can be inverted**.
- **Motion:** the hologram flickers by design. Its `flicker_amount` can be set to zero from the
  Schematic panel or the graphics bench.
- **Audio:** the rain, the street bed and the mains hum are on separate beds and are all governed by
  the ambience volume, which can be set to zero independently of effects and interface.
- **Reading:** all panels can be closed with the key that opened them or with **Esc**. The objective
  and status panels are informational only and never intercept the mouse.

---

## 12. An abbreviated demonstration script

For showing the project in about six minutes, following the sequence in the brief:

1. Title screen — note the procedurally drawn reactor ring behind the menu.
2. **Start** → the courtyard, the garage, the shutter. Press `E`.
3. Inside. Look down the length of the room: mechanical clutter on the left, the assembly stage and
   the exosuit ahead in the dark.
4. Switchboard on the right wall. Press `E`. **Do not narrate over the light sequence** — the tube
   strike and the fans spinning up are the point.
5. Look at the suit now that the core is pulsing.
6. Walk to the mechanical bench. `E` on the notebook. Read page four: the original sketch.
7. `F` on the engine block, then on the rickshaw wheel. Show the inspection panels.
8. Cross to the electronics bench. `E` on the tower. Let the POST run.
9. Press **Tab**. Show the six sections, then the LOG.
10. `E` on the holographic table. Show the schematic.
11. Collect the three crates. Show the module list filling.
12. `E` on the stage. Install three modules. Start the assembly. **Let it run without talking.**
13. The core ignites, the optics light.
14. `E` on the console in the testing corner. The diagnostic pass runs.
15. **F6**. Materials tab: change roughness and metallic live. Hologram tab: switch between the three
    variants. Lighting tab: switch to warm-only and back to full rig. Post tab: toggle SDFGI and watch
    the core's wall spill disappear.
16. Press **F6** again, walk back out through the shutter, and turn around.
