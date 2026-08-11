# SDF builder helpers

Builder helpers are optional. They exist to reduce common LLM mistakes in XML construction, not to replace SDFormat or libsdformat.

## Why helpers exist

LLMs often make these mistakes when writing raw XML:

- wrong pose value length;
- hidden degree/radian conversion;
- missing `relative_to` or `expressed_in`;
- zero or non-finite joint axes;
- negative primitive dimensions;
- mesh scale applied inconsistently;
- inertial values copied from visuals;
- plugin filenames invented from plausible names.

Helpers should make the common path explicit, typed-ish, and auditable while still returning ordinary `xml.etree.ElementTree.Element` nodes.

## Design constraints

- Standard library only.
- No mandatory Gazebo, ROS, NumPy, lxml, CAD, or mesh dependency.
- Return ElementTree elements.
- Compose with raw ElementTree calls.
- Validate local numeric shape and finiteness.
- Do not attempt full SDFormat schema validation.
- Do not silently invent frames, axes, inertials, plugins, or sensor parameters.

## Recommended helper surface

Names may vary to match the current runtime package, but the helper surface should stay small.

```python
# XML basics
text(parent, tag, value, attrib=None)
fmt_float(value)
fmt_vector(values)

# Poses and axes
pose(parent, xyz=(0, 0, 0), rpy=(0, 0, 0), *, relative_to=None,
     rotation_format="euler_rpy", degrees=False)
quat_pose(parent, xyz=(0, 0, 0), quat_xyzw=(0, 0, 0, 1), *, relative_to=None)
axis(parent, xyz=(0, 0, 1), *, expressed_in=None)

# Document structure
sdf_root(version="1.12")
world(parent, name)
model(parent, name, *, static=None, pose=None)
frame(parent, name, *, attached_to=None, pose=None)
link(parent, name, *, pose=None, inertial=None)
joint(parent, name, joint_type, parent_link, child_link, *, pose=None,
      axis_xyz=None, axis_expressed_in=None, axis2_xyz=None, limits=None)

# Geometry
visual(parent, name, *, pose=None)
collision(parent, name, *, pose=None)
box(parent, size_xyz)
sphere(parent, radius)
cylinder(parent, radius, length)
capsule(parent, radius, length)
mesh(parent, uri, *, scale=None)

# Physics and metadata
inertial(parent, mass, inertia, *, pose=None)
sensor(parent, name, sensor_type, *, pose=None, topic=None, update_rate=None)
plugin(parent, name, filename, params=None)
include(parent, uri, *, name=None, pose=None)
```

## Numeric behavior

Helpers should reject:

- non-finite numbers;
- vectors with the wrong length;
- negative or zero primitive dimensions;
- zero joint axes;
- zero-mass inertials;
- zero-norm quaternions.

Helpers may warn, but should not silently fix:

- non-unit axes;
- non-normalized quaternions;
- use of degrees;
- missing `relative_to` on nontrivial poses.

## Example

```python
from sdf.builder import axis, box, collision, joint, link, model, sdf_root, visual

BASE_SIZE_M = (0.4, 0.3, 0.1)
LIFT_AXIS_Z = (0.0, 0.0, 1.0)


def gen_sdf():
    sdf = sdf_root("1.12")
    robot = model(sdf, "lift_fixture", static=False)

    base = link(robot, "base_link")
    v = visual(base, "base_visual")
    box(v, BASE_SIZE_M)
    c = collision(base, "base_collision")
    box(c, BASE_SIZE_M)

    carriage = link(robot, "carriage_link")
    j = joint(
        robot,
        "lift_joint",
        "prismatic",
        parent_link="base_link",
        child_link="carriage_link",
        axis_xyz=LIFT_AXIS_Z,
        axis_expressed_in="base_link",
    )

    return {
        "xml": sdf,
        "assumptions": [
            {"code": "inertials_placeholder", "message": "Inertials omitted pending measured masses."}
        ],
    }
```

## When not to use helpers

Raw ElementTree is acceptable when:

- a target simulator needs unusual extension XML;
- a plugin has arbitrary nested configuration;
- an existing generator already has a clear internal abstraction;
- the user asked for a minimal XML-only source.

Even then, keep named constants, ledger comments, and validation.
