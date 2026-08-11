# URDF Workflow

Use this reference when editing robot-description structure, frame placement, mesh references, inertial data, or generated URDF output.

## Edit Loop

1. Find the Python source that defines `gen_urdf()`.
2. Treat that Python source as source of truth and the `.urdf` file as generated.
3. Identify target consumers and strictness requirements: visualization, TF tree, simulation, planning, or real robot integration.
4. Create or update the design ledger before changing frames, origins, axes, limits, mesh scales, or inertials.
5. Apply URDF frame semantics: joint origin in parent frame, child link frame at joint frame, joint axis in joint frame, visual/collision/inertial origins in link frame.
6. Edit links, joints, limits, axes, origins, inertials, materials, visual/collision geometry, and mesh filenames deliberately in the generator source.
7. Regenerate only the explicit URDF target with `scripts/urdf <source-file>`, `scripts/urdf <source-file> -o <output.urdf>`, or `scripts/urdf <source-file>=<output.urdf>`.
8. Let generation-time validation catch structural and semantic problems. Fix the generator source instead of hand-editing generated XML.
9. If mesh outputs changed, regenerate only the affected explicit outputs with the owning CAD or mesh workflow.
10. Hand generated or modified `.urdf` files to `$cad-viewer` for live viewer links when available.
11. When available, run a consumer smoke test and report what was not checked.

## Spatial-Reasoning Guardrails

LLMs are prone to plausible-looking spatial mistakes. Use these guardrails:

- Do not infer dimensions, handedness, axes, mesh units, or joint signs from vague descriptions.
- Do not silently mirror left/right parts unless the mirror transform and sign changes are explicit.
- Do not assume visual mesh origin equals link frame, collision frame, or center of mass.
- Do not assume CAD mesh units are meters. STL files often carry no reliable unit metadata.
- Do not encode a kinematic correction by offsetting only the visual mesh; correct the link and joint frames unless the visual mesh is genuinely offset.
- Preserve existing proven transforms unless the task explicitly requires changing them.
- Use named constants and comments for assumptions.

## Standard Link Tags

Use these tags for each link that represents physical robot geometry:

- `inertial`: mass, center of mass, and inertia tensor used by simulators.
- `visual`: display geometry and optional material.
- `collision`: contact geometry used by physics and planning.

Frame-only links, such as `base_footprint`, optical frames, or tool-center marker frames, may intentionally omit these tags when they represent no physical mass or geometry.

For movable physical links, avoid zero or missing mass unless the target simulator explicitly supports that modeling choice. If exact mass properties are unavailable, use a documented approximation and make the approximation easy to replace later.

## Joint Authoring

For every joint, confirm:

- parent and child direction are correct;
- joint origin is expressed in the parent link frame;
- child link frame is intended to coincide with the joint frame;
- non-fixed joint axis is expressed in the joint frame;
- positive motion is documented;
- revolute limits are radians;
- prismatic limits are meters;
- continuous joints are not given artificial finite lower/upper limits;
- fixed joints are used for frame relationships and rigid assemblies.

Supported joint types may vary by project runtime. If the validator/runtime supports only `fixed`, `continuous`, `revolute`, and `prismatic`, do not author `floating` or `planar` joints unless the consumer and validation path support them.

## Mesh References

URDF mesh filenames should be stable from the generated URDF file's perspective or use a package URI convention understood by the consumer.

The current `scripts/urdf` validation path accepts any non-empty mesh filename or URI. Local relative mesh paths are checked relative to the generated URDF file; `package://...` and remote references are left unresolved with warnings unless a package map is supplied through `read_urdf_source()`.

When using package URIs, confirm the consuming environment resolves the package root the same way as the generated URDF expects.

Do not use generated URDF XML as the source of truth for mesh placement. Prefer deriving visual mesh references from the same source data that owns the mesh instance placement.

When mesh references point to generated assets, keep the ownership clear:

- CAD or mesh workflows own mesh generation;
- URDF generation owns references, scales, and placements;
- SRDF/MoveIt workflows own semantic groups, named joint poses via `<group_state>`, and planning metadata.

## Collision Geometry

Add collision geometry under each `<link>` that should participate in physics, contact, or collision-aware planning. Do not encode collision behavior on joints.

Use one or more `<collision>` blocks per link. The `<origin>` is expressed in the link frame, just like `<visual>`, and mesh scales must match the units of the exported mesh:

The current `scripts/urdf` validator allows visual and collision geometry to use `<mesh>`, `<box>`, `<cylinder>`, or `<sphere>`.

```xml
<link name="forearm_link">
  <visual>
    <origin xyz="0 0 0" rpy="0 0 0" />
    <geometry>
      <mesh filename="package://robot_description/meshes/forearm.stl" scale="0.001 0.001 0.001" />
    </geometry>
  </visual>
  <collision>
    <origin xyz="0.12 0 0" rpy="0 1.57079632679 0" />
    <geometry>
      <cylinder radius="0.035" length="0.24" />
    </geometry>
  </collision>
</link>
```

Prefer simplified collision geometry over detailed visual meshes. Good options, from simplest to most specific:

- primitive `<box>`, `<cylinder>`, or `<sphere>` geometry when it approximates the part well;
- a coarse, closed collision mesh exported from CAD;
- the visual mesh as a temporary fallback for loading and smoke tests.

In generator sources, model collisions explicitly rather than hand-editing generated URDF. A common pattern is to add a `collisions` collection beside `visuals` in each link spec and emit it with the same origin and scale helper code used for visual meshes.

## Inertials

For each physical link, use an explicit `inertial` block when the target simulator or dynamics consumer needs mass properties.

The inertial origin is the center of mass in the link frame. It is not automatically the visual mesh origin, collision origin, or link origin.

When exact mass properties are unavailable, use a documented approximation and make it easy to replace. Mark approximate mass, COM, and inertia constants clearly.

## Smoke Tests

After generation-time validation, use the most relevant available smoke test:

- load in RViz or equivalent visualization to inspect visible placement;
- run robot_state_publisher or equivalent to check the TF tree;
- load in Gazebo/Ignition or another simulator for physics consumers;
- load in MoveIt only after URDF structure is stable, then handle semantic data through the SRDF workflow.

Report the smoke tests run and any skipped checks that would materially affect confidence.
