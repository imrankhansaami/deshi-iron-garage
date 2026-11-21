# স্বপ্নের গ্যারেজ — Dream Garage
### The project's story, written for the thesis

**Logline.** In a one-room iron workshop in Bangladesh, a young engineer rolls up the
shutter, brings the power back, and finishes building the powered exosuit the shop
sketched in its notebook years earlier — from a motorcycle frame, a dead IPS battery,
a corrugated roof sheet, and whatever else the bench borrowed from other machines.

---

## The story

**1. The dark shop.** It is monsoon morning, and the rain is drumming on the tin roof —
that particular sound every workshop in this country shares, proud percussion over the
traffic. The shutter has been down for a week. The main switch is down too: the shop had
been running off one borrowed circuit for months, and the borrowed circuit finally gave
up. So the day starts where every working day starts — at the switchboard, on the west
wall, under the danger notice, hand on the main switch.

Power comes back up in order, the way it always does: the tube lights stutter awake, the
bench lamp warms, the workstation tower exhales its fans, and finally, out in the
assembly bay, something at the centre of a steel ring clears its throat with a small cyan
light. Around you the room remembers what it is. Repair shop. Laboratory. Both, always.

**2. The country on the walls.** Between the bench and the photographs, the shop tells you
what it believes. There is a wall of scientists this country claims — six plaques, names
with dates, a line for each life's work. There is a board of things this country built or
proved: oral rehydration therapy, first proven in a Dhaka laboratory; the jute genome; the
first satellite; the Padma bridge; the solar home programme. And there is a plywood board
of thirty-odd photographs — rickshaws, tea gardens, brickfields, a village farmer holding
up his rice — because the shop has never separated the work from the country it is done in.

The oldest engineering discipline in this country, the walls say, is not steel. It is
making do.

**3. The three crates.** The bench has been cleared — you can tell because everything on it
has been moved at least once today. On the floor beside it stand three crates with
hand-lettered tags. The frame crate holds what is left of a 100 cc motorcycle and a
notebook column of dimensions. The energy crate holds two lead cells, a buffer board, and
a coupling coil lifted off a dead flyback. The shell crate holds plates rolled from a
corrugated roof sheet and taken to with a hammer and the shop's own red paint.

The notebook lying open on the bench is the oldest thing in the room that still does work:
a first sketch of the suit in construction lines, and a page of constraints in a dry
student hand — *a load-bearing demonstration, not a weapon; every joint documented; every
part traceable to a donor.* The brief was never to invent something new. The brief was to
prove something old: that the machines this country already repairs, all day, everywhere,
contain every lesson a powered exoskeleton needs.

**4. The stand.** In the middle of the bay the suit hangs half-finished on its stand — a
spine column, a torso cradle, limbs ending in careful splints where the next module goes.
It has been built the way this shop builds everything: find the machine that already
solved your problem, take it gently apart, and re-teach it its lesson in a different
shape. The CRT's yoke sits inside the coupling coil. The scanner's tube is in the chest,
reading as a core. A flyback ferrite ring is in the power buffer. Jugaad is not a
shortcut here. It is the syllabus.

**5. The test.** The testing corner by the north wall is where the fiction stays honest.
Its deck, its rail, its console with the mushroom-headed stop: nothing there runs on
faith. Diagnostics run, the trace scrolls, the boundary stays up — and the display wakes
only when the prototype deserves it. The core is a display model, and the project says so
where the world can read it. This is a fiction about engineering, not engineering fiction.

**6. The light.** When the last module seats and the core lights for the first time,
nobody applauds. One bulb is enough for that. Instead the room does what this room always
does at the end of a job: the kettle goes on, two glasses stand on the good board, and you
sit in the plastic chair to look at the thing you built. The rain has stopped. Through the
open shutter come the yard, the flag, and the smell of wet dust.

Tomorrow someone will arrive with a problem — a tractor, a roof, a flooded lane — and the
shop will say what it has always said.

*Bring it in. We'll see.*

---

> **নিজের প্রযুক্তি, নিজের শক্তি**
> *Our own technology, our own strength.*

---

## Where the story lives in the build

Every beat above is a place in the room, not a paragraph written around the room. For the
thesis chapter, the mapping is:

| Beat | In the world | In the build |
|---|---|---|
| The dark shop | Press the switchboard's main switch; circuits restore in sequence — tube lights, bench lamp, workstation, fans, reactor zone | `switchboard` station, the runtime's `set_power()` sequence, the five always-on bulbs |
| The shutter | The gate rolls up at the start of the session | shutter animation + apron, `GarageWorld` boot |
| The country on the walls | The six scientists' plaques, the inventions board, the notice wall and the two photo boards | `_scientists_corner()`, `_photo_boards()`, 23 licensed photographs + 5 supplied by the author, `docs/ASSET_LICENSES.md` |
| The three crates | Frame, energy and shell crates, each tagged in baked Bengali, each holding a donor-built module | `component_crate` prop with `frame`/`energy`/`shell` payloads, tag bakes in `_signage()` |
| The notebook | The open page on the mechanical bench: the first sketch, dimensions, the constraints | `_notebook_spec()` bake; the sketch's dimensions are the stand's real ones |
| The stand | The suit hangs on its spine column and torso cradle, feet inside the reactor pedestal — the mounting fixture, exactly as drawn | `suit_stand`, `ExosuitFactory` build + `runtime.install_suit()` |
| Jugaad donors | The CRT's yoke, the scanner's tube, the flyback ferrite, the roof-sheet plates | `props_daily`/`props_proto` donors, module descriptions in `GameConfig` |
| The test | Deck, rail, console, diagnostics, the display that wakes when the prototype is complete | `_area_testing()`, `tests/` harness, the diagnostic screen's station |
| The honesty note | Core is a display model; no weapons; no film reproduction | station text in-world, `docs/PROJECT_OVERVIEW.md` stance |
| The light | Core activation, eye slits, indicator strips, glow ring | `runtime.install_core()`, light rig |
| নিজের প্রযুক্তি, নিজের শক্তি | The signboard — স্বপ্নের গ্যারেজ / DREAM GARAGE | `SignCanvas` bake, `GameConfig.bangla_labels()` |

## The story in one paragraph (abstract version)

*Dream Garage* is a first-person, single-room fiction: you arrive at a working
Bangladeshi iron workshop on the morning its borrowed power has failed, and you are its
engineer. You restore the circuits, read the room — a wall of the country's scientists,
a board of its inventions, a wall of its photographs — and finish the project the shop
had already begun: a powered exosuit built entirely from the machines the workshop
repairs. The suit is not a weapon and not a replica; it is an engineering demonstration,
documented part by part, tested on a deck with a real boundary and a real emergency
stop. The story's argument is the country's own: nothing here was invented in this room
except the proof that it could be made here.

## What the story is not

- It is not a Marvel story. The armour figure is the shop's own homage build in a red
  and gold palette, deliberately unbranded; the stations say so in-world.
- It is not a weapons project. The suit is a load-bearing demonstration; the core is a
  display model; the deck has a boundary for a reason.
- It is not decoration. Every story beat above has a built location, and the thesis can
  cite the location — that is what this document is for.

## The sixty-second viva version

"On the morning you visit this garage, its power has failed. Everything you see — the
bench, the crates, the stand, the test deck — is a workshop that repairs machines for a
living, in a country whose oldest engineering tradition is making do. The suit hanging
half-built is the shop's answer to a question an engineering student would ask: how much
of a powered exoskeleton can be built from what a Bangladeshi workshop already knows how
to fix? The answer is hanging on the stand, and the room — the switchboard, the notebook,
the crates, the diagnostics deck — is the proof, built to be walked around."
