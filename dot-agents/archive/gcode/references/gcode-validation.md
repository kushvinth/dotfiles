# G-code Validation

`scripts/gcode_tool.py validate` performs static checks only. It does not simulate extrusion physics, firmware state, acceleration limits, or slicer-specific semantics.

## Required Checks

Validation fails when:

- The file is empty.
- No `G0`, `G1`, `G2`, or `G3` movement commands are present.
- No extrusion moves are present.
- No nozzle or bed temperature commands are present.
- Parsed absolute `X`, `Y`, or `Z` moves exceed the wrapper profile motion bounds.

Validation warns when:

- Unknown or unsupported G-code commands are encountered.
- Relative positioning is used; bounds checking is skipped while relative mode is active.

Warnings do not rewrite or delete commands. Treat them as review prompts, especially before sending G-code to unfamiliar firmware.

## Bounds Policy

The validator assumes absolute positioning until `G91` appears, and resumes absolute bounds checks after `G90`. This avoids false hard failures for relative motion blocks while still catching obvious out-of-bed absolute moves.

The wrapper profile provides printable bounds:

- `machine.bed_size_mm[0]`: maximum `X`
- `machine.bed_size_mm[1]`: maximum `Y`
- `machine.z_height_mm`: maximum `Z`

By default, motion bounds are `X=0..bed_size_mm[0]`, `Y=0..bed_size_mm[1]`, and `Z=0..z_height_mm`. If a native printer profile intentionally uses safe off-bed wipe, purge, or maintenance positions, set `machine.motion_bounds_mm` with explicit `x`, `y`, and/or `z` `[min, max]` ranges. Do this only from a real printer/profile source, not as a way to silence unknown G-code.

## Interpreting Results

`ok: true` means the file passed these static checks. It does not mean the G-code is safe to print on real hardware. Still review:

- Printer/profile match.
- Filament and temperature settings.
- Start and end G-code.
- Bed origin and coordinate system.
- Any unknown command warnings.
