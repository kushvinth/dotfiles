from __future__ import annotations

import argparse
from collections.abc import Sequence


def generate_dxf_targets(*args, **kwargs):
    from cadpy.generation import generate_dxf_targets as generate

    return generate(*args, **kwargs)


def _targets_include_output_pairs(targets: Sequence[str]) -> bool:
    return any("=" in str(target or "") for target in targets)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="dxf",
        description="Generate explicit DXF targets from Python sources.",
    )
    parser.add_argument(
        "targets",
        nargs="+",
        help="Explicit Python source file or SOURCE.py=OUTPUT.dxf pair defining gen_dxf() to generate.",
    )
    parser.add_argument(
        "-o",
        "--output",
        metavar="PATH",
        help="Write the generated DXF file to this path. Valid only with one plain generated Python target.",
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Show detailed progress and timing information.",
    )
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(list(argv) if argv is not None else None)
    if args.output is not None:
        if _targets_include_output_pairs(args.targets):
            parser.error("--output cannot be combined with SOURCE=OUTPUT targets")
        if len(args.targets) != 1:
            parser.error("--output can only be used with exactly one target")
    return generate_dxf_targets(args.targets, output=args.output, verbose=bool(args.verbose))


if __name__ == "__main__":
    raise SystemExit(main())
