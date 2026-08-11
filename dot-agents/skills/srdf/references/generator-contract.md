# SRDF generator contract

Define a top-level zero-argument `gen_srdf()` function in a Python source file. It must return an envelope dictionary with the root SRDF XML and the owning URDF path.

```python
import xml.etree.ElementTree as ET


def gen_srdf():
    robot = ET.Element("robot", {"name": "sample_robot"})
    group = ET.SubElement(robot, "group", {"name": "manipulator"})
    ET.SubElement(group, "chain", {"base_link": "base_link", "tip_link": "tool0"})
    return {
        "xml": robot,
        "urdf": "sample_robot.urdf",
    }
```

## Required envelope

```python
{
    "xml": robot_root_element_or_xml_string,
    "urdf": "relative/path/to/robot.urdf",
}
```

The current runtime accepts only `xml` and `urdf` fields. Do not add unsupported fields.

## XML root

The XML root must be:

```xml
<robot name="...">
```

The SRDF `robot` name must match the linked URDF robot name.

## URDF path

The `urdf` field is resolved relative to the generator source file. It must:

- be a non-empty string;
- use POSIX `/` separators;
- be relative, not absolute;
- end in `.urdf`;
- refer to an existing file.

The CLI injects or updates:

```xml
<tcad:urdf path="..."/>
```

The `tcad` prefix is emitted with the `https://text-to-cad.dev/srdf` namespace. The injected path is relative from the generated `.srdf` location to the linked URDF. This metadata is a local SRDF convention for downstream tools; it is not a core SRDF semantic element. Readers also accept existing legacy `<explorer:urdf/>` metadata.

## Supported target forms

```bash
python scripts/srdf path/to/source.py
python scripts/srdf path/to/source.py -o path/to/robot.srdf
python scripts/srdf a.py=out/a.srdf b.py=out/b.srdf
```

The generated output path is selected by the CLI. The generator should not write the `.srdf` file itself.

## Group-state units

Group-state joint values are URDF-native values:

- revolute and continuous joints: radians;
- prismatic joints: meters.

Do not store degrees in SRDF. Legacy UI/protocol degree fields are compatibility aliases and must be converted by joint type.

## Example with common semantic elements

```python
import xml.etree.ElementTree as ET


def gen_srdf():
    robot = ET.Element("robot", {"name": "sample_robot"})

    ET.SubElement(
        robot,
        "virtual_joint",
        {
            "name": "fixed_base",
            "type": "fixed",
            "parent_frame": "world",
            "child_link": "base_link",
        },
    )

    arm = ET.SubElement(robot, "group", {"name": "manipulator"})
    ET.SubElement(arm, "chain", {"base_link": "base_link", "tip_link": "tool0"})

    gripper = ET.SubElement(robot, "group", {"name": "gripper"})
    ET.SubElement(gripper, "joint", {"name": "finger_joint"})

    ET.SubElement(
        robot,
        "end_effector",
        {
            "name": "gripper_eef",
            "parent_link": "tool0",
            "group": "gripper",
            "parent_group": "manipulator",
        },
    )

    home = ET.SubElement(robot, "group_state", {"name": "home", "group": "manipulator"})
    ET.SubElement(home, "joint", {"name": "shoulder_pan_joint", "value": "0.0"})

    ET.SubElement(
        robot,
        "disable_collisions",
        {"link1": "base_link", "link2": "shoulder_link", "reason": "Adjacent"},
    )

    return {"xml": robot, "urdf": "sample_robot.urdf"}
```

Virtual and passive joints are valid SRDF concepts. The current lightweight runtime preserves them but does not yet fully inventory or validate them; verify them with MoveIt Setup Assistant or a MoveIt smoke test.
