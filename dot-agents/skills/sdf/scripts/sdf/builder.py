from __future__ import annotations

from collections.abc import Callable, Mapping, Sequence
import math
import xml.etree.ElementTree as ET

Number = int | float
PoseValues = Sequence[Number] | ET.Element | None

def fmt_float(value: object) -> str:
    number = _finite_float(value, "value")
    if number == 0:
        return "0"
    if 1e-4 <= abs(number) < 1e9:
        text_value = f"{number:.12f}".rstrip("0").rstrip(".")
        return text_value or "0"
    return f"{number:.12g}"


def fmt_vector(values: Sequence[object]) -> str:
    return " ".join(fmt_float(value) for value in values)


def text(parent: ET.Element, tag: str, value: object, attrib: Mapping[str, object] | None = None) -> ET.Element:
    child = ET.SubElement(parent, tag, _string_attrib(attrib))
    child.text = str(value)
    return child


def sdf_root(version: str = "1.12") -> ET.Element:
    version_text = str(version or "").strip()
    if not version_text:
        raise ValueError("SDF version must be non-empty")
    return ET.Element("sdf", {"version": version_text})


def world(parent: ET.Element, name: str) -> ET.Element:
    return ET.SubElement(parent, "world", {"name": _required_name(name, "world")})


def model(
    parent: ET.Element,
    name: str,
    *,
    static: bool | None = None,
    pose: PoseValues = None,
) -> ET.Element:
    model_element = ET.SubElement(parent, "model", {"name": _required_name(name, "model")})
    if static is not None:
        text(model_element, "static", "true" if static else "false")
    _append_pose(model_element, pose)
    return model_element


def frame(
    parent: ET.Element,
    name: str,
    *,
    attached_to: str | None = None,
    pose: PoseValues = None,
) -> ET.Element:
    attrib = {"name": _required_name(name, "frame")}
    if attached_to:
        attrib["attached_to"] = str(attached_to)
    frame_element = ET.SubElement(parent, "frame", attrib)
    _append_pose(frame_element, pose)
    return frame_element


def link(parent: ET.Element, name: str, *, pose: PoseValues = None, inertial: Mapping[str, object] | None = None) -> ET.Element:
    link_element = ET.SubElement(parent, "link", {"name": _required_name(name, "link")})
    _append_pose(link_element, pose)
    if inertial:
        inertial_element = inertial_helper(
            link_element,
            inertial["mass"],
            inertial["inertia"],
            pose=inertial.get("pose"),
        )
        del inertial_element
    return link_element


def joint(
    parent: ET.Element,
    name: str,
    joint_type: str,
    parent_link: str,
    child_link: str,
    *,
    pose: PoseValues = None,
    axis_xyz: Sequence[object] | None = None,
    axis_expressed_in: str | None = None,
    axis2_xyz: Sequence[object] | None = None,
    limits: Mapping[str, object] | None = None,
) -> ET.Element:
    joint_element = ET.SubElement(
        parent,
        "joint",
        {
            "name": _required_name(name, "joint"),
            "type": _required_name(joint_type, "joint type"),
        },
    )
    text(joint_element, "parent", _required_name(parent_link, "joint parent"))
    text(joint_element, "child", _required_name(child_link, "joint child"))
    _append_pose(joint_element, pose)
    if axis_xyz is not None:
        axis_element = axis(joint_element, axis_xyz, expressed_in=axis_expressed_in)
        if limits:
            _limit(axis_element, limits)
    if axis2_xyz is not None:
        axis2_element = axis(joint_element, axis2_xyz, expressed_in=axis_expressed_in, tag="axis2")
        if limits and "axis2" in limits and isinstance(limits["axis2"], Mapping):
            _limit(axis2_element, limits["axis2"])
    return joint_element


def pose(
    parent: ET.Element,
    xyz: Sequence[object] = (0, 0, 0),
    rpy: Sequence[object] = (0, 0, 0),
    *,
    relative_to: str | None = None,
    rotation_format: str = "euler_rpy",
    degrees: bool = False,
) -> ET.Element:
    if rotation_format != "euler_rpy":
        raise ValueError("pose() supports rotation_format='euler_rpy'; use quat_pose() for quaternions")
    values = [*_vector(xyz, 3, "pose xyz"), *_vector(rpy, 3, "pose rpy")]
    attrib: dict[str, object] = {}
    if relative_to:
        attrib["relative_to"] = str(relative_to)
    if degrees:
        attrib["degrees"] = "true"
    return text(parent, "pose", fmt_vector(values), attrib)


def quat_pose(
    parent: ET.Element,
    xyz: Sequence[object] = (0, 0, 0),
    quat_xyzw: Sequence[object] = (0, 0, 0, 1),
    *,
    relative_to: str | None = None,
) -> ET.Element:
    quat = _vector(quat_xyzw, 4, "pose quaternion")
    if _norm(quat) == 0:
        raise ValueError("pose quaternion must be nonzero")
    attrib: dict[str, object] = {"rotation_format": "quat_xyzw"}
    if relative_to:
        attrib["relative_to"] = str(relative_to)
    return text(parent, "pose", fmt_vector([*_vector(xyz, 3, "pose xyz"), *quat]), attrib)


def axis(
    parent: ET.Element,
    xyz: Sequence[object] = (0, 0, 1),
    *,
    expressed_in: str | None = None,
    tag: str = "axis",
) -> ET.Element:
    values = _vector(xyz, 3, f"{tag} xyz")
    if _norm(values) == 0:
        raise ValueError(f"{tag} vector must be nonzero")
    axis_element = ET.SubElement(parent, tag)
    attrib = {"expressed_in": str(expressed_in)} if expressed_in else None
    text(axis_element, "xyz", fmt_vector(values), attrib)
    return axis_element


def visual(
    parent: ET.Element,
    name: str,
    *,
    pose: PoseValues = None,
    geometry_builder: Callable[[ET.Element], object] | None = None,
) -> ET.Element:
    owner = ET.SubElement(parent, "visual", {"name": _required_name(name, "visual")})
    _append_pose(owner, pose)
    _call_geometry_builder(owner, geometry_builder)
    return owner


def collision(
    parent: ET.Element,
    name: str,
    *,
    pose: PoseValues = None,
    geometry_builder: Callable[[ET.Element], object] | None = None,
) -> ET.Element:
    owner = ET.SubElement(parent, "collision", {"name": _required_name(name, "collision")})
    _append_pose(owner, pose)
    _call_geometry_builder(owner, geometry_builder)
    return owner


def box(parent: ET.Element, size_xyz: Sequence[object]) -> ET.Element:
    values = _positive_vector(size_xyz, 3, "box size")
    box_element = ET.SubElement(_geometry_parent(parent), "box")
    text(box_element, "size", fmt_vector(values))
    return box_element


def sphere(parent: ET.Element, radius: object) -> ET.Element:
    sphere_element = ET.SubElement(_geometry_parent(parent), "sphere")
    text(sphere_element, "radius", fmt_float(_positive_float(radius, "sphere radius")))
    return sphere_element


def cylinder(parent: ET.Element, radius: object, length: object) -> ET.Element:
    cylinder_element = ET.SubElement(_geometry_parent(parent), "cylinder")
    text(cylinder_element, "radius", fmt_float(_positive_float(radius, "cylinder radius")))
    text(cylinder_element, "length", fmt_float(_positive_float(length, "cylinder length")))
    return cylinder_element


def capsule(parent: ET.Element, radius: object, length: object) -> ET.Element:
    capsule_element = ET.SubElement(_geometry_parent(parent), "capsule")
    text(capsule_element, "radius", fmt_float(_positive_float(radius, "capsule radius")))
    text(capsule_element, "length", fmt_float(_positive_float(length, "capsule length")))
    return capsule_element


def mesh(parent: ET.Element, uri: str, *, scale: Sequence[object] | None = None) -> ET.Element:
    uri_text = str(uri or "").strip()
    if not uri_text:
        raise ValueError("mesh uri must be non-empty")
    mesh_element = ET.SubElement(_geometry_parent(parent), "mesh")
    text(mesh_element, "uri", uri_text)
    if scale is not None:
        text(mesh_element, "scale", fmt_vector(_positive_vector(scale, 3, "mesh scale")))
    return mesh_element


def inertial(parent: ET.Element, mass: object, inertia: Mapping[str, object] | Sequence[object], *, pose: PoseValues = None) -> ET.Element:
    return inertial_helper(parent, mass, inertia, pose=pose)


def sensor(
    parent: ET.Element,
    name: str,
    sensor_type: str,
    *,
    pose: PoseValues = None,
    topic: str | None = None,
    update_rate: object | None = None,
) -> ET.Element:
    sensor_element = ET.SubElement(
        parent,
        "sensor",
        {"name": _required_name(name, "sensor"), "type": _required_name(sensor_type, "sensor type")},
    )
    _append_pose(sensor_element, pose)
    if topic:
        text(sensor_element, "topic", topic)
    if update_rate is not None:
        rate = _finite_float(update_rate, "sensor update_rate")
        if rate < 0:
            raise ValueError("sensor update_rate must be non-negative")
        text(sensor_element, "update_rate", fmt_float(rate))
    return sensor_element


def plugin(
    parent: ET.Element,
    name: str,
    filename: str,
    params: Mapping[str, object] | None = None,
    **extra_params: object,
) -> ET.Element:
    plugin_element = ET.SubElement(
        parent,
        "plugin",
        {
            "name": _required_name(name, "plugin"),
            "filename": _required_name(filename, "plugin filename"),
        },
    )
    for key, value in {**dict(params or {}), **extra_params}.items():
        text(plugin_element, str(key), value)
    return plugin_element


def include(parent: ET.Element, uri: str, *, name: str | None = None, pose: PoseValues = None) -> ET.Element:
    include_element = ET.SubElement(parent, "include")
    text(include_element, "uri", _required_name(uri, "include uri"))
    if name:
        text(include_element, "name", name)
    _append_pose(include_element, pose)
    return include_element


def inertial_helper(
    parent: ET.Element,
    mass: object,
    inertia: Mapping[str, object] | Sequence[object],
    *,
    pose: PoseValues = None,
) -> ET.Element:
    inertial_element = ET.SubElement(parent, "inertial")
    _append_pose(inertial_element, pose)
    text(inertial_element, "mass", fmt_float(_positive_float(mass, "inertial mass")))
    inertia_element = ET.SubElement(inertial_element, "inertia")
    for key, value in _inertia_items(inertia).items():
        text(inertia_element, key, fmt_float(_finite_float(value, f"inertia {key}")))
    return inertial_element


def _limit(parent: ET.Element, values: Mapping[str, object]) -> ET.Element:
    limit_element = ET.SubElement(parent, "limit")
    for key in ("lower", "upper", "effort", "velocity"):
        if key in values:
            text(limit_element, key, fmt_float(_finite_float(values[key], f"limit {key}")))
    return limit_element


def _append_pose(parent: ET.Element, value: PoseValues) -> None:
    if value is None:
        return
    if isinstance(value, ET.Element):
        parent.append(value)
        return
    if len(value) == 6:
        pose(parent, xyz=value[:3], rpy=value[3:])
        return
    if len(value) == 7:
        quat_pose(parent, xyz=value[:3], quat_xyzw=value[3:])
        return
    raise ValueError("pose values must contain 6 Euler values or 7 quaternion values")


def _call_geometry_builder(
    owner: ET.Element,
    geometry_builder: Callable[[ET.Element], object] | None,
) -> None:
    if geometry_builder is None:
        return
    geometry_builder(_geometry_parent(owner))


def _geometry_parent(parent: ET.Element) -> ET.Element:
    if _local_name(parent.tag) == "geometry":
        return parent
    if _local_name(parent.tag) in {"visual", "collision"}:
        existing = next((child for child in list(parent) if _local_name(child.tag) == "geometry"), None)
        return existing if existing is not None else ET.SubElement(parent, "geometry")
    return ET.SubElement(parent, "geometry")


def _inertia_items(inertia: Mapping[str, object] | Sequence[object]) -> dict[str, object]:
    keys = ("ixx", "iyy", "izz", "ixy", "ixz", "iyz")
    if isinstance(inertia, Mapping):
        missing = [key for key in keys if key not in inertia]
        if missing:
            raise ValueError(f"inertia is missing component(s): {', '.join(missing)}")
        return {key: inertia[key] for key in keys}
    if len(inertia) != 6:
        raise ValueError("inertia sequence must contain ixx, iyy, izz, ixy, ixz, iyz")
    return dict(zip(keys, inertia))


def _vector(values: Sequence[object], expected_len: int, label: str) -> list[float]:
    if len(values) != expected_len:
        raise ValueError(f"{label} must contain {expected_len} values")
    return [_finite_float(value, label) for value in values]


def _positive_vector(values: Sequence[object], expected_len: int, label: str) -> list[float]:
    return [_positive_float(value, label) for value in _vector(values, expected_len, label)]


def _finite_float(value: object, label: str) -> float:
    try:
        number = float(value)
    except (TypeError, ValueError) as exc:
        raise ValueError(f"{label} must be numeric") from exc
    if not math.isfinite(number):
        raise ValueError(f"{label} must be finite")
    return number


def _positive_float(value: object, label: str) -> float:
    number = _finite_float(value, label)
    if number <= 0:
        raise ValueError(f"{label} must be positive")
    return number


def _norm(values: Sequence[float]) -> float:
    return math.sqrt(sum(value * value for value in values))


def _required_name(value: object, label: str) -> str:
    text_value = str(value or "").strip()
    if not text_value:
        raise ValueError(f"{label} must be non-empty")
    return text_value


def _string_attrib(attrib: Mapping[str, object] | None) -> dict[str, str]:
    return {str(key): str(value) for key, value in dict(attrib or {}).items() if value is not None}


def _local_name(tag: object) -> str:
    return str(tag).rsplit("}", 1)[-1]
