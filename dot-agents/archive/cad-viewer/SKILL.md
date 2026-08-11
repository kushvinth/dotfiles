---
name: cad-viewer
description: Start or reuse CAD Viewer and return review links for explicit CAD, implicit CAD, robot-description, and G-code files. Use when visually reviewing `.step`, `.stp`, `.implicit.js`, `.implicit.mjs`, `.glb`, `.stl`, `.3mf`, `.gcode`, `.dxf`, `.urdf`, `.srdf`, or `.sdf` files, especially when handed off from CAD, implicit-cad, G-code, URDF, SRDF, or SDF generation skills.
---

# CAD Viewer

Provenance: maintained in [earthtojake/text-to-cad](https://github.com/earthtojake/text-to-cad).
Use the installed local skill files as the runtime source of truth; the
repository link is only for provenance and release review.

Use this skill to open existing or newly generated CAD, implicit CAD,
robot-description, DXF, or plain FDM G-code files in CAD Viewer and hand back
live review links. The expected input is one or more explicit file paths.

## Start Viewer

Use one local CAD Viewer per machine and serve every directory through `?dir=`.
The Viewer advertises `dynamic-root`, so a single server answers for any
absolute directory; you never need a second server just to change directories.

First check whether a reusable Viewer is already running on the default port:

```bash
curl -sS -m 2 http://127.0.0.1:4178/__cad/server
```

Reuse that server when the response is JSON with `"app": "cad-viewer"` and
`"dynamicRoot": true`. Take its `url` and `port` from the response and skip
straight to Links. Start your own server instead when the probe fails, or when
the response's `viewerVersion` differs from the `version` in
`scripts/viewer/package.json` — a different version is another checkout's
Viewer, not this skill's runtime.

To start one, run from this skill directory:

```bash
npm --prefix scripts/viewer run serve -- --host 127.0.0.1 --dir <absolute-model-root> --shutdown-after 12h --json
```

Choose `--dir` as the absolute directory that contains the model artifacts and
sidecars, commonly `<repo>/models` or the consuming project's equivalent model
directory. The `file=` value must be relative to that `--dir`.

The server binds `4178` when it is free and scans forward when it is not, so do
not pick ports by hand or probe for a free one. Read the bound port from the
`--json` startup line described under Claude Preview rather than assuming
`4178`, then append `file=`:

```bash
http://127.0.0.1:<bound-port>/?dir=/absolute/project/models&file=path/to/model.step
```

In sandboxed agent environments, local binding or probe failures such as `EPERM`
or `EACCES` can be expected; rerun the same command with the needed
permission/escalation.

## Links

- Before returning any `file=` link, resolve `<dir>/<file>` and confirm the
  artifact exists. Pass the generated artifact (e.g. `.step`), not its
  generator source (e.g. `.py`). If the resolved path is missing, do not
  return the link, and instead report the problem and point to the correct
  generated artifact path.
- Return one Viewer URL per requested file.
- Start/reuse the Viewer once per absolute directory `--dir`, then append
  `file=<path>` for each requested file. The file path must be relative to
  `--dir`.
- For directory-only review links, return the started or reused Viewer URL
  without adding `file=`.
- Do not stop an existing Viewer server unless the user asks.
- If Viewer startup fails, report the failure and continue with the owning skill's non-GUI validation or artifacts.

## Claude Preview

The viewer port is dynamic — `4178` is only the first candidate, and the server
scans forward when it is taken. To integrate with the Claude Preview tool, pass
`--json` when starting the server:

```bash
npm --prefix scripts/viewer run serve -- --host 127.0.0.1 --dir <absolute-model-root> --shutdown-after 12h --json
```

The server writes a JSON result line to stdout after the human-readable lines.
Parse it by taking the last line of stdout that begins with `{`:

```json
{"url":"http://127.0.0.1:<port>/?dir=<absolute-model-root>","host":"127.0.0.1","port":<port>,"action":"start"}
```

The line is written once the listener is bound, so `url` is ready to hand to
the Claude Preview tool without further probing. When you reused an existing
Viewer from the `/__cad/server` probe instead of starting one, use that
response's `url` and append `?dir=<absolute-model-root>` yourself.

## References

- Read `references/development.md` when the user asks to modify, debug, or
  iterate on CAD Viewer source.
- Read `references/viewer-features.md` when you need supported file types, Viewer controls, or file-specific feature details.
- Read `references/moveit2-server.md` only when the user specifically needs optional SRDF MoveIt2 IK or path-planning controls.
