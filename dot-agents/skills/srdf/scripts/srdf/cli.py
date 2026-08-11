from __future__ import annotations

import argparse
import importlib.util
import inspect
from math import isfinite
import os
import sys
import warnings
from collections.abc import Sequence
from dataclasses import dataclass
from pathlib import Path, PurePosixPath
import xml.etree.ElementTree as ET

SCRIPTS_DIR = Path(__file__).resolve().parents[1]
if __package__ in {None, ""}:
    sys.path.insert(0, str(SCRIPTS_DIR))

PACKAGES_DIR = SCRIPTS_DIR / "packages"
CADPY_METADATA_SRC_DIR = PACKAGES_DIR / "cadpy_metadata" / "src"
if str(PACKAGES_DIR) not in sys.path:
    sys.path.insert(0, str(PACKAGES_DIR))
if str(CADPY_METADATA_SRC_DIR) not in sys.path:
    sys.path.insert(0, str(CADPY_METADATA_SRC_DIR))

from cadpy_metadata import (
    GenerationOutput,
    python_source_identity,
    track_generation_run,
    xml_with_text_to_cad_metadata,
)
from srdf.source import LEGACY_EXPLORER_NAMESPACE, SRDF_METADATA_NAMESPACE, SrdfSource, SrdfSourceError, parse_srdf_xml


@dataclass(frozen=True)
class _TargetSpec:
    source_path: Path
    output_path: Path


def generate_srdf_targets(targets: Sequence[str], *, output: str | Path | None = None) -> int:
    target_specs = _resolve_target_specs(targets, output=output)
    _validate_unique_outputs(target_specs)
    for target_spec in target_specs:
        _generate_target(target_spec.source_path, output_path=target_spec.output_path)
    return 0


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="srdf",
        description="Generate explicit MoveIt2 SRDF targets from Python sources.",
    )
    parser.add_argument(
        "targets",
        nargs="+",
        help="Explicit Python source file or SOURCE.py=OUTPUT.srdf pair defining gen_srdf() to generate.",
    )
    parser.add_argument(
        "-o",
        "--output",
        metavar="PATH",
        help="Write the generated SRDF file to this path. Valid only with one plain Python target.",
    )
    args = parser.parse_args(list(argv) if argv is not None else None)
    if args.output is not None:
        if _targets_include_output_pairs(args.targets):
            parser.error("--output cannot be combined with SOURCE=OUTPUT targets")
        if len(args.targets) != 1:
            parser.error("--output can only be used with exactly one target")
    return generate_srdf_targets(args.targets, output=args.output)


def _resolve_target_specs(targets: Sequence[str], *, output: str | Path | None = None) -> list[_TargetSpec]:
    if output is not None and _targets_include_output_pairs(targets):
        raise ValueError("srdf --output cannot be combined with SOURCE=OUTPUT targets")
    if output is not None and len(targets) != 1:
        raise ValueError("srdf --output can only be used with exactly one target")

    specs: list[_TargetSpec] = []
    for raw_target in targets:
        target_text = str(raw_target or "").strip()
        if "=" in target_text:
            raw_source, raw_output = target_text.split("=", 1)
            source_path = _resolve_source_path(raw_source)
            output_path = _resolve_cli_output_path(raw_output)
        else:
            source_path = _resolve_source_path(target_text)
            output_path = _resolve_cli_output_path(output) if output is not None else source_path.with_suffix(".srdf")
        specs.append(_TargetSpec(source_path=source_path, output_path=output_path))
    return specs


def _resolve_source_path(raw_source: object) -> Path:
    value = str(raw_source or "").strip()
    if not value:
        raise ValueError("srdf target source must be a non-empty path")
    source_path = Path(value).expanduser()
    return source_path.resolve() if source_path.is_absolute() else (Path.cwd() / source_path).resolve()


def _resolve_cli_output_path(raw_output: object) -> Path:
    value = str(raw_output or "").strip()
    if not value:
        raise ValueError("srdf output must be a non-empty path")
    if "\\" in value:
        raise ValueError("srdf output must use POSIX '/' separators")
    output_path = Path(value).expanduser()
    resolved = output_path.resolve() if output_path.is_absolute() else (Path.cwd() / output_path).resolve()
    if resolved.suffix.lower() != ".srdf":
        raise ValueError("srdf output must end in .srdf")
    return resolved


def _targets_include_output_pairs(targets: Sequence[str]) -> bool:
    return any("=" in str(target or "") for target in targets)


def _validate_unique_outputs(target_specs: Sequence[_TargetSpec]) -> None:
    seen: dict[Path, Path] = {}
    for target_spec in target_specs:
        output_path = target_spec.output_path.resolve()
        previous = seen.get(output_path)
        if previous is not None:
            raise ValueError(f"srdf output path is used more than once: {_display_path(target_spec.output_path)}")
        seen[output_path] = target_spec.output_path


def _generate_target(script_path: Path, *, output_path: Path) -> Path:
    script_path = script_path.resolve()
    if script_path.suffix.lower() != ".py":
        raise ValueError(f"{_display_path(script_path)} must be a Python source file")
    if not script_path.is_file():
        raise FileNotFoundError(f"Python source not found: {_display_path(script_path)}")

    with track_generation_run(
        source_path=script_path,
        generator="gen_srdf",
        outputs=[GenerationOutput(output_path, "srdf")],
    ):
        return _generate_target_inner(script_path, output_path=output_path)


def _generate_target_inner(script_path: Path, *, output_path: Path) -> Path:

    module = _load_generator_module(script_path)
    generator = getattr(module, "gen_srdf", None)
    if not callable(generator):
        raise RuntimeError(f"{_display_path(script_path)} does not define callable gen_srdf()")
    if inspect.signature(generator).parameters:
        raise ValueError(f"{_display_path(script_path)} gen_srdf() must not accept arguments")

    payload = _normalize_srdf_payload(generator(), script_path=script_path)
    xml = str(payload["xml"])
    urdf_path = _resolve_relative_file(payload["urdf"], source_path=script_path, suffix=".urdf", label="urdf")
    urdf_robot = _read_urdf_robot(urdf_path)
    xml = _xml_with_linked_urdf_metadata(xml, output_path=output_path, urdf_path=urdf_path)
    srdf_source = parse_srdf_xml(xml, source_path=output_path)
    _validate_linked_urdf_ref(
        srdf_source,
        expected_urdf_ref=_relative_posix_path(urdf_path, output_path.parent),
    )
    _validate_srdf_against_urdf(srdf_source, urdf_robot=urdf_robot)
    _write_srdf_payload(xml, output_path=output_path, script_path=script_path)
    if not output_path.exists():
        raise RuntimeError(f"{_display_path(script_path)} did not write {_display_path(output_path)}")
    return output_path


def _load_generator_module(script_path: Path) -> object:
    module_name = (
        "_srdf_tool_"
        + _display_path(script_path).replace("/", "_").replace("\\", "_").replace("-", "_").replace(".", "_")
    )
    module_spec = importlib.util.spec_from_file_location(module_name, script_path)
    if module_spec is None or module_spec.loader is None:
        raise RuntimeError(f"Failed to load generator module from {_display_path(script_path)}")

    module = importlib.util.module_from_spec(module_spec)
    original_sys_path = list(sys.path)
    search_paths = [
        str(Path.cwd().resolve()),
        str(script_path.parent),
    ]
    for candidate in reversed(search_paths):
        if candidate not in sys.path:
            sys.path.insert(0, candidate)

    try:
        sys.modules[module_name] = module
        module_spec.loader.exec_module(module)
    finally:
        sys.path[:] = original_sys_path

    return module


def _normalize_srdf_payload(raw_payload: object, *, script_path: Path) -> dict[str, object]:
    if not isinstance(raw_payload, dict):
        raise TypeError(f"{_display_path(script_path)} gen_srdf() must return an envelope dict")
    allowed_fields = {"xml", "urdf"}
    extra_fields = sorted(str(key) for key in raw_payload if key not in allowed_fields)
    if extra_fields:
        joined = ", ".join(extra_fields)
        raise TypeError(f"{_display_path(script_path)} gen_srdf() envelope has unsupported field(s): {joined}")
    if "xml" not in raw_payload:
        raise TypeError(f"{_display_path(script_path)} gen_srdf() envelope must define 'xml'")
    if "urdf" not in raw_payload:
        raise TypeError(f"{_display_path(script_path)} gen_srdf() envelope must define 'urdf'")
    xml = _normalize_xml_value(raw_payload.get("xml"), script_path=script_path, label="gen_srdf() envelope field 'xml'")
    if not xml.strip():
        raise TypeError(f"{_display_path(script_path)} gen_srdf() envelope field 'xml' must be non-empty")
    if not isinstance(raw_payload.get("urdf"), str) or not str(raw_payload.get("urdf")).strip():
        raise TypeError(f"{_display_path(script_path)} gen_srdf() envelope field 'urdf' must be a non-empty string")
    return {
        "xml": xml,
        "urdf": str(raw_payload["urdf"]).strip(),
    }


def _normalize_xml_value(raw_xml: object, *, script_path: Path, label: str) -> str:
    if _is_xml_element(raw_xml):
        return _serialize_xml_element(raw_xml)
    if isinstance(raw_xml, str):
        return raw_xml
    raise TypeError(
        f"{_display_path(script_path)} {label} must be an xml.etree.ElementTree.Element or string, "
        f"got {type(raw_xml).__name__}"
    )


def _is_xml_element(value: object) -> bool:
    return isinstance(value, ET.Element)


def _serialize_xml_element(root: ET.Element) -> str:
    ET.indent(root, space="  ")
    body = ET.tostring(root, encoding="unicode", short_empty_elements=True)
    return f'<?xml version="1.0"?>\n{body}'


def _resolve_relative_file(raw_value: object, *, source_path: Path, suffix: str, label: str) -> Path:
    if not isinstance(raw_value, str) or not raw_value.strip():
        raise ValueError(f"{label} must be a non-empty relative path")
    value = raw_value.strip()
    if "\\" in value:
        raise ValueError(f"{label} must use POSIX '/' separators")
    pure = PurePosixPath(value)
    if pure.is_absolute() or any(part in {"", "."} for part in pure.parts):
        raise ValueError(f"{label} must be a relative path")
    path = (source_path.parent / Path(*pure.parts)).resolve()
    if path.suffix.lower() != suffix:
        raise ValueError(f"{label} must end in {suffix}")
    if not path.is_file():
        raise FileNotFoundError(f"{label} file does not exist: {_display_path(path)}")
    return path


def _read_urdf_robot(urdf_path: Path) -> dict[str, object]:
    try:
        root = ET.parse(urdf_path).getroot()
    except ET.ParseError as exc:
        raise ValueError(f"URDF is invalid XML: {_display_path(urdf_path)}") from exc
    if root.tag != "robot":
        raise ValueError("URDF root must be <robot>")
    robot_name = str(root.get("name") or "").strip()
    links = {
        str(link.get("name") or "").strip()
        for link in root.findall("link")
        if str(link.get("name") or "").strip()
    }
    joints: dict[str, dict[str, object]] = {}
    for joint in root.findall("joint"):
        name = str(joint.get("name") or "").strip()
        if not name:
            continue
        parent_element = joint.find("parent")
        child_element = joint.find("child")
        joint_type = str(joint.get("type") or "").strip()
        lower: float | None = None
        upper: float | None = None
        limit_element = joint.find("limit")
        if limit_element is not None and joint_type in {"revolute", "prismatic"}:
            lower = _optional_finite_float(limit_element.get("lower"))
            upper = _optional_finite_float(limit_element.get("upper"))
        joints[name] = {
            "type": joint_type,
            "parent": str(parent_element.get("link") if parent_element is not None else "").strip(),
            "child": str(child_element.get("link") if child_element is not None else "").strip(),
            "lower": lower,
            "upper": upper,
            "mimic": joint.find("mimic") is not None,
        }
    if not robot_name:
        raise ValueError("URDF robot name is required")
    return {"name": robot_name, "links": links, "joints": joints}


def _validate_srdf_against_urdf(srdf_source: SrdfSource, *, urdf_robot: dict[str, object]) -> None:
    urdf_name = str(urdf_robot["name"])
    if srdf_source.robot_name != urdf_name:
        raise SrdfSourceError(f"SRDF robot name {srdf_source.robot_name!r} must match URDF robot name {urdf_name!r}")
    links = urdf_robot["links"]
    joints = urdf_robot["joints"]
    assert isinstance(links, set)
    assert isinstance(joints, dict)
    group_names = {group.name for group in srdf_source.planning_groups}
    groups_by_name = {group.name: group for group in srdf_source.planning_groups}
    if not group_names:
        raise SrdfSourceError("SRDF must define at least one planning group")

    for group in srdf_source.planning_groups:
        if not group.joint_names and not group.link_names and not group.chains and not group.subgroups:
            raise SrdfSourceError(f"SRDF planning group {group.name!r} must define joints, links, chains, or subgroups")
        _validate_names_exist(group.joint_names, set(joints), label=f"planning group {group.name!r} joint")
        _validate_names_exist(group.link_names, links, label=f"planning group {group.name!r} link")
        _validate_names_exist(group.subgroups, group_names, label=f"planning group {group.name!r} subgroup")
        for chain in group.chains:
            if chain.base_link not in links:
                raise SrdfSourceError(f"planning group {group.name!r} chain references missing base_link {chain.base_link!r}")
            if chain.tip_link not in links:
                raise SrdfSourceError(f"planning group {group.name!r} chain references missing tip_link {chain.tip_link!r}")

    for end_effector in srdf_source.end_effectors:
        if end_effector.parent_link not in links:
            raise SrdfSourceError(f"end_effector {end_effector.name!r} references missing parent_link {end_effector.parent_link!r}")
        if end_effector.group not in group_names:
            raise SrdfSourceError(f"end_effector {end_effector.name!r} references missing group {end_effector.group!r}")
        if end_effector.parent_group and end_effector.parent_group not in group_names:
            raise SrdfSourceError(
                f"end_effector {end_effector.name!r} references missing parent_group {end_effector.parent_group!r}"
            )
        _validate_end_effector_topology(
            end_effector,
            groups_by_name=groups_by_name,
            urdf_robot=urdf_robot,
        )

    for group_state in srdf_source.group_states:
        if group_state.group not in group_names:
            raise SrdfSourceError(f"group_state {group_state.name!r} references missing group {group_state.group!r}")
        group_joint_names = set(_joint_names_for_group(groups_by_name[group_state.group], urdf_robot=urdf_robot, groups_by_name=groups_by_name))
        for joint_name, value in group_state.joint_values_by_name.items():
            if joint_name not in joints:
                raise SrdfSourceError(f"group_state {group_state.name!r} joint references missing name {joint_name!r}")
            if joint_name not in group_joint_names:
                raise SrdfSourceError(
                    f"group_state {group_state.name!r} joint {joint_name!r} is not in group {group_state.group!r}"
                )
            _validate_group_state_joint_value(group_state.name, joint_name, value, joints[joint_name])

    for pair in srdf_source.disabled_collision_pairs:
        _validate_names_exist((pair.link1, pair.link2), links, label="disable_collisions link")
    _warn_on_many_manual_disabled_pairs(srdf_source.disabled_collision_pairs)


def _optional_finite_float(value: object) -> float | None:
    if value is None:
        return None
    try:
        parsed = float(value)
    except (TypeError, ValueError):
        return None
    return parsed if isfinite(parsed) else None


def _joint_path_for_chain(urdf_robot: dict[str, object], *, base_link: str, tip_link: str) -> list[str]:
    if not base_link or not tip_link or base_link == tip_link:
        return []
    joints = urdf_robot.get("joints")
    if not isinstance(joints, dict):
        return []
    by_parent: dict[str, list[tuple[str, dict[str, object]]]] = {}
    for joint_name, joint in joints.items():
        if not isinstance(joint, dict):
            continue
        parent = str(joint.get("parent") or "").strip()
        child = str(joint.get("child") or "").strip()
        if parent and child:
            by_parent.setdefault(parent, []).append((str(joint_name), joint))

    stack: list[tuple[str, list[str]]] = [(base_link, [])]
    visited: set[str] = set()
    while stack:
        link_name, path = stack.pop()
        if link_name == tip_link:
            return path
        if link_name in visited:
            continue
        visited.add(link_name)
        for joint_name, joint in reversed(by_parent.get(link_name, [])):
            child = str(joint.get("child") or "").strip()
            if child:
                stack.append((child, [*path, joint_name]))
    return []


def _joint_names_for_group(
    group: object,
    *,
    urdf_robot: dict[str, object],
    groups_by_name: dict[str, object],
    visited: set[str] | None = None,
) -> list[str]:
    names: list[str] = []
    joints = urdf_robot.get("joints")
    if not isinstance(joints, dict):
        return names

    for joint_name in getattr(group, "joint_names", ()):
        joint = joints.get(joint_name)
        if isinstance(joint, dict) and str(joint.get("type") or "") != "fixed" and not bool(joint.get("mimic")):
            _append_unique(names, [joint_name])

    for chain in getattr(group, "chains", ()):
        chain_joint_names = []
        for joint_name in _joint_path_for_chain(
            urdf_robot,
            base_link=str(getattr(chain, "base_link", "") or ""),
            tip_link=str(getattr(chain, "tip_link", "") or ""),
        ):
            joint = joints.get(joint_name)
            if isinstance(joint, dict) and str(joint.get("type") or "") != "fixed" and not bool(joint.get("mimic")):
                chain_joint_names.append(joint_name)
        _append_unique(names, chain_joint_names)

    if visited is None:
        visited = set()
    group_name = str(getattr(group, "name", "") or "")
    if group_name:
        visited.add(group_name)
    for subgroup_name in getattr(group, "subgroups", ()):
        subgroup_key = str(subgroup_name or "").strip()
        if not subgroup_key or subgroup_key in visited:
            continue
        subgroup = groups_by_name.get(subgroup_key)
        if subgroup is not None:
            _append_unique(
                names,
                _joint_names_for_group(
                    subgroup,
                    urdf_robot=urdf_robot,
                    groups_by_name=groups_by_name,
                    visited=visited,
                ),
            )
    return names


def _link_names_for_group(
    group: object,
    *,
    urdf_robot: dict[str, object],
    groups_by_name: dict[str, object],
    visited: set[str] | None = None,
) -> set[str]:
    links = set(str(link_name) for link_name in getattr(group, "link_names", ()))
    joints = urdf_robot.get("joints")
    if not isinstance(joints, dict):
        return links

    def add_joint_links(joint_name: str) -> None:
        joint = joints.get(joint_name)
        if not isinstance(joint, dict):
            return
        child = str(joint.get("child") or "").strip()
        if child:
            links.add(child)

    for joint_name in getattr(group, "joint_names", ()):
        add_joint_links(str(joint_name))
    for chain in getattr(group, "chains", ()):
        links.add(str(getattr(chain, "tip_link", "") or ""))
        for joint_name in _joint_path_for_chain(
            urdf_robot,
            base_link=str(getattr(chain, "base_link", "") or ""),
            tip_link=str(getattr(chain, "tip_link", "") or ""),
        ):
            add_joint_links(joint_name)

    if visited is None:
        visited = set()
    group_name = str(getattr(group, "name", "") or "")
    if group_name:
        visited.add(group_name)
    for subgroup_name in getattr(group, "subgroups", ()):
        subgroup_key = str(subgroup_name or "").strip()
        if not subgroup_key or subgroup_key in visited:
            continue
        subgroup = groups_by_name.get(subgroup_key)
        if subgroup is not None:
            links.update(
                _link_names_for_group(
                    subgroup,
                    urdf_robot=urdf_robot,
                    groups_by_name=groups_by_name,
                    visited=visited,
                )
            )
    links.discard("")
    return links


def _joint_adjacent_to_any_link(urdf_robot: dict[str, object], parent_link: str, child_links: set[str]) -> bool:
    joints = urdf_robot.get("joints")
    if not isinstance(joints, dict):
        return False
    for joint in joints.values():
        if not isinstance(joint, dict):
            continue
        parent = str(joint.get("parent") or "").strip()
        child = str(joint.get("child") or "").strip()
        if (parent == parent_link and child in child_links) or (child == parent_link and parent in child_links):
            return True
    return False


def _validate_end_effector_topology(
    end_effector: object,
    *,
    groups_by_name: dict[str, object],
    urdf_robot: dict[str, object],
) -> None:
    group_name = str(getattr(end_effector, "group", "") or "")
    parent_group_name = str(getattr(end_effector, "parent_group", "") or "")
    parent_link = str(getattr(end_effector, "parent_link", "") or "")
    if not group_name or group_name not in groups_by_name:
        return

    end_effector_links = _link_names_for_group(
        groups_by_name[group_name],
        urdf_robot=urdf_robot,
        groups_by_name=groups_by_name,
    )
    if parent_group_name and parent_group_name in groups_by_name:
        parent_group_links = _link_names_for_group(
            groups_by_name[parent_group_name],
            urdf_robot=urdf_robot,
            groups_by_name=groups_by_name,
        )
        overlap = sorted(end_effector_links & parent_group_links)
        if overlap:
            raise SrdfSourceError(
                f"end_effector {getattr(end_effector, 'name', '')!r} group shares link(s) with parent_group: {overlap!r}"
            )
        if parent_link and parent_link not in parent_group_links:
            raise SrdfSourceError(
                f"end_effector {getattr(end_effector, 'name', '')!r} parent_link {parent_link!r} is not in parent_group {parent_group_name!r}"
            )
    if end_effector_links and parent_link not in end_effector_links and not _joint_adjacent_to_any_link(
        urdf_robot,
        parent_link,
        end_effector_links,
    ):
        raise SrdfSourceError(
            f"end_effector {getattr(end_effector, 'name', '')!r} parent_link {parent_link!r} is not adjacent to its group"
        )


def _validate_group_state_joint_value(
    state_name: str,
    joint_name: str,
    value: float,
    joint: object,
) -> None:
    if not isinstance(joint, dict):
        return
    joint_type = str(joint.get("type") or "").strip()
    if joint_type == "fixed":
        raise SrdfSourceError(f"group_state {state_name!r} cannot set fixed joint {joint_name!r}")
    if bool(joint.get("mimic")):
        raise SrdfSourceError(f"group_state {state_name!r} cannot set mimic joint {joint_name!r}")
    if joint_type == "continuous":
        return
    lower = joint.get("lower")
    upper = joint.get("upper")
    if isinstance(lower, float) and value < lower:
        raise SrdfSourceError(f"group_state {state_name!r} joint {joint_name!r} is below its URDF lower limit")
    if isinstance(upper, float) and value > upper:
        raise SrdfSourceError(f"group_state {state_name!r} joint {joint_name!r} is above its URDF upper limit")


def _append_unique(target: list[str], values: list[str]) -> None:
    seen = set(target)
    for value in values:
        if value not in seen:
            target.append(value)
            seen.add(value)


def _warn_on_many_manual_disabled_pairs(pairs: object) -> None:
    manual_count = sum(1 for pair in pairs if getattr(pair, "source", "") == "manual")
    if manual_count >= 25:
        warnings.warn(
            f"SRDF contains {manual_count} manually reasoned disabled collision pairs; prefer sampled/setup-assistant provenance.",
            stacklevel=3,
        )


def _validate_linked_urdf_ref(srdf_source: SrdfSource, *, expected_urdf_ref: str) -> None:
    urdf_ref = str(srdf_source.urdf_ref or "").strip()
    if not urdf_ref:
        raise SrdfSourceError("SRDF must include <tcad:urdf path=\"...\"/> metadata")
    if PurePosixPath(urdf_ref) != PurePosixPath(expected_urdf_ref):
        raise SrdfSourceError(
            f"SRDF tcad:urdf path {urdf_ref!r} must match gen_srdf() envelope urdf {expected_urdf_ref!r}"
        )


def _relative_posix_path(target_path: Path, start_dir: Path) -> str:
    return Path(os.path.relpath(Path(target_path).resolve(), Path(start_dir).resolve())).as_posix()


def _xml_with_linked_urdf_metadata(xml: str, *, output_path: Path, urdf_path: Path) -> str:
    try:
        root = ET.fromstring(xml)
    except ET.ParseError as exc:
        raise SrdfSourceError(f"{_display_path(output_path)} could not be parsed as SRDF XML") from exc
    if root.tag != "robot":
        raise SrdfSourceError(f"{_display_path(output_path)} root element must be <robot>")
    ET.register_namespace("tcad", SRDF_METADATA_NAMESPACE)
    ET.register_namespace("explorer", LEGACY_EXPLORER_NAMESPACE)
    metadata_tag = f"{{{SRDF_METADATA_NAMESPACE}}}urdf"
    legacy_metadata_tag = f"{{{LEGACY_EXPLORER_NAMESPACE}}}urdf"
    metadata_element = None
    for child in list(root):
        if child.tag in {metadata_tag, legacy_metadata_tag} or str(child.tag or "") in {"tcad:urdf", "explorer:urdf"}:
            metadata_element = child
            break
    if metadata_element is None:
        metadata_element = ET.Element(metadata_tag)
        root.insert(0, metadata_element)
    else:
        metadata_element.tag = metadata_tag
    metadata_element.set("path", _relative_posix_path(urdf_path, output_path.parent))
    if root.text is None:
        root.text = "\n  "
    if metadata_element.tail is None:
        metadata_element.tail = "\n  "
    return _serialize_xml_element(root)


def _validate_names_exist(names: object, allowed: set[str], *, label: str) -> None:
    for name in names:
        if name not in allowed:
            raise SrdfSourceError(f"{label} references missing name {name!r}")


def _write_srdf_payload(xml: str, *, output_path: Path, script_path: Path) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    xml = xml_with_text_to_cad_metadata(
        xml,
        python_source_identity(script_path),
        output_path=output_path,
        source_path=script_path,
    )
    text = xml if xml.endswith("\n") else xml + "\n"
    output_path.write_text(text, encoding="utf-8")
    print(f"Wrote SRDF: {output_path}")


def _display_path(path: Path) -> str:
    resolved = path.resolve()
    try:
        return resolved.relative_to(Path.cwd().resolve()).as_posix()
    except ValueError:
        return resolved.as_posix()


if __name__ == "__main__":
    raise SystemExit(main())
