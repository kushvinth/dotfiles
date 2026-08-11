# URDF Generation-Time Validation

Use this reference to understand what generated URDFs should satisfy. The `scripts/urdf` generation path validates by default; there is no separate validation-only command in this skill.

Validation is a guardrail, not a substitute for a design ledger or visual/consumer smoke test. A URDF can pass structural checks while still having incorrect spatial assumptions.

Generated or modified `.urdf` files should be handed to `$cad-viewer` for live viewer links when available.

## Structural Checks

Validate that:

- the root element is `<robot>`;
- the robot has a non-empty name;
- every link has a unique non-empty name;
- every joint has a unique non-empty name;
- every joint has valid parent and child fields;
- parent and child links exist;
- each child link has at most one parent;
- the graph has exactly one root link;
- the graph is connected and acyclic;
- the tree has exactly `links - 1` joints unless the design intentionally uses a different structure and the runtime supports it.

## Origin Checks

For each joint, visual, collision, and inertial origin, validate or review that:

- `xyz` has three finite numeric values when present;
- `rpy` has three finite numeric values when present;
- omitted values follow the URDF default only when that is intentional;
- units are meters for `xyz` and radians for `rpy`;
- the origin is expressed in the correct frame.

Frame correctness must be reviewed from the design ledger. XML validation alone cannot prove that an origin is spatially correct.

## Joint Checks

The current `scripts/urdf` source reader supports these joint types:

- `fixed`
- `continuous`
- `revolute`
- `prismatic`

Some URDF consumers also support `floating` and `planar`; use them only when the project runtime and validation path support them. The current `scripts/urdf` reader rejects them.

For non-fixed joints, validate or review that:

- `<axis>` exists where required;
- axis has exactly three finite numeric values;
- axis is nonzero;
- axis is normalized or intentionally normalized by generator code;
- axis is expressed in the joint frame;
- positive motion is documented in the design ledger.

For limits:

- `revolute` lower/upper limits are radians;
- `prismatic` lower/upper limits are meters;
- lower is not greater than upper;
- effort and velocity are finite when present;
- `continuous` joints do not use artificial finite lower/upper limits;
- `fixed` joints do not need motion limits.

## Geometry Checks

General URDF visual and collision geometry may use:

- `<mesh>`
- `<box>`
- `<cylinder>`
- `<sphere>`

The current `scripts/urdf` validation path allows these geometry types for both visual and collision geometry.

For geometry, validate or review that:

- each visual or collision block has a `<geometry>` element;
- each geometry block has exactly one supported geometry child;
- primitive dimensions are positive and finite;
- mesh filenames are non-empty;
- mesh scale, when present, has three positive finite values;
- visual and collision origins are relative to the owning link frame;
- collision geometry is appropriate for the target consumer.

## Mesh Reference Checks

For mesh references, distinguish syntax, local existence, and runtime package resolution.

Validate or review that:

- local relative and absolute paths are intentional;
- local files exist when filesystem validation is available;
- `package://...` URIs have valid syntax;
- package URIs are not incorrectly assumed to resolve from the current working directory;
- the consuming ROS or simulator environment can resolve package URIs;
- mesh source units and emitted scale convert to meters.

The current source reader accepts any non-empty mesh filename or URI. It resolves local mesh paths from the generated URDF file's directory and verifies those files exist. It accepts unresolved `package://...` and remote references with warnings, because final mesh-format support is consumer-specific.

If mesh references changed, confirm the corresponding mesh outputs were regenerated separately by the owning CAD or mesh workflow.

## Inertial Checks

For each physical link with mass or geometry, prefer an explicit `inertial` block:

- `origin` is the center of mass in the link frame;
- `mass` is positive and finite;
- `inertia` defines `ixx`, `ixy`, `ixz`, `iyy`, `iyz`, and `izz`;
- all inertia values are finite;
- diagonal inertia values are positive;
- the inertia matrix is physically plausible for the intended approximation;
- approximations are documented.

Frame-only links may intentionally omit `inertial`. Physical links with omitted inertials should be called out when the target consumer uses simulation or dynamics.

## URDF Validity vs Project Policy

Separate general URDF validity from project-specific policy.

Examples of general URDF validity or sanity checks:

- unique links and joints;
- valid tree structure;
- valid joint parent/child references;
- finite origins;
- nonzero movable-joint axes;
- positive primitive dimensions;
- positive mass for physical inertial blocks.

Examples of project policy checks:

- visual mesh references must use a specific extension;
- visual geometry must be mesh-only;
- collision geometry must be primitive-only;
- mesh files must live under a specific directory;
- every physical link must have collision geometry;
- every physical link must have inertial data;
- package URIs must use a specific package prefix.

When a generated URDF fails because of project policy, report it as policy failure, not as universal URDF invalidity.

## Failure Handling

When generation-time validation fails:

1. fix the generator source, design ledger, or referenced assets;
2. regenerate the explicit URDF target;
3. do not hand-edit the generated `.urdf` as a permanent fix;
4. record any remaining assumptions or unchecked spatial claims.

## Tooling

Use `scripts/urdf/source.py` through the `urdf.source.read_urdf_source()` helper for compact robot/link/joint checks when writing tests or focused checks.

The URDF source reader is a lightweight standard-library validator. It checks the generated subset used by this skill; consumer-specific parser and mesh-loading compatibility should still be smoke-tested in the target runtime when confidence matters.
