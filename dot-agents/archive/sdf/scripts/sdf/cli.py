from __future__ import annotations

import argparse
import importlib.util
import inspect
import sys
from collections.abc import Sequence
from dataclasses import dataclass
from pathlib import Path
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
from sdf.external import run_gz_sdf_check
from sdf.findings import Finding, ValidationResult, format_findings
from sdf.source import SdfSourceError
from sdf.validation import validate_sdf_xml


@dataclass(frozen=True)
class _TargetSpec:
    source_path: Path
    output_path: Path


def generate_sdf_targets(
    targets: Sequence[str],
    *,
    output: str | Path | None = None,
    gz_check: str = "auto",
    strict: bool = False,
) -> int:
    target_specs = _resolve_target_specs(targets, output=output)
    _validate_unique_outputs(target_specs)
    for target_spec in target_specs:
        _generate_target(
            target_spec.source_path,
            output_path=target_spec.output_path,
            gz_check=gz_check,
            strict=strict,
        )
    return 0


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="sdf",
        description="Generate explicit SDFormat/SDF targets from Python sources.",
    )
    parser.add_argument(
        "targets",
        nargs="+",
        help="Explicit Python source file or SOURCE.py=OUTPUT.sdf pair defining gen_sdf() to generate.",
    )
    parser.add_argument(
        "-o",
        "--output",
        metavar="PATH",
        help="Write the generated SDF file to this path. Valid only with one plain Python target.",
    )
    parser.add_argument(
        "--gz-check",
        choices=("auto", "required", "never"),
        default="auto",
        help="Optionally run 'gz sdf --check' before writing output.",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Treat bundled validation warnings and generator envelope warnings as failures.",
    )
    args = parser.parse_args(list(argv) if argv is not None else None)
    if args.output is not None:
        if _targets_include_output_pairs(args.targets):
            parser.error("--output cannot be combined with SOURCE=OUTPUT targets")
        if len(args.targets) != 1:
            parser.error("--output can only be used with exactly one target")
    return generate_sdf_targets(args.targets, output=args.output, gz_check=args.gz_check, strict=args.strict)


def _resolve_target_specs(targets: Sequence[str], *, output: str | Path | None = None) -> list[_TargetSpec]:
    if output is not None and _targets_include_output_pairs(targets):
        raise ValueError("sdf --output cannot be combined with SOURCE=OUTPUT targets")
    if output is not None and len(targets) != 1:
        raise ValueError("sdf --output can only be used with exactly one target")

    specs: list[_TargetSpec] = []
    for raw_target in targets:
        target_text = str(raw_target or "").strip()
        if "=" in target_text:
            raw_source, raw_output = target_text.split("=", 1)
            source_path = _resolve_source_path(raw_source)
            output_path = _resolve_cli_output_path(raw_output)
        else:
            source_path = _resolve_source_path(target_text)
            output_path = _resolve_cli_output_path(output) if output is not None else source_path.with_suffix(".sdf")
        specs.append(_TargetSpec(source_path=source_path, output_path=output_path))
    return specs


def _resolve_source_path(raw_source: object) -> Path:
    value = str(raw_source or "").strip()
    if not value:
        raise ValueError("sdf target source must be a non-empty path")
    source_path = Path(value).expanduser()
    return source_path.resolve() if source_path.is_absolute() else (Path.cwd() / source_path).resolve()


def _resolve_cli_output_path(raw_output: object) -> Path:
    value = str(raw_output or "").strip()
    if not value:
        raise ValueError("sdf output must be a non-empty path")
    if "\\" in value:
        raise ValueError("sdf output must use POSIX '/' separators")
    output_path = Path(value).expanduser()
    resolved = output_path.resolve() if output_path.is_absolute() else (Path.cwd() / output_path).resolve()
    if resolved.suffix.lower() != ".sdf":
        raise ValueError("sdf output must end in .sdf")
    return resolved


def _targets_include_output_pairs(targets: Sequence[str]) -> bool:
    return any("=" in str(target or "") for target in targets)


def _validate_unique_outputs(target_specs: Sequence[_TargetSpec]) -> None:
    seen: dict[Path, Path] = {}
    for target_spec in target_specs:
        output_path = target_spec.output_path.resolve()
        previous = seen.get(output_path)
        if previous is not None:
            raise ValueError(f"sdf output path is used more than once: {_display_path(target_spec.output_path)}")
        seen[output_path] = target_spec.output_path


def _generate_target(script_path: Path, *, output_path: Path, gz_check: str, strict: bool) -> Path:
    script_path = script_path.resolve()
    if script_path.suffix.lower() != ".py":
        raise ValueError(f"{_display_path(script_path)} must be a Python source file")
    if not script_path.is_file():
        raise FileNotFoundError(f"Python source not found: {_display_path(script_path)}")

    with track_generation_run(
        source_path=script_path,
        generator="gen_sdf",
        outputs=[GenerationOutput(output_path, "sdf")],
    ):
        return _generate_target_inner(script_path, output_path=output_path, gz_check=gz_check, strict=strict)


def _generate_target_inner(script_path: Path, *, output_path: Path, gz_check: str, strict: bool) -> Path:

    module = _load_generator_module(script_path)
    generator = getattr(module, "gen_sdf", None)
    if not callable(generator):
        raise RuntimeError(f"{_display_path(script_path)} does not define callable gen_sdf()")
    if inspect.signature(generator).parameters:
        raise ValueError(f"{_display_path(script_path)} gen_sdf() must not accept arguments")

    payload = _normalize_sdf_payload(generator(), script_path=script_path)
    xml_text = _payload_xml(payload, script_path=script_path)

    validation = validate_sdf_xml(
        xml_text,
        source_path=output_path,
        base_dir=output_path.parent,
        metadata=payload.get("metadata") if isinstance(payload.get("metadata"), dict) else None,
    )
    validation.warnings.extend(_payload_warning_findings(payload, script_path=script_path))
    _raise_for_failed_generation(validation, strict=strict)

    external = run_gz_sdf_check(xml_text, output_path=output_path, mode=gz_check)
    validation.extend(external)
    _raise_for_failed_generation(validation, strict=strict)

    _write_sdf_payload(payload, output_path=output_path, script_path=script_path)
    _print_generation_report(payload, validation)
    if not output_path.exists():
        raise RuntimeError(f"{_display_path(script_path)} did not write {_display_path(output_path)}")
    return output_path


def _load_generator_module(script_path: Path) -> object:
    module_name = (
        "_sdf_tool_"
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


def _normalize_sdf_payload(raw_payload: object, *, script_path: Path) -> dict[str, object]:
    if _is_xml_element(raw_payload):
        return {"xml": _serialize_xml_element(raw_payload)}
    if isinstance(raw_payload, str):
        return {"xml": raw_payload}
    if not isinstance(raw_payload, dict):
        raise TypeError(
            f"{_display_path(script_path)} gen_sdf() must return an SDF XML root element, XML string, "
            "or generator envelope dict"
        )
    allowed_fields = {"xml", "metadata", "assumptions", "warnings"}
    extra_fields = sorted(str(key) for key in raw_payload if key not in allowed_fields)
    if extra_fields:
        joined = ", ".join(extra_fields)
        raise TypeError(f"{_display_path(script_path)} gen_sdf() envelope has unsupported field(s): {joined}")
    if "xml" not in raw_payload:
        raise TypeError(f"{_display_path(script_path)} gen_sdf() envelope must define 'xml'")
    payload = dict(raw_payload)
    payload["xml"] = _normalize_xml_value(payload["xml"], script_path=script_path, label="gen_sdf() envelope field 'xml'")
    payload["metadata"] = _normalize_metadata(payload.get("metadata"), script_path=script_path)
    payload["assumptions"] = _normalize_report_items(payload.get("assumptions"), field="assumptions", script_path=script_path)
    payload["warnings"] = _normalize_report_items(payload.get("warnings"), field="warnings", script_path=script_path)
    return payload


def _write_sdf_payload(payload: dict[str, object], *, output_path: Path, script_path: Path) -> None:
    xml = _payload_xml(payload, script_path=script_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    xml = xml_with_text_to_cad_metadata(
        xml,
        python_source_identity(script_path),
        output_path=output_path,
        source_path=script_path,
    )
    text = xml if xml.endswith("\n") else xml + "\n"
    output_path.write_text(text, encoding="utf-8")
    print(f"Wrote SDF: {output_path}")


def _payload_xml(payload: dict[str, object], *, script_path: Path) -> str:
    xml = payload.get("xml")
    if not isinstance(xml, str):
        raise TypeError(
            f"{_display_path(script_path)} gen_sdf() envelope field 'xml' must be a string, "
            f"got {type(xml).__name__}"
        )
    return xml


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


def _normalize_metadata(raw_metadata: object, *, script_path: Path) -> dict[str, object]:
    if raw_metadata is None:
        return {}
    if not isinstance(raw_metadata, dict):
        raise TypeError(f"{_display_path(script_path)} gen_sdf() envelope field 'metadata' must be a dict")
    metadata: dict[str, object] = {}
    for key, value in raw_metadata.items():
        if not isinstance(value, (str, int, float, bool, type(None))):
            raise TypeError(
                f"{_display_path(script_path)} gen_sdf() metadata value for {key!r} must be a scalar"
            )
        metadata[str(key)] = value
    return metadata


def _normalize_report_items(raw_items: object, *, field: str, script_path: Path) -> list[dict[str, str]]:
    if raw_items is None:
        return []
    if isinstance(raw_items, (str, bytes)) or not isinstance(raw_items, Sequence):
        raise TypeError(f"{_display_path(script_path)} gen_sdf() envelope field '{field}' must be a list")
    normalized: list[dict[str, str]] = []
    default_code = "generator_assumption" if field == "assumptions" else "generator_warning"
    for item in raw_items:
        if isinstance(item, str):
            message = item.strip()
            code = default_code
            source = ""
        elif isinstance(item, dict):
            message = str(item.get("message") or "").strip()
            code = str(item.get("code") or default_code).strip()
            source = str(item.get("source") or "").strip()
        else:
            raise TypeError(
                f"{_display_path(script_path)} gen_sdf() envelope field '{field}' entries must be strings or dicts"
            )
        if not message:
            raise TypeError(f"{_display_path(script_path)} gen_sdf() envelope field '{field}' has an empty message")
        normalized.append({"code": code, "message": message, "source": source})
    return normalized


def _payload_warning_findings(payload: dict[str, object], *, script_path: Path) -> list[Finding]:
    warnings = payload.get("warnings")
    if not isinstance(warnings, list):
        return []
    findings: list[Finding] = []
    for item in warnings:
        if not isinstance(item, dict):
            continue
        source = item.get("source")
        findings.append(
            Finding(
                severity="warning",
                code=str(item.get("code") or "generator_warning"),
                message=str(item.get("message") or ""),
                path=_display_path(script_path),
                hint=f"Source: {source}" if source else None,
            )
        )
    return findings


def _raise_for_failed_generation(validation: ValidationResult, *, strict: bool) -> None:
    findings = validation.errors + (validation.warnings if strict else [])
    if findings:
        raise SdfSourceError(format_findings(findings))


def _print_generation_report(payload: dict[str, object], validation: ValidationResult) -> None:
    assumptions = payload.get("assumptions")
    if isinstance(assumptions, list):
        for item in assumptions:
            if not isinstance(item, dict):
                continue
            source = f" Source: {item['source']}." if item.get("source") else ""
            message = str(item["message"])
            ending = "" if message.endswith(".") else "."
            print(f"Assumption [{item['code']}]: {message}{ending}{source}")
    for finding in [*validation.warnings, *validation.infos]:
        print(finding.format())


def _display_path(path: Path) -> str:
    resolved = path.resolve()
    try:
        return resolved.relative_to(Path.cwd().resolve()).as_posix()
    except ValueError:
        return resolved.as_posix()


if __name__ == "__main__":
    raise SystemExit(main())
