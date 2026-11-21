# স্বপ্নের গ্যারেজ — Dream Garage
### The story, the short way

> Told in the product-story style Steve Jobs made famous: short sentences, one idea at a
> time, and the product gets the last word. বাংলা রূপ: `docs/STORY_BN.md`.

**One sentence.** A repair shop in Bangladesh has no factory, no lab, and no new parts —
and it builds a powered exosuit anyway, out of the machines it repairs.

---

**One. The shop.**

Start with a hand on a switch.

The power has been out for a week. One borrowed line, run too long. You push the main
switch, and the room wakes the way it always wakes: tube lights first, then the bench
lamp, then the tower's fans — and then, in the middle of the floor, inside a steel ring,
a small cyan light.

Repair shop. Laboratory. The same room.

That's the whole business. It has always been the same room.

**Two. The country.**

Look at the walls.

Six scientists. One board of firsts — oral rehydration therapy, first proven in a Dhaka
lab. The jute genome. A satellite. A bridge. Solar homes. And thirty photographs of where
all of it happens: rickshaws, tea gardens, brickfields, one farmer holding up his rice.

The most advanced engineering tradition here isn't steel. It's the discipline of making do.

Most people call that a limitation. The shop calls it a curriculum.

**Three. The work.**

The bench is clear.

On the floor: three crates. Frame. Energy. Shells. A motorcycle's bones. Two lead cells
and a coil from a dead flyback. Roof-sheet steel, beaten flat, painted red — by hand.

On the bench: one open notebook. The oldest working thing in the room. A sketch of the
suit — and a promise in a student's handwriting: *A load-bearing demonstration. Not a
weapon. Every joint documented. Every part traceable to a donor.*

That's the entire specification.

**Four. The method.**

Don't invent. Look around.

The CRT's yoke becomes a coupling coil. The scanner's tube becomes the chest core. The
flyback's ferrite ring goes into the power buffer. Every answer is already somewhere in
the shop, waiting in a dead machine to be re-taught.

Jugaad isn't a shortcut. It's a syllabus.

**Five. The test.**

Where does honesty live?

On the deck by the north wall. A rail. A console. A mushroom-headed stop. Diagnostics run.
The trace scrolls. The screen stays dark until the prototype earns it.

The core is a display model, and the room says so where the world can read it.

Fiction about engineering. Never the other way around.

**Six. The light.**

The last module seats. The core comes on.

Nobody claps. One bulb is enough for that.

Then the room does what this room always does at the end of a job: the kettle, two glasses
on the good board, and the plastic chair, angled at the thing you built.

The rain has stopped. Through the shutter: the yard, the flag, the smell of wet dust.

Tomorrow someone will bring a tractor, a roof, a flooded lane. The shop will say what it
has always said.

*Bring it in. We'll see.*

---

> **নিজের প্রযুক্তি, নিজের শক্তি**
> Our own technology, our own strength.

Three machines. One notebook. No factory.

That's how everything worth building gets built.

---

## Say it in one paragraph

*Dream Garage* is a first-person, single-room fiction. You are the engineer of a working
Bangladeshi repair shop on the morning its borrowed power has failed. You restore the
circuits. You read the room — a wall of the country's scientists, a board of its
inventions, a wall of its photographs. And you finish the project the shop had already
begun: a powered exosuit built entirely from the machines the shop repairs. Not a weapon.
Not a replica. A demonstration — documented part by part, tested on a deck with a real
boundary and a real emergency stop.

## The thirty-second viva version

"On the morning you visit this garage, its power has failed. Everything you see is a shop
that repairs machines for a living — in a country whose oldest engineering tradition is
making do. The suit hanging half-built is the answer to one question: how much of a
powered exoskeleton can be built from what a Bangladeshi workshop already knows how to
fix? The answer is on the stand. The room is the proof, built to be walked around."

## Where each scene lives in the build

Every beat is a place, not a paragraph written around a place:

| Beat | In the world | In the build |
|---|---|---|
| The switch | The switchboard's main switch restores the circuits in sequence | `switchboard` station, runtime `set_power()` |
| The waking room | Tube lights, bench lamp, workstation, fans, the cyan core light | always-on bulbs + the light rig, `GarageWorld` boot |
| The country on the walls | Six scientists' plaques, the inventions board, the notice wall, the photo boards | `_scientists_corner()`, `_photo_boards()`, 23 licensed + 5 author-supplied photographs, `docs/ASSET_LICENSES.md` |
| Three crates | Frame, energy, shell — tagged in baked Bengali, each holding a donor-built module | `component_crate` payloads, tag bakes in `_signage()` |
| The notebook | The open sketch on the mechanical bench; the constraints page | `_notebook_spec()` bake |
| Don't invent, look around | CRT yoke → coupling coil; scanner tube → core; flyback ferrite → power buffer | module descriptions in `GameConfig`, donor props |
| The test | Deck, rail, console, diagnostics, the screen that stays dark | `_area_testing()`, the diagnostic screen's station |
| The honesty note | Core is a display model; no weapons; no film reproduction | station text in-world, `docs/PROJECT_OVERVIEW.md` |
| The light | Core activation, eye slits, indicator strips | `runtime.install_core()` |
| Bring it in | The signboard — স্বপ্নের গ্যারেজ / DREAM GARAGE | `SignCanvas` bake, `GameConfig.bangla_labels()` |

## What the story is not

- Not a Marvel story — the armour figure is the shop's own homage build, deliberately
  unbranded, and the stations say so in-world.
- Not a weapons project — a load-bearing demonstration, with a boundary and a stop.
- Not decoration — every beat above has a built location the thesis can cite.
