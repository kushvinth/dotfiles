# SDF workflow

Use this reference when editing SDF robot model structure, world structure, mesh references, simulator metadata, or generated SDF output.

## Edit loop

1. Find the Python source that defines `gen_sdf()`.
2. Treat that source as authoritative. Do not hand-edit generated `.sdf` output unless explicitly instructed.
3. Identify the target consumer and required SDFormat version.
4. Decide whether the output is model-level, world-level, or model-in-world.
5. Fill or update the design ledger before writing XML.
6. For every pose and axis, state the frame in which it is expressed. Use `relative_to` / `expressed_in` where ambiguity would otherwise remain.
7. Edit the generator source.
8. Regenerate only the explicit target.
9. Review bundled validation errors as structural guardrails, not exhaustive simulator proof.
10. Hand generated or modified `.sdf` files to `$cad-viewer` for live viewer links when available.
11. Run available smoke tests.
12. Report assumptions and skipped checks.

## Model vs world

Use **model-level SDF** when exporting a reusable robot or object model that another world can include.

Use **world-level SDF** when the task includes:

- physics engine settings;
- lights or scene setup;
- terrain or ground plane;
- multiple initial model placements;
- world plugins;
- includes of external model packages;
- simulator scene setup.

Use **model-in-world SDF** when the task explicitly needs both an inline model and world-specific context.

The lightweight validator should allow pure world-only documents. A world-only document with lights, physics, actors, or includes can be valid SDFormat even when it contains no inline `<model>`.

## Mesh references

SDF mesh URIs should be stable from the generated `.sdf` file's perspective or use a simulator/package URI convention understood by the consumer.

Good URI choices include:

- relative paths beside the generated SDF when the model is self-contained;
- `model://...` for simulator model packages;
- `package://...` when the simulator environment resolves package roots;
- `fuel://...`, `http://...`, or `https://...` only when the consumer is expected to fetch external assets.

Do not use generated SDF XML as the source of truth for mesh placement. Prefer deriving visual and collision mesh references from the same source data that owns mesh instance placement.

## Inertials and physics

For dynamic models, inertial data is simulation-critical. If inertials are estimated, record the approximation method. Do not copy visual origins into inertial origins unless that is physically justified.

Collision geometry should be selected for stable and fast physics, not visual fidelity. Use primitive or simplified collision geometry when possible.

## Plugins and sensors

For plugins and sensors, record:

- plugin filename or sensor type;
- expected simulator distribution/version;
- topics, frames, update rates, namespaces;
- parameter source;
- startup smoke test result.

Do not invent plugin parameters. Incorrect plugin XML can pass lightweight validation and still fail at simulator load time.

CAD Viewer reviews SDF files as static model/world structure through `$cad-viewer` links. Do not add Explorer-only motion plugins; use simulator-native controllers, plugins, or test harnesses for simulator behavior.

## Existing SDF inspection

When inspecting existing `.sdf` files, separate three questions:

1. Is the XML structurally valid enough for the bundled validator?
2. Is it compatible with the target SDFormat/libsdformat/simulator version?
3. Does it satisfy this project's packaging, mesh, and workflow policy?

Do not reject valid SDF solely because it violates a project preference unless the task or repository policy requires that preference.
