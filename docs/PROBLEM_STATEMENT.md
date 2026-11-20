# PROBLEM STATEMENT

## 1. The conventional state of the art in workshop visualisation

A very large share of real-time 3D workshop and industrial visualisations are produced as
**static scenes with passive inspection**: a modelled interior, a baked or semi-dynamic light rig, a
camera the user can orbit, and objects that can be looked at but not operated. The rendering may be
excellent while the environment remains a diorama. The user learns what the space looks like and
nothing about how it works or what it is for.

Three specific limitations follow from that structure.

**Materials are decorative rather than parametrised.** Surfaces are authored as image maps whose
metallic and roughness channels were painted by hand or lifted from a photograph. The relationship
between a material's physical parameters and its appearance under the scene's lighting is therefore
neither explicit nor changeable at runtime, so the environment cannot be used to demonstrate the
BRDF behaviour it is displaying.

**Light is additive rather than a system.** Lights are placed to make the shot look good, usually
without isolation, without a defined budget, and without a measurable relationship between the number
of shadow-casting sources and the frame cost. Comparisons between lighting configurations are then
not reproducible.

**Interaction stops at inspection.** A bench is a surface with props on it. A monitor is a texture.
A machine cannot be operated, and there is consequently no way for a user to learn a procedure from
the environment — only to observe objects in it.

## 2. The opportunity

The techniques required to address all three are individually well established and available in a
modern open-source engine. What is less commonly reported is their **integration** in a single
constrained indoor scene: physically based materials whose parameters are exposed and comparable,
a lighting rig organised as switchable circuits with a measured shadow budget, custom shaders that
do work standard materials cannot, generated geometry for detail that would be impractical to model,
and interaction systems deep enough that the environment can be operated rather than only viewed.

That integration, under a real performance constraint and with reproducible measurement, is the
subject of this project.

## 3. Formal problem statement

> Many conventional 3D workshop visualisations present industrial environments as static scenes with
> limited interaction between users and the displayed objects, and with material and lighting
> behaviour that is authored rather than parametrised.
>
> There is an opportunity to develop an interactive real-time 3D workshop environment that combines
> physically based material rendering, dynamic lighting, procedural visual elements and interactive
> engineering-themed components, and to subject that combination to reproducible measurement.
>
> This project proposes an interactive 3D garage environment inspired by a young Bangladeshi
> inventor's vision of a futuristic engineering workshop constructed using locally available and
> salvaged equipment.
>
> The system will allow users to explore the garage, inspect mechanical and electronic objects,
> operate virtual workshop equipment, interact with a prototype exosuit and experience a simulated
> engineering assembly process.
>
> The project will investigate how physically based rendering, emissive shaders, holographic effects,
> procedural geometry and interactive lighting can be integrated to create a visually realistic indoor
> 3D environment while maintaining acceptable real-time rendering performance.

## 4. Scoping the academic claim

The project does **not** claim to introduce a new graphics algorithm. Every technique it uses is
published and implemented in the engine or in the standard literature: microfacet BRDF sampling,
Fresnel approximation, fractal Brownian motion, cellular noise, Sobel normal derivation,
parallel-transport framing, catenary approximation, thresholded HDR bloom, screen-space ambient
occlusion, and analytic fitting for tonemapping.

What is claimed is:

1. **Implementation and integration.** Assembling these techniques into one coherent indoor scene with
   a documented architecture, and resolving the specific problems that arise where they meet — for
   example that a height field shared between albedo, roughness and normal keeps a surface coherent
   where three independently painted maps do not.
2. **Parametrisation and exposure.** Making the material, lighting and shader parameters live and
   addressable at runtime, so the environment is itself the demonstration apparatus.
3. **Measurement.** Producing a reproducible experimental procedure for each technique and reporting
   the measured cost on stated hardware, rather than asserting a quality or performance claim.

The brief's instruction — *do not label all regular Godot material configuration as an original
algorithm* — is followed explicitly. `docs/GRAPHICS_ALGORITHMS.md` marks each of the five
contributions as either **built-in feature configured**, **built-in feature extended**, or
**custom implementation**, and says which.

## 5. Why this setting

The choice of a Bangladeshi garage is not decoration. It is a **constraint that forces the technical
approach.**

A workshop in Dhaka operates with scarce, salvaged and improvised material: a motorcycle frame
becomes a structural spine, two dead IPS batteries become a power module, a corrugated roof sheet
becomes armour plate, a bike fork becomes a robot arm. There is no budget for a modelled asset
library.

That is precisely the situation in which **procedural generation stops being a convenience and
becomes the method.** A project that had access to a large purchased asset pack could demonstrate
material rendering, but it would demonstrate it on content it did not make. A project that must
generate its own content has to justify the generation, and generation is where the interesting
graphics problems live: coherence between channels, physical tiling density, curve-to-tube sweeps,
and the difference between noise that looks like noise and noise that looks like a material.

The setting therefore serves two purposes at once. It is an authentic cultural subject — a genuine
workshop vernacular the reference photographs document in detail — and it is the reason the
technical content is what it is.

## 6. Objectives

**O1.** Build a single detailed indoor garage, 13 m × 16.5 m × 4.6 m, across five visually distinct
areas, with no external 3D model, texture or audio assets.

**O2.** Implement a physically based material system whose metallic, roughness, occlusion and normal
channels are synthesised from a shared height field at a declared physical scale, and expose the
parameters for live comparison.

**O3.** Implement a lighting rig organised as independently switchable circuits, with an explicit and
measurable shadow-casting budget, and with the interior daylight coupled to a moving part of the
architecture.

**O4.** Implement at least three custom spatial shaders that perform work standard materials cannot:
a holographic projection, an emissive energy core, and display glass.

**O5.** Generate cable and conduit geometry procedurally from parameterised curves, and measure how
subdivision count and bundling affect generation cost and rendering cost.

**O6.** Implement a complete interaction layer — raycast focus, contextual prompts, inspection panels
and operable equipment — sufficient that the environment can be *operated*, not only viewed.

**O7.** Implement an interactive assembly sequence for an original fourteen-part exosuit prototype,
driven by a single auditable animation chain.

**O8.** Produce a reproducible measurement procedure covering materials, shaders, lighting, procedural
geometry and post-processing, reporting real figures from the running renderer on stated hardware, and
documenting the limitations that remain.

## 7. Deliverable

A running desktop application, its source, and eight documents covering concept, problem, architecture,
algorithms, methodology, experiments, asset licences and usage. The application must be interactive on
a normal student laptop — not a rendering on a workstation.

## 8. Scope boundaries

Excluded deliberately, following the brief's scope control:

- No outdoor or multi-location world. One garage, plus a small courtyard.
- No combat, enemies, or non-player characters requiring AI.
- No rigged character animation. The exosuit is posed on a static skeleton; the assembly sequence
  animates part transforms.
- No physics simulation of small hand tools. Tools are placed props with simple animation.
- No live electronics engineering. The energy core and the three prototype modules are fictional
  game components; the project contains no battery-modification or powered-armour construction
  instructions, and none of its content is presented as real electrical practice.
- No VR support, despite being listed as an optional extension, in favour of completing and
  documenting the core systems.
