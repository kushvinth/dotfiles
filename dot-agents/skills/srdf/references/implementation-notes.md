# SRDF implementation notes

These notes describe the current runtime shape so the documentation does not overstate what the code enforces.

## Implemented in the current code

- `scripts/srdf` generates explicit targets only.
- `gen_srdf()` must return an envelope with `xml` and `urdf`.
- Generated SRDF is validated against the linked URDF before writing.
- The CLI injects or updates local `tcad:urdf` metadata.
- Group states use `joint_values_by_name` / `jointValuesByName` in URDF-native units.
- Deprecated `joint_values_by_name_rad` / `jointValuesByNameRad` aliases remain for compatibility.
- Group-state values are checked for group membership, finite values, fixed/mimic status, and URDF limits when available.
- End-effector overlap and adjacency checks are implemented.
- Disabled-collision reasons are required and classified into broad provenance buckets.
- Optional CAD Viewer MoveIt2 controls use `protocolVersion: 1`.
- Pose targets support `quat_xyzw` and `rpy`.
- Position-only IK is explicit in request settings and defaults based on whether orientation is provided.
- Legacy degree fields are converted by joint type so prismatic values remain linear.
- Error responses sanitize absolute paths unless debug errors are enabled.

## Not yet fully implemented in code

The following remain process requirements and future code-improvement targets:

- full URDF structural validation shared with the URDF skill;
- virtual joint parsing and validation;
- passive joint parsing and exclusion from active planning variables;
- hard failure for disconnected chain base/tip definitions in every case;
- subgroup cycle detection as a first-class validation error;
- typed SRDF generation helpers;
- structured assumption/warning envelope fields;
- sampled self-collision matrix generation;
- full MoveIt configuration package generation;
- safer generator execution in a subprocess.

Until those are implemented, rely on the planning ledger, MoveIt Setup Assistant, `$cad-viewer` handoff for visual/MoveIt smoke tests when available, and explicit reporting of skipped checks.
