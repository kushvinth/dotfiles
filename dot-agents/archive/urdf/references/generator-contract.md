# URDF Generator Contract

Use this reference when creating or editing Python sources that generate URDF files.

## Source of Truth

The Python source that defines `gen_urdf()` is source of truth. The configured `.urdf` file is generated and should not be hand-edited.

Keep the design ledger close to the source. At minimum, generator source should make units, frame conventions, parent/child choices, joint axes, mesh scale, and assumptions easy to audit.

## Contract

`gen_urdf()` must be a top-level zero-argument function that returns one of:

- the root `xml.etree.ElementTree.Element` for a complete URDF document;
- a complete URDF XML string;
- an envelope dict with exactly one field, `xml`, whose value is an `ElementTree.Element` or XML string.

Default generator shape:

```python
import xml.etree.ElementTree as ET


def gen_urdf():
    robot = ET.Element("robot", {"name": "sample"})
    ET.SubElement(robot, "link", {"name": "base_link"})
    return robot
```

When an envelope is needed, set `xml` to the same root element or XML string:

```python
def gen_urdf():
    robot = ET.Element("robot", {"name": "sample"})
    ET.SubElement(robot, "link", {"name": "base_link"})
    return {"xml": robot}
```

Do not include output-path, validation, Explorer, pose-preset, or consumer metadata in the envelope. The current runtime rejects fields such as `urdf_output`, `validate`, and `explorer_metadata`; output paths are selected only by CLI arguments. Named robot poses belong in SRDF `<group_state>` elements, not URDF-side `explorer.json` or Explorer metadata artifacts.

The CLI serializes the returned payload, writes the configured `.urdf` output path, and validates that generated file before returning success.

The generated `.urdf` output path is selected by the CLI. A plain source target writes a sibling `.urdf`; `-o`/`--output` overrides one target; `SOURCE.py=OUTPUT.urdf` pairs override individual targets.

The host project may impose its own layout policy, but the URDF skill runtime does not hardcode a project directory.

## Authoring Expectations

Use explicit constants for physical dimensions, joint locations, joint limits, mesh scale, and inertial values. Avoid anonymous literals in joint origins and axes.

Prefer:

```python
BASE_TO_SHOULDER_Z_M = 0.240
SHOULDER_PAN_AXIS = (0.0, 0.0, 1.0)
FOREARM_MESH_SCALE_FROM_MM = (0.001, 0.001, 0.001)
```

Over:

```python
origin="0 0 0.24"
axis="0 0 1"
scale="0.001 0.001 0.001"
```

Document assumptions directly in comments near the constants or in `references/design-ledger.md` style project documentation.

## Frame and Unit Rules

Generators must emit URDF values in the project's URDF unit convention, normally meters, kilograms, seconds, and radians.

Before emitting a joint, confirm:

- the parent and child link names are correct;
- the joint origin is expressed in the parent link frame;
- the child link frame is intended to coincide with the joint frame;
- the joint axis is expressed in the joint frame;
- revolute limits are radians;
- prismatic limits are meters;
- continuous joints do not get fake finite lower/upper limits.

Before emitting visual, collision, or inertial data, confirm:

- its origin is expressed in the owning link frame;
- mesh scale converts mesh source units into meters;
- collision geometry is intentionally simplified or intentionally identical to visual geometry;
- inertial origin represents the center of mass, not merely the visual origin.

The current `scripts/urdf` validation path accepts any non-empty mesh filename or URI, checks local file existence when the URI resolves locally, and leaves mesh-format loadability to the target URDF consumer. Visual and collision geometry may use `<mesh>`, `<box>`, `<cylinder>`, or `<sphere>`.

## Runtime Behavior

`scripts/urdf` runs only `gen_urdf()`. It does not regenerate external CAD, mesh/export, GLB/topology, render, SDF, or SRDF/MoveIt2 artifacts.

If URDF visual/collision mesh references depend on updated CAD or mesh outputs, regenerate those explicit targets separately with the owning CAD or mesh workflow.

Importing a generator module executes its top-level Python code. Keep top-level generator modules deterministic and side-effect-light. Place expensive or mutating work behind `gen_urdf()` only when the task explicitly requires it.

## Paths

Relative source targets and CLI output paths resolve from the current working directory.

Inside generator code, prefer paths derived from the generator file or package conventions over implicit shell working-directory assumptions. Mesh filenames emitted into URDF should be stable from the generated `.urdf` file's perspective or use a package URI understood by the consumer.
