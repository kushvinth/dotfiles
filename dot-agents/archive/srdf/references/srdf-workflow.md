# SRDF workflow

SRDF is the MoveIt semantic companion to a URDF. Keep physical robot structure, links, joints, geometry, inertials, mesh references, and limits in URDF. Keep planning semantics in SRDF.

## Edit loop

1. Start from a valid URDF. SRDF cannot repair wrong link frames, joint origins, limits, or geometry.
2. Find the Python source that defines `gen_srdf()`.
3. Treat that source as authoritative. Do not hand-edit generated `.srdf` output.
4. Fill or update the planning ledger.
5. Define virtual joints when the robot root needs a planning/world attachment.
6. Define passive joints for unactuated joints.
7. Define planning groups from URDF topology.
8. Define end effectors only after group membership is known.
9. Define group states in URDF-native units and check them against URDF limits.
10. Define disabled collisions only from adjacency, sampling, Setup Assistant output, or explicit user evidence.
11. Regenerate only the explicit SRDF target with `scripts/srdf`.
12. Hand generated or modified `.srdf` files to `$cad-viewer` for live viewer links when available.
13. Run MoveIt smoke tests when available. Use `$cad-viewer` for local Viewer-based IK or path-planning controls.
14. Report assumptions and skipped checks.

## Typical SRDF content

- `<virtual_joint>` entries for root/world attachment.
- `<passive_joint>` entries for unactuated joints.
- `<group>` planning groups, usually by joint list or chain.
- `<end_effector>` entries that connect a tool group to a parent planning group.
- `<group_state>` named joint states such as `home`.
- `<disable_collisions>` pairs for adjacent, sampled-safe, or intentionally ignored collisions.

## Planning groups

MoveIt acts on a selected planning group. Other joints are left stationary unless they belong to the selected group or are otherwise managed by the planning pipeline.

A group may be represented as:

- a collection of joints;
- a collection of links;
- a serial chain from base link to tip link;
- a collection of subgroups.

For serial chains, the base link is the parent link of the first joint in the chain, and the tip link is the child link of the last joint. Verify that the URDF graph actually contains that path.

## Group states

`<group_state>` values are stored in URDF-native units:

- revolute and continuous joints: radians;
- prismatic joints: meters.

The current runtime validates group-state values against group membership, fixed/mimic status, finite numeric values, and URDF limits when limits are available.

## End effectors

An end-effector is usually a separate tool or gripper group attached to a parent planning group. Avoid overlap between the end-effector group and the parent group. Record the target/TCP link in the planning ledger and in MoveIt2 request settings when it differs from the inferred group tip.

## Disabled collisions

`<disable_collisions>` pairs affect planning safety. Use truthful reasons:

- `Adjacent`;
- `Never`;
- `Always`;
- `Default`;
- `Setup Assistant sampled`;
- explicit manual rationale.

Do not generate broad disabled-collision lists from prose or visual appearance.

## CAD Viewer handoff and MoveIt2 controls

After creating or modifying generated `.srdf` files, hand the explicit output path to `$cad-viewer` for a live viewer link when that skill is available. SRDF does not own Viewer startup.

When the user needs local IK or path-planning controls, include that in the `$cad-viewer` handoff. CAD Viewer owns the local `moveit2_server`, including setup, environment checks, WebSocket URL wiring, and protocol details. Provide the SRDF path plus any known planning group, target/TCP link, target frame, pose, start state, and skipped assumptions.

The local server is a smoke-test helper, not a replacement for a full MoveIt configuration package.
