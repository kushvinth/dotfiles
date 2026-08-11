from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from math import degrees, isfinite
from pathlib import Path, PurePosixPath
from urllib.parse import unquote, urlparse
import warnings
import xml.etree.ElementTree as ET

URDF_SUFFIX = ".urdf"
SUPPORTED_JOINT_TYPES = {"fixed", "continuous", "revolute", "prismatic"}
SUPPORTED_GEOMETRY_TAGS = {"box", "cylinder", "mesh", "sphere"}


class UrdfSourceError(ValueError):
    pass


class UrdfSourceWarning(UserWarning):
    pass


class MeshUriKind(Enum):
    LOCAL_RELATIVE = "local_relative"
    LOCAL_ABSOLUTE = "local_absolute"
    PACKAGE = "package"
    REMOTE = "remote"


@dataclass(frozen=True)
class MeshReference:
    uri: str
    kind: MeshUriKind
    path: Path | None = None
    package_name: str | None = None
    package_path: PurePosixPath | None = None


@dataclass(frozen=True)
class UrdfJoint:
    name: str
    joint_type: str
    parent_link: str
    child_link: str
    min_value_deg: float | None
    max_value_deg: float | None


@dataclass(frozen=True)
class UrdfSource:
    file_ref: str
    source_path: Path
    robot_name: str
    root_link: str
    links: tuple[str, ...]
    joints: tuple[UrdfJoint, ...]
    mesh_paths: tuple[Path, ...]
    visual_mesh_paths: tuple[Path, ...] = ()
    collision_mesh_paths: tuple[Path, ...] = ()


def file_ref_from_urdf_path(urdf_path: Path) -> str:
    resolved = urdf_path.resolve()
    if resolved.suffix.lower() != URDF_SUFFIX:
        raise UrdfSourceError(f"{resolved} is not a URDF source file")
    return _relative_to_repo(resolved)


def read_urdf_source(urdf_path: Path, *, package_map: dict[str, Path] | None = None) -> UrdfSource:
    resolved_path = urdf_path.resolve()
    if resolved_path.suffix.lower() != URDF_SUFFIX:
        raise UrdfSourceError(f"{resolved_path} is not a URDF source file")

    try:
        root = ET.fromstring(resolved_path.read_text(encoding="utf-8"))
    except (OSError, ET.ParseError) as exc:
        raise UrdfSourceError(f"{_relative_to_repo(resolved_path)} could not be parsed as URDF XML") from exc

    if root.tag != "robot":
        raise UrdfSourceError(f"{_relative_to_repo(resolved_path)} root element must be <robot>")
    robot_name = str(root.attrib.get("name") or "").strip()
    if not robot_name:
        raise UrdfSourceError(f"{_relative_to_repo(resolved_path)} robot name is required")

    link_names = []
    for link_element in root.findall("link"):
        name = str(link_element.attrib.get("name") or "").strip()
        if not name:
            raise UrdfSourceError(f"{_relative_to_repo(resolved_path)} link name is required")
        link_names.append(name)
    if not link_names:
        raise UrdfSourceError(f"{_relative_to_repo(resolved_path)} must define at least one link")
    _raise_on_duplicates(link_names, source_path=resolved_path, label="link")
    link_name_set = set(link_names)
    _validate_link_inertials(root, source_path=resolved_path)

    visual_mesh_paths: list[Path] = []
    collision_mesh_paths: list[Path] = []
    for link_element in root.findall("link"):
        visual_mesh_paths.extend(
            _geometry_mesh_paths(
                link_element,
                element_name="visual",
                source_path=resolved_path,
                package_map=package_map,
            )
        )
        collision_mesh_paths.extend(
            _geometry_mesh_paths(
                link_element,
                element_name="collision",
                source_path=resolved_path,
                package_map=package_map,
            )
        )

    joints = []
    joint_names = []
    parent_by_child: dict[str, str] = {}
    children = set()
    joints_by_parent: dict[str, list[str]] = {}
    for joint_element in root.findall("joint"):
        name = str(joint_element.attrib.get("name") or "").strip()
        if not name:
            raise UrdfSourceError(f"{_relative_to_repo(resolved_path)} joint name is required")
        joint_names.append(name)
        joint_type = str(joint_element.attrib.get("type") or "").strip().lower()
        if joint_type not in SUPPORTED_JOINT_TYPES:
            raise UrdfSourceError(
                f"{_relative_to_repo(resolved_path)} joint {name!r} uses unsupported type {joint_type!r}"
            )
        _validate_origin(
            joint_element.find("origin"),
            source_path=resolved_path,
            label=f"joint {name!r} origin",
        )
        _validate_joint_axis(joint_element, joint_type=joint_type, source_path=resolved_path)
        parent_element = joint_element.find("parent")
        child_element = joint_element.find("child")
        parent_link = str(parent_element.attrib.get("link") if parent_element is not None else "").strip()
        child_link = str(child_element.attrib.get("link") if child_element is not None else "").strip()
        if not parent_link or not child_link:
            raise UrdfSourceError(
                f"{_relative_to_repo(resolved_path)} joint {name!r} must define parent and child links"
            )
        if parent_link not in link_name_set:
            raise UrdfSourceError(
                f"{_relative_to_repo(resolved_path)} joint {name!r} references missing parent link {parent_link!r}"
            )
        if child_link not in link_name_set:
            raise UrdfSourceError(
                f"{_relative_to_repo(resolved_path)} joint {name!r} references missing child link {child_link!r}"
            )
        if child_link in parent_by_child:
            raise UrdfSourceError(
                f"{_relative_to_repo(resolved_path)} link {child_link!r} has multiple parents"
            )
        parent_by_child[child_link] = parent_link
        children.add(child_link)
        joints_by_parent.setdefault(parent_link, []).append(child_link)
        min_value_deg, max_value_deg = _joint_limits_deg(joint_element, joint_type=joint_type, source_path=resolved_path)
        joints.append(
            UrdfJoint(
                name=name,
                joint_type=joint_type,
                parent_link=parent_link,
                child_link=child_link,
                min_value_deg=min_value_deg,
                max_value_deg=max_value_deg,
            )
        )

    _raise_on_duplicates(joint_names, source_path=resolved_path, label="joint")
    root_candidates = [link_name for link_name in link_names if link_name not in children]
    if len(root_candidates) != 1:
        raise UrdfSourceError(
            f"{_relative_to_repo(resolved_path)} must form a single rooted tree; found roots {root_candidates!r}"
        )
    root_link = root_candidates[0]

    visited: set[str] = set()
    visiting: set[str] = set()

    def visit(link_name: str) -> None:
        if link_name in visited:
            return
        if link_name in visiting:
            raise UrdfSourceError(f"{_relative_to_repo(resolved_path)} joint graph contains a cycle")
        visiting.add(link_name)
        for child_link in joints_by_parent.get(link_name, ()):
            visit(child_link)
        visiting.remove(link_name)
        visited.add(link_name)

    visit(root_link)
    if visited != link_name_set:
        missing_links = sorted(link_name_set - visited)
        raise UrdfSourceError(
            f"{_relative_to_repo(resolved_path)} leaves links disconnected from the root: {missing_links!r}"
        )
    if len(joints) != len(link_names) - 1:
        raise UrdfSourceError(
            f"{_relative_to_repo(resolved_path)} must form a tree with exactly links-1 joints"
        )

    return UrdfSource(
        file_ref=file_ref_from_urdf_path(resolved_path),
        source_path=resolved_path,
        robot_name=robot_name,
        root_link=root_link,
        links=tuple(link_names),
        joints=tuple(joints),
        mesh_paths=tuple(visual_mesh_paths + collision_mesh_paths),
        visual_mesh_paths=tuple(visual_mesh_paths),
        collision_mesh_paths=tuple(collision_mesh_paths),
    )


def _validate_link_inertials(root: ET.Element, *, source_path: Path) -> None:
    for link_element in root.findall("link"):
        link_name = str(link_element.attrib.get("name") or "").strip()
        inertial_element = link_element.find("inertial")
        if inertial_element is None:
            continue
        _validate_origin(
            inertial_element.find("origin"),
            source_path=source_path,
            label=f"link {link_name!r} inertial origin",
        )
        mass_element = inertial_element.find("mass")
        if mass_element is None:
            raise UrdfSourceError(
                f"{_relative_to_repo(source_path)} link {link_name!r} inertial requires <mass>"
            )
        mass = _required_float_attr(
            mass_element,
            "value",
            source_path=source_path,
            label=f"link {link_name!r} inertial mass",
        )
        if mass <= 0.0:
            raise UrdfSourceError(
                f"{_relative_to_repo(source_path)} link {link_name!r} inertial mass must be positive"
            )

        inertia_element = inertial_element.find("inertia")
        if inertia_element is None:
            raise UrdfSourceError(
                f"{_relative_to_repo(source_path)} link {link_name!r} inertial requires <inertia>"
            )
        ixx = _required_float_attr(
            inertia_element,
            "ixx",
            source_path=source_path,
            label=f"link {link_name!r} inertia ixx",
        )
        ixy = _required_float_attr(
            inertia_element,
            "ixy",
            source_path=source_path,
            label=f"link {link_name!r} inertia ixy",
        )
        ixz = _required_float_attr(
            inertia_element,
            "ixz",
            source_path=source_path,
            label=f"link {link_name!r} inertia ixz",
        )
        iyy = _required_float_attr(
            inertia_element,
            "iyy",
            source_path=source_path,
            label=f"link {link_name!r} inertia iyy",
        )
        iyz = _required_float_attr(
            inertia_element,
            "iyz",
            source_path=source_path,
            label=f"link {link_name!r} inertia iyz",
        )
        izz = _required_float_attr(
            inertia_element,
            "izz",
            source_path=source_path,
            label=f"link {link_name!r} inertia izz",
        )
        _validate_inertia_values(
            link_name,
            ixx=ixx,
            ixy=ixy,
            ixz=ixz,
            iyy=iyy,
            iyz=iyz,
            izz=izz,
            source_path=source_path,
        )


def _required_float_attr(
    element: ET.Element,
    attr_name: str,
    *,
    source_path: Path,
    label: str,
) -> float:
    try:
        value = element.attrib[attr_name]
    except KeyError as exc:
        raise UrdfSourceError(
            f"{_relative_to_repo(source_path)} {label} requires {attr_name!r}"
        ) from exc
    try:
        parsed = float(value)
    except ValueError as exc:
        raise UrdfSourceError(f"{_relative_to_repo(source_path)} {label} is invalid") from exc
    if not isfinite(parsed):
        raise UrdfSourceError(f"{_relative_to_repo(source_path)} {label} must be finite")
    return parsed


def _validate_inertia_values(
    link_name: str,
    *,
    ixx: float,
    ixy: float,
    ixz: float,
    iyy: float,
    iyz: float,
    izz: float,
    source_path: Path,
) -> None:
    del ixy, ixz, iyz
    if ixx <= 0.0 or iyy <= 0.0 or izz <= 0.0:
        raise UrdfSourceError(
            f"{_relative_to_repo(source_path)} link {link_name!r} inertia diagonal values must be positive"
        )
    tolerance = 1e-12
    if ixx + iyy + tolerance < izz or ixx + izz + tolerance < iyy or iyy + izz + tolerance < ixx:
        raise UrdfSourceError(
            f"{_relative_to_repo(source_path)} link {link_name!r} inertia violates triangle inequalities"
        )


def _geometry_mesh_paths(
    link_element: ET.Element,
    *,
    element_name: str,
    source_path: Path,
    package_map: dict[str, Path] | None,
) -> list[Path]:
    mesh_paths: list[Path] = []
    link_name = str(link_element.attrib.get("name") or "").strip()
    for geometry_owner in link_element.findall(element_name):
        _validate_origin(
            geometry_owner.find("origin"),
            source_path=source_path,
            label=f"link {link_name!r} {element_name} origin",
        )
        geometry_element = geometry_owner.find("geometry")
        if geometry_element is None:
            raise UrdfSourceError(
                f"{_relative_to_repo(source_path)} link {link_name!r} {element_name} requires <geometry>"
            )
        geometry_child = _validate_geometry_element(
            geometry_element,
            source_path=source_path,
            label=f"link {link_name!r} {element_name} geometry",
        )
        if geometry_child.tag != "mesh":
            continue
        mesh_path = _validated_mesh_path(geometry_child, source_path=source_path, package_map=package_map)
        if mesh_path is not None:
            mesh_paths.append(mesh_path)
    return mesh_paths


def _validated_mesh_path(
    mesh_element: ET.Element,
    *,
    source_path: Path,
    package_map: dict[str, Path] | None,
) -> Path | None:
    filename = str(mesh_element.attrib.get("filename") or "").strip()
    if not filename:
        raise UrdfSourceError(f"{_relative_to_repo(source_path)} mesh filename is required")
    mesh_ref = classify_mesh_uri(filename)
    _validate_mesh_scale(mesh_element, source_path=source_path, filename=filename)
    mesh_path = resolve_mesh_uri(filename, package_map=package_map)
    if mesh_path is None:
        _warn_unresolved_mesh_uri(filename, mesh_ref=mesh_ref, source_path=source_path)
        return None
    if mesh_ref.kind == MeshUriKind.LOCAL_RELATIVE:
        mesh_path = (source_path.parent / mesh_path).resolve()
    if not mesh_path.is_file():
        raise UrdfSourceError(
            f"{_relative_to_repo(source_path)} references missing mesh file: {filename!r}"
        )
    return mesh_path


def _joint_limits_deg(
    joint_element: ET.Element,
    *,
    joint_type: str,
    source_path: Path,
) -> tuple[float | None, float | None]:
    if joint_type == "fixed":
        return 0.0, 0.0
    if joint_type == "continuous":
        return -180.0, 180.0
    limit_element = joint_element.find("limit")
    if limit_element is None:
        raise UrdfSourceError(
            f"{_relative_to_repo(source_path)} {joint_type} joint {joint_element.attrib.get('name', '')!r} requires <limit>"
        )
    try:
        lower = float(limit_element.attrib["lower"])
        upper = float(limit_element.attrib["upper"])
    except KeyError as exc:
        raise UrdfSourceError(
            f"{_relative_to_repo(source_path)} {joint_type} joint {joint_element.attrib.get('name', '')!r} requires lower and upper limits"
        ) from exc
    except ValueError as exc:
        raise UrdfSourceError(
            f"{_relative_to_repo(source_path)} {joint_type} joint {joint_element.attrib.get('name', '')!r} has invalid limits"
        ) from exc
    if not isfinite(lower) or not isfinite(upper):
        raise UrdfSourceError(
            f"{_relative_to_repo(source_path)} {joint_type} joint {joint_element.attrib.get('name', '')!r} limits must be finite"
        )
    if lower > upper:
        raise UrdfSourceError(
            f"{_relative_to_repo(source_path)} {joint_type} joint {joint_element.attrib.get('name', '')!r} lower limit exceeds upper limit"
        )
    _validate_optional_float_attr(
        limit_element,
        "effort",
        source_path=source_path,
        label=f"{joint_type} joint {joint_element.attrib.get('name', '')!r} effort limit",
    )
    _validate_optional_float_attr(
        limit_element,
        "velocity",
        source_path=source_path,
        label=f"{joint_type} joint {joint_element.attrib.get('name', '')!r} velocity limit",
    )
    if joint_type == "prismatic":
        return lower, upper
    return degrees(lower), degrees(upper)


def _validate_optional_float_attr(
    element: ET.Element,
    attr_name: str,
    *,
    source_path: Path,
    label: str,
) -> float | None:
    if attr_name not in element.attrib:
        return None
    return _required_float_attr(element, attr_name, source_path=source_path, label=label)


def _validate_origin(origin_element: ET.Element | None, *, source_path: Path, label: str) -> None:
    if origin_element is None:
        return
    if "xyz" in origin_element.attrib:
        _required_float_vector_attr(
            origin_element,
            "xyz",
            expected_count=3,
            source_path=source_path,
            label=f"{label} xyz",
        )
    if "rpy" in origin_element.attrib:
        _required_float_vector_attr(
            origin_element,
            "rpy",
            expected_count=3,
            source_path=source_path,
            label=f"{label} rpy",
        )


def _validate_joint_axis(joint_element: ET.Element, *, joint_type: str, source_path: Path) -> None:
    axis_element = joint_element.find("axis")
    if axis_element is None:
        return
    axis = _required_float_vector_attr(
        axis_element,
        "xyz",
        expected_count=3,
        source_path=source_path,
        label=f"joint {joint_element.attrib.get('name', '')!r} axis",
    )
    if joint_type != "fixed" and all(component == 0.0 for component in axis):
        raise UrdfSourceError(
            f"{_relative_to_repo(source_path)} joint {joint_element.attrib.get('name', '')!r} axis must be nonzero"
        )


def _validate_geometry_element(geometry_element: ET.Element, *, source_path: Path, label: str) -> ET.Element:
    geometry_children = list(geometry_element)
    if len(geometry_children) != 1:
        supported = ", ".join(sorted(SUPPORTED_GEOMETRY_TAGS))
        raise UrdfSourceError(
            f"{_relative_to_repo(source_path)} {label} must define exactly one geometry element: {supported}"
        )
    geometry_child = geometry_children[0]
    if geometry_child.tag not in SUPPORTED_GEOMETRY_TAGS:
        supported = ", ".join(sorted(SUPPORTED_GEOMETRY_TAGS))
        raise UrdfSourceError(
            f"{_relative_to_repo(source_path)} {label} must use one of: {supported}"
        )
    _validate_geometry_child(geometry_child, source_path=source_path, label=label)
    return geometry_child


def _validate_geometry_child(geometry_child: ET.Element, *, source_path: Path, label: str) -> None:
    if geometry_child.tag == "mesh":
        return
    if geometry_child.tag == "box":
        _required_positive_float_vector_attr(
            geometry_child,
            "size",
            expected_count=3,
            source_path=source_path,
            label=f"{label} box size",
        )
        return
    if geometry_child.tag == "cylinder":
        _required_positive_float_attr(
            geometry_child,
            "radius",
            source_path=source_path,
            label=f"{label} cylinder radius",
        )
        _required_positive_float_attr(
            geometry_child,
            "length",
            source_path=source_path,
            label=f"{label} cylinder length",
        )
        return
    if geometry_child.tag == "sphere":
        _required_positive_float_attr(
            geometry_child,
            "radius",
            source_path=source_path,
            label=f"{label} sphere radius",
        )


def _validate_mesh_scale(mesh_element: ET.Element, *, source_path: Path, filename: str) -> None:
    if "scale" not in mesh_element.attrib:
        return
    _required_positive_float_vector_attr(
        mesh_element,
        "scale",
        expected_count=3,
        source_path=source_path,
        label=f"mesh {filename!r} scale",
    )


def _required_positive_float_attr(
    element: ET.Element,
    attr_name: str,
    *,
    source_path: Path,
    label: str,
) -> float:
    value = _required_float_attr(element, attr_name, source_path=source_path, label=label)
    if value <= 0.0:
        raise UrdfSourceError(f"{_relative_to_repo(source_path)} {label} must be positive")
    return value


def _required_float_vector_attr(
    element: ET.Element,
    attr_name: str,
    *,
    expected_count: int,
    source_path: Path,
    label: str,
) -> tuple[float, ...]:
    try:
        raw_value = element.attrib[attr_name]
    except KeyError as exc:
        raise UrdfSourceError(
            f"{_relative_to_repo(source_path)} {label} requires {attr_name!r}"
        ) from exc
    raw_parts = raw_value.split()
    if len(raw_parts) != expected_count:
        raise UrdfSourceError(
            f"{_relative_to_repo(source_path)} {label} must have {expected_count} values"
        )
    try:
        values = tuple(float(part) for part in raw_parts)
    except ValueError as exc:
        raise UrdfSourceError(f"{_relative_to_repo(source_path)} {label} is invalid") from exc
    if not all(isfinite(value) for value in values):
        raise UrdfSourceError(f"{_relative_to_repo(source_path)} {label} values must be finite")
    return values


def _required_positive_float_vector_attr(
    element: ET.Element,
    attr_name: str,
    *,
    expected_count: int,
    source_path: Path,
    label: str,
) -> tuple[float, ...]:
    values = _required_float_vector_attr(
        element,
        attr_name,
        expected_count=expected_count,
        source_path=source_path,
        label=label,
    )
    if any(value <= 0.0 for value in values):
        raise UrdfSourceError(f"{_relative_to_repo(source_path)} {label} values must be positive")
    return values


def classify_mesh_uri(uri: str) -> MeshReference:
    value = str(uri or "").strip()
    parsed = urlparse(value)

    if parsed.scheme == "package":
        package_name = unquote(parsed.netloc).strip()
        package_path = PurePosixPath(unquote(parsed.path).lstrip("/"))
        if not package_name or package_path.as_posix() == "." or ".." in package_path.parts:
            raise UrdfSourceError(f"package mesh URI is invalid: {uri!r}")
        return MeshReference(
            uri=value,
            kind=MeshUriKind.PACKAGE,
            package_name=package_name,
            package_path=package_path,
        )

    if parsed.scheme == "file":
        file_path = Path(unquote(parsed.path))
        if file_path.is_absolute():
            return MeshReference(uri=value, kind=MeshUriKind.LOCAL_ABSOLUTE, path=file_path.resolve())
        return MeshReference(uri=value, kind=MeshUriKind.LOCAL_RELATIVE, path=file_path)

    if parsed.scheme:
        return MeshReference(uri=value, kind=MeshUriKind.REMOTE)

    local_path = Path(value)
    if local_path.is_absolute():
        return MeshReference(uri=value, kind=MeshUriKind.LOCAL_ABSOLUTE, path=local_path.resolve())
    return MeshReference(uri=value, kind=MeshUriKind.LOCAL_RELATIVE, path=local_path)


def resolve_mesh_uri(uri: str, package_map: dict[str, Path] | None = None) -> Path | None:
    mesh_ref = classify_mesh_uri(uri)
    if mesh_ref.kind in {MeshUriKind.LOCAL_RELATIVE, MeshUriKind.LOCAL_ABSOLUTE}:
        return mesh_ref.path
    if mesh_ref.kind == MeshUriKind.PACKAGE:
        package_root = (package_map or {}).get(str(mesh_ref.package_name))
        if package_root is None or mesh_ref.package_path is None:
            return None
        return (Path(package_root).expanduser() / Path(*mesh_ref.package_path.parts)).resolve()
    return None


def _warn_unresolved_mesh_uri(uri: str, *, mesh_ref: MeshReference, source_path: Path) -> None:
    if mesh_ref.kind == MeshUriKind.PACKAGE:
        message = f"WARN: {uri} syntax is valid but was not resolved."
    else:
        message = f"WARN: {uri} is not a local mesh URI and was not resolved."
    warnings.warn(f"{_relative_to_repo(source_path)} {message}", UrdfSourceWarning, stacklevel=3)


def _raise_on_duplicates(values: list[str], *, source_path: Path, label: str) -> None:
    seen: set[str] = set()
    duplicates: set[str] = set()
    for value in values:
        if value in seen:
            duplicates.add(value)
            continue
        seen.add(value)
    if duplicates:
        duplicate_text = ", ".join(repr(item) for item in sorted(duplicates))
        raise UrdfSourceError(
            f"{_relative_to_repo(source_path)} {label} names contain duplicates {duplicate_text}"
        )


def _relative_to_repo(path: Path) -> str:
    try:
        return path.resolve().relative_to(Path.cwd().resolve()).as_posix()
    except ValueError:
        return path.resolve().as_posix()
