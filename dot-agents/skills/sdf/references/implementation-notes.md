# SDF implementation notes

These notes describe the intended runtime shape after the rewrite. Keep this file accurate when implementation changes.

## Implemented behavior

The SDF skill should:

- generate explicit targets only;
- validate generated XML before writing;
- preserve existing `gen_sdf()` return compatibility: XML element, XML string, or envelope dict with `xml`;
- accept envelope `assumptions`, `warnings`, and `metadata` fields;
- support `--strict` warning-as-failure behavior;
- optionally run `gz sdf --check` through `--gz-check auto|required|never`;
- provide optional stdlib-only authoring helpers;
- parse SDF XML from files or in-memory strings;
- resolve local mesh files relative to the generated output location;
- accept external mesh URI schemes without local filesystem resolution;
- allow pure world files when structurally valid.

## Intended bundled validation scope

The bundled validator should check common structural and numeric errors:

- root element and version;
- document shape and pure world support;
- required names and duplicate names in local scopes;
- pose value counts, rotation formats, finite values, degrees usage, quaternion normalization, and local `relative_to` resolution;
- named frame attachment references and cycles;
- joint type set, parent/child references, axis/axis2 values, limits, and dynamics numbers;
- visual/collision owner names and geometry presence;
- primitive geometry dimensions and mesh URI/scale;
- local mesh path existence;
- inertial mass and inertia tensor plausibility;
- sensor name/type/update-rate structure;
- plugin name/filename structure.

## Remaining limitations

The bundled validator is still not a full libsdformat or simulator validator. It should not claim to fully validate:

- every version-specific SDFormat schema rule;
- all nested-model frame semantics;
- transform math or resolved poses;
- mesh unit conventions;
- arbitrary mesh inertia or collision quality;
- simulator-specific physics settings;
- plugin schemas and runtime availability;
- sensor runtime behavior;
- target simulator support for every element.

Use the design ledger, structured diagnostics, `gz sdf --check`, simulator load tests, and explicit reporting of skipped checks.

## Execution safety

The current launcher imports generator modules in-process. Generator Python files execute code and must be trusted project sources.
