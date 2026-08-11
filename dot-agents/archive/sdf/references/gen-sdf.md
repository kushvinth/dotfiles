# SDF generation command

Use the SDF launcher to regenerate explicit SDFormat outputs from Python sources with top-level `gen_sdf()` functions.

```bash
python scripts/sdf path/to/model.py
python scripts/sdf path/to/model.py -o path/to/robot.sdf
python scripts/sdf path/to/a.py=out/a.sdf path/to/b.py=out/b.sdf
```

Plain Python targets write sibling `.sdf` files beside their sources. `-o` / `--output` is valid only with one plain target. Use `SOURCE.py=OUTPUT.sdf` pairs for custom multi-target destinations.

Relative source targets and CLI output paths resolve from the current working directory. When running from outside the skill directory, prefix the launcher path so source and target files still resolve from the intended workspace.

## What the command does

The tool should:

1. import the target Python source;
2. call top-level zero-argument `gen_sdf()`;
3. normalize the returned SDF XML or envelope;
4. parse the generated XML;
5. run bundled dependency-light validation;
6. optionally run external `gz sdf --check` if requested and available;
7. write the requested `.sdf` only after required checks pass;
8. print structured warnings and assumptions.

The command does **not** regenerate geometry, meshes, GLB/topology outputs, render assets, robot-description files, planning metadata, or simulator resource packages. Regenerate those with their owning workflows before regenerating SDF that references them.

## Optional external check

If implemented, the recommended flag is:

```bash
python scripts/sdf path/to/model.py --gz-check auto
python scripts/sdf path/to/model.py --gz-check required
python scripts/sdf path/to/model.py --gz-check never
python scripts/sdf path/to/model.py --strict
```

- `auto`: run `gz sdf --check` when `gz` is available; otherwise report the check as skipped and continue.
- `required`: fail if `gz` is unavailable or if `gz sdf --check` exits nonzero.
- `never`: skip external checking.

If the external checker requires a path, write to a temporary file first. Do not overwrite the target until bundled validation and all required external checks pass.

## Failure behavior

If validation fails, the newly generated payload is not written. Existing output files may be stale; fix the Python source and regenerate.

Errors should be blocking. Warnings and assumptions should be reported but should not fail generation unless the user or CI explicitly requests strict behavior.

## Execution safety

The launcher imports generator modules. Top-level Python code in generator files may execute. Use this command only for trusted project sources. A future subprocess runner may reduce accidental side effects, but it cannot make untrusted Python safe.
