"""Dependency-free metadata helpers for generated CAD-adjacent outputs."""

from cadpy_metadata.generator import (
    GenerationOutput,
    PythonSourceIdentity,
    python_source_identity,
    track_generation_run,
    xml_with_text_to_cad_metadata,
)

__all__ = [
    "GenerationOutput",
    "PythonSourceIdentity",
    "python_source_identity",
    "track_generation_run",
    "xml_with_text_to_cad_metadata",
]
