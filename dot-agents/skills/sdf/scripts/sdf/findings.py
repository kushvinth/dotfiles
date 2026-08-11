from __future__ import annotations

from dataclasses import dataclass, field
from typing import Literal

Severity = Literal["error", "warning", "info"]


@dataclass(frozen=True)
class Finding:
    severity: Severity
    code: str
    message: str
    path: str | None = None
    hint: str | None = None

    def format(self) -> str:
        location = f" at {self.path}" if self.path else ""
        hint = f" Hint: {self.hint}" if self.hint else ""
        return f"{self.severity}: {self.code}{location}: {self.message}{hint}"


@dataclass
class ValidationResult:
    errors: list[Finding] = field(default_factory=list)
    warnings: list[Finding] = field(default_factory=list)
    infos: list[Finding] = field(default_factory=list)

    @property
    def ok(self) -> bool:
        return not self.errors

    def add(
        self,
        severity: Severity,
        code: str,
        message: str,
        *,
        path: str | None = None,
        hint: str | None = None,
    ) -> Finding:
        finding = Finding(severity=severity, code=code, message=message, path=path, hint=hint)
        if severity == "error":
            self.errors.append(finding)
        elif severity == "warning":
            self.warnings.append(finding)
        else:
            self.infos.append(finding)
        return finding

    def extend(self, other: ValidationResult) -> None:
        self.errors.extend(other.errors)
        self.warnings.extend(other.warnings)
        self.infos.extend(other.infos)

    def all_findings(self) -> list[Finding]:
        return [*self.errors, *self.warnings, *self.infos]


def format_findings(findings: list[Finding]) -> str:
    return "\n".join(finding.format() for finding in findings)
