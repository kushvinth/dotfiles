# STEP generation

Read this file when generating or regenerating STEP/STP artifacts from build123d Python source or from direct STEP/STP targets.

## Tool

The launcher lives in the CAD skill directory:

```bash
python scripts/step [--kind {part|assembly}] targets... [flags]
```

Use explicit target paths only; target paths resolve from the command cwd unless absolute. Do not rely on directory-wide generation.

Plain generated Python targets write sibling `.step` outputs. Use `-o`/`--output` only with one plain generated Python target, or use `SOURCE.py=OUTPUT.step` positional pairs for per-target custom outputs. Paired output paths resolve from the command cwd and are valid only for generated Python sources, not direct STEP/STP inputs. Do not put output paths in the `gen_step()` return value; the CLI owns output paths.

## Generated Python source

This is the default path when designing from scratch or modifying a generated model. Generated build123d sources define:

```python
def gen_step():
    ...
    return step_ready_shape_or_labeled_compound
```

Generated Python targets infer their kind from the source metadata and `gen_step()` return value; pass the source path directly:

```bash
python scripts/step path/to/part.py
python scripts/step path/to/part.py -o path/to/custom.step
python scripts/step path/to/a.py=out/a.step path/to/b.py=out/b.step
python scripts/step path/to/assembly.py
```

Passing a generated assembly `.step` directly treats it as imported native STEP and loses source-level assembly composition; pass the `.py` assembly source. For generated build123d assemblies, prefer `cadpy.assembly.AssemblyHelper` in the Python source so native labels, named mate frames, and source-level relationships are preserved before STEP export (see `positioning.md`).

## Direct STEP/STP imports

Use a direct STEP/STP target when no generator exists (imported or downloaded STEP) or the user explicitly identifies a STEP/STP file as the target. The GLB/topology artifacts are then generated from the STEP file itself:

```bash
python scripts/step --kind part path/to/imported.step
```

Direct targets support the same mesh sidecar flags as generator targets; read `supported-exports.md` for STL and 3MF sidecars.

## Viewer artifacts

Every `scripts/step` run also writes hidden adjacent GLB/topology artifacts as part of the normal build. They power CAD Viewer review, `$cad-viewer` workflows, and `scripts/inspect` refs, and are not optional in the STEP workflow.

## After generation

- Confirm the process succeeded and the STEP file exists and is non-empty.
- Run the baseline inspection and any spec-driven checks per `inspection-and-validation.md`:

```bash
python scripts/inspect refs path/to/model.step --facts --planes --positioning
```
