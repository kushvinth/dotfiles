# URDF Generation

Regenerate explicit URDF outputs from Python sources with top-level `gen_urdf()` functions.

```bash
python scripts/urdf path/to/assembly.py
python scripts/urdf path/to/assembly.py -o path/to/robot.urdf
python scripts/urdf path/to/a.py=out/a.urdf path/to/b.py=out/b.urdf
```

Plain Python targets write a sibling `.urdf` beside the source. `-o`/`--output` is valid only with one plain target. Use `SOURCE.py=OUTPUT.urdf` pairs for custom multi-target destinations.

`gen_urdf()` must be a top-level zero-argument function returning the root `xml.etree.ElementTree.Element`, a complete URDF XML string, or an accepted envelope whose only field is `xml`. See `references/generator-contract.md`.

Relative source targets and CLI output paths resolve from the current working directory.

## Default Validation Behavior

The generation command validates the generated URDF before accepting the output. There is no separate validation-only command in this skill.

A generation failure should be treated as a model or source problem, not as a reason to hand-edit the generated `.urdf`. Fix the generator source, then regenerate the explicit target.

The generation-time validation is intended to catch compact robot-description issues such as:

- malformed XML or wrong root element;
- missing or duplicate link and joint names;
- invalid parent/child references;
- multiple roots, disconnected graphs, or cycles;
- suspicious joint limits, axes, origins, geometry, mesh references, or inertials when supported by the runtime.

## Boundaries

This tool runs only `gen_urdf()`. It does not regenerate CAD, mesh/export, GLB/topology, render, SDF, SRDF, MoveIt2, or simulator outputs.

If URDF visual/collision mesh references depend on updated CAD or mesh outputs, regenerate those explicit targets separately with the owning CAD or mesh workflow, then regenerate the affected URDF.

After creating or modifying generated `.urdf` files, hand explicit paths to `$cad-viewer` for live viewer links when available.

## Failure Handling

When generation-time validation fails:

1. inspect the reported links, joints, mesh references, or inertial fields;
2. update the source generator, design ledger, or referenced assets;
3. regenerate the same explicit URDF target;
4. do not patch the generated `.urdf` directly unless the task is explicitly forensic and the patch will not be treated as source of truth.
