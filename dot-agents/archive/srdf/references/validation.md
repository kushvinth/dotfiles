# SRDF validation

Generation validates every `gen_srdf()` result against its linked URDF before writing. This catches many planning-semantics errors, but it is not a substitute for MoveIt Setup Assistant, MoveIt runtime tests, or collision-matrix sampling.

Generated or modified `.srdf` files should be handed to `$cad-viewer` for live viewer links when available.

## Current generation-time checks

The current runtime checks that:

- `gen_srdf()` returns an envelope dictionary;
- envelope fields are exactly `xml` and `urdf`;
- the URDF path is relative to the generator source, uses POSIX separators, ends in `.urdf`, and exists;
- SRDF XML parses and has root `<robot name="...">`;
- SRDF robot name matches the URDF robot name;
- local `tcad:urdf` metadata is injected or updated and matches the linked URDF path relative to the generated SRDF; legacy `explorer:urdf` metadata remains readable;
- at least one planning group exists;
- planning groups are named and unique;
- each planning group defines joints, links, chains, or subgroups;
- group joint names, link names, and subgroup names exist;
- chain base/tip links exist;
- end effectors reference existing parent links and groups;
- end-effector groups do not overlap their parent group when a parent group is provided;
- end-effector parent links are in the parent group or adjacent to the end-effector group;
- group states reference existing groups;
- group-state joints exist and belong to the selected group after group expansion;
- group-state values are finite;
- group states do not set fixed or mimic joints;
- revolute/prismatic group-state values are within URDF limits when limits are available;
- disabled collision pairs have distinct links, valid link references, non-empty reasons, and no reversed duplicates;
- many manually reasoned disabled collision pairs trigger a warning.

## Optional CAD Viewer MoveIt2 checks

When `$cad-viewer` starts its local MoveIt2 server for SRDF review, the server additionally checks:

- request `protocolVersion`;
- request type;
- repository-relative SRDF path and traversal safety;
- linked URDF path from `tcad:urdf` metadata;
- planning group selection;
- target frame and target link existence;
- target orientation shape and quaternion normalization;
- position-only IK consistency;
- native joint value parsing;
- legacy degree-field conversion by joint type;
- planner and IK setting basic numeric validity.

## Important current limitations

Do not treat a passing validation as proof of planning correctness. The current lightweight runtime does not fully validate:

- full URDF graph consistency; duplicate URDF links or joints can be collapsed by shallow inventory parsing;
- chain base/tip connectivity at generation time unless group-state expansion exposes the issue;
- subgroup cycles as hard errors in every path;
- `<virtual_joint>` inventory and validation;
- `<passive_joint>` inventory and exclusion from all active groups;
- collision matrix correctness through sampled self-collision analysis;
- actual IK solver availability for each group;
- actual planning success in the target MoveIt environment;
- controller configuration;
- full orientation-constraint behavior beyond request normalization.

Use MoveIt Setup Assistant or a MoveIt runtime smoke test for these checks.

## Manual planning checks

After generation, verify:

### URDF dependency

- URDF has been checked by the URDF workflow.
- URDF collision geometry is suitable for MoveIt collision checking.
- Active, fixed, mimic, and passive joints are understood.

### Planning groups

- Each chain has a real URDF path from base to tip.
- Each group contains the intended active joints and no accidental fixed/mimic/passive joints.
- Subgroups do not create ambiguous or cyclic group definitions.
- The selected planner/IK solver supports the group.

### End effectors

- End-effector group and parent group do not share links.
- Parent link is the real attachment point.
- Target/TCP link is explicit for pose requests.

### Group states

- Values use radians/meters, not degrees.
- Values are inside URDF limits.
- Named states are collision-free when intended.

### Disabled collisions

- Pairs came from adjacency, sampling, Setup Assistant output, or explicit user evidence.
- No broad disable list was invented by the model.
- Manual pairs were reviewed for safety.

## Validation report format

Use a compact report:

```text
Checks run:
- SRDF generation validation: passed
- linked URDF validation: previously passed with URDF skill
- CAD Viewer link: returned
- MoveIt Setup Assistant review: skipped, unavailable
- CAD Viewer MoveIt2 IK smoke test: passed for manipulator/tool0
- collision matrix sampling: skipped, no MoveIt environment

Assumptions:
- Assumed tool0 is the desired TCP.
- Disabled collisions are adjacency-only.
```
