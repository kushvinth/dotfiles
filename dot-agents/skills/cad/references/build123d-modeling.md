# build123d modeling patterns

Read this file when writing or repairing build123d Python source.

## Modeling objective

Create a valid STEP-ready BREP model, not a visual mesh. Prefer closed solids, explicit labels, and stable parametric dimensions. Define `gen_step()` returning the STEP-ready shape or labeled compound; the CLI owns output paths (see `step-generation.md`).

## Design strategy

Decide how the part is constructed before writing geometry code:

- **Choose the construction that makes the spec's dimensions direct parameters.** Profile-driven shapes get one closed sketch plus `extrude`/`revolve`/`sweep`/`loft`; block-and-feature parts get a base solid plus subtractive features. Prefer whichever construction lets the user's controlling dimensions appear as named parameters instead of derived values.
- **Decide part vs assembly before modeling.** Bodies that are separately manufactured, purchased, or movable belong in a labeled assembly (see `positioning.md`); monolithic manufacturing intent gets a single fused solid. Avoid unlabeled compounds of solids — multi-body output without occurrence labels loses traceability in inspection and viewer review.
- **Pick the origin and orientation from the functional datum before sculpting.** Model on the mating interface, mounting plane, or symmetry axis; see `positioning.md` for part-type origin defaults.
- **Order operations so fragile steps come last and failures localize.** Base solid → major additions → subtractive features → shell → through-wall holes → fillets and chamfers last. Fillets are the most failure-prone operation and every boolean invalidates selectors, so postpone them. Structure the source so each feature is a named step — a per-feature function or a distinct intermediate variable — so a failed operation points at exactly one feature and a parameter change touches one obvious place.
- **Overshoot boolean tools.** Extend cutting tools past the faces they enter and exit; for through-cuts, go roughly 1 mm beyond both faces. Coincident or coplanar tool/target faces are a classic kernel failure. Cut repeated or patterned features in one combined operation.
- **Sanity-check proportions before generating.** Compare the expected bounding box against the real-world object, wall thickness against overall size, and feature positions against edges and neighboring features. Order-of-magnitude and collision errors pass geometric validation but fail visual review.

## Topology stack

Think in this order:

```text
Vertex → Edge → Wire → Face → Shell → Solid → Compound
```

For assemblies, use these repo topology terms consistently:

- **Occurrence**: a placed node in the assembly tree. An occurrence has a parent, transform, path, and user-facing role such as `lid` or `m3_screw:front_left`.
- **Shape**: an exported geometry/body inside an occurrence. Shape rows own topology; faces and edges belong to a shape, and the shape belongs to an occurrence.
- **Face/edge**: selectable topology owned by a shape. Do not assume arbitrary faces or edges have persistent intent labels; inspect them by occurrence, shape, ordinal, surface/curve type, and measured geometry.

When inspecting topology, follow `assembly occurrence -> shape/body -> faces -> edges`. Every face/edge row should be traceable through both `occurrenceId` and `shapeId`.

For normal STEP output, return one of:

- a valid `Solid`
- a compound of valid solids
- a labeled assembly compound

Avoid returning loose wires, open faces, or construction surfaces unless the user explicitly requested them.

## Parameters first

Put meaningful dimensions in named variables:

```python
width = 80.0
depth = 50.0
thickness = 6.0
hole_diameter = 4.5
hole_offset_x = 30.0
hole_offset_y = 17.5
```

Avoid burying important numbers inside geometry calls.

## Coordinate system

Declare or comment the convention:

```text
Origin: center of primary part or chosen mating datum
XY: main base/sketch plane
+Z: up/extrusion direction
```

Use `Location`, `Plane`, and `Axis` intentionally. For positioning-sensitive tasks and source-level assembly relationships, read `positioning.md`.

## Builder contexts

Use the context that matches the geometry:

```python
with BuildLine() as path:
    ...

with BuildSketch() as profile:
    ...

with BuildPart() as part:
    ...
```

Typical flow:

```text
curves/paths → sketches/profiles → solids/features → labels → STEP
```

## Selection practices

Avoid fragile topology order when possible. Select by:

- axis or normal
- location or bounding position
- plane grouping
- feature intent
- stable construction plane
- inspected local selector ref for downstream validation

For source operations, prefer robust selectors such as top/bottom by axis or position rather than arbitrary list indexes.


## Assemblies and positioning

For assemblies, keep this file focused on BREP modeling patterns and labels. Use `positioning.md` as the single source of truth for:

- part-local coordinate conventions
- when to use `cadpy.assembly.AssemblyHelper`, build123d joints, or explicit `Location` transforms
- `connect_to()` behavior
- CLI `inspect align` as read-only selector-pair alignment validation
- frame, measure, and positioning report expectations

## Labels and assemblies

Label every exported part and assembly child with native build123d labels. Prefer concise intent labels through `cadpy.assembly` helpers:

```python
from cadpy.assembly import AssemblyHelper, label_shape

asm = AssemblyHelper("electronics_enclosure")
base = asm.add(make_base(), "base")
lid = asm.add(make_lid(), "lid")

boss = label_shape(Cylinder(radius=3.0, height=12.0), "m3_boss", "front_left")
```

Do not prefix labels with topology categories like assembly, component, feature, datum, mate, or hardware. The assembly tree and topology inspection already expose those structural categories. Use labels for the intent topology cannot reliably infer: role, placement, interface, repetition, or mating purpose. Feature labels survive STEP export best when the feature remains a labeled child shape in a `Compound`; boolean-subtracted or fused feature history should be represented by source parameters, named datums, and validation refs instead of assumed persistent feature labels.

Label for inspection:

- Label the root assembly.
- Label every exported part, subassembly/module, and repeated component occurrence.
- Use occurrence labels for assembly role and placement, especially repeated parts: `m3_screw:front_left`, `m3_screw:rear_right`.
- Use shape labels for retained exported geometry/body roles where useful.
- Use feature/datum labels only when that geometry remains exported as a child shape.
- Use named mate datums for source-level positioning intent, then validate the exported STEP topology and occurrence frames.

Occurrence and shape labels are exported through STEP names and surfaced in `STEP_topology` when available. The viewer uses occurrence labels for assembly/tree references and shape labels for shape references. Faces and edges inherit their context from `occurrenceId` and `shapeId`; do not promise persistent face/edge intent labels unless explicit tested support exists.

For repeated parts, keep occurrence labels, transforms, or joint connections explicit and inspect frames/positioning after generation.

## Common failure modes

- Fillet radius larger than local edge geometry.
- Open sketch profile produces invalid or missing face.
- Face selector changes after a boolean or fillet.
- Part origin is arbitrary and later alignment checks become ambiguous.
- Source-level joints are treated as if they were persistent STEP constraints rather than one-time source placement operations.
- Joint labels are missing, duplicated, or attached to the wrong local datum.
- `.connect_to()` fixes the wrong side of the relationship, moving the part intended to remain fixed.

Use `repair-loop.md` when generation or validation fails.
