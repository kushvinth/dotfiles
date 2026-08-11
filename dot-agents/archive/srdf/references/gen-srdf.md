# SRDF generation command

Regenerate explicit MoveIt SRDF outputs from Python sources with top-level `gen_srdf()` functions.

```bash
python scripts/srdf path/to/semantic.py
python scripts/srdf path/to/semantic.py -o path/to/robot.srdf
python scripts/srdf path/to/a.py=out/a.srdf path/to/b.py=out/b.srdf
```

Plain Python targets write a sibling `.srdf` beside the source. `-o` / `--output` is valid only with one plain target. Use `SOURCE.py=OUTPUT.srdf` pairs for custom multi-target destinations.

`gen_srdf()` must return an envelope dictionary containing:

- `xml`: complete SRDF `<robot>` XML as an `xml.etree.ElementTree.Element` or XML string;
- `urdf`: a POSIX relative path from the generator source file to the linked `.urdf`.

## What the command does

The tool:

1. imports the target Python source;
2. calls `gen_srdf()`;
3. resolves the linked URDF path relative to the generator source file;
4. injects or updates local `tcad:urdf` metadata so downstream tools can find the URDF;
5. parses the generated SRDF;
6. validates the SRDF against the linked URDF;
7. writes the requested `.srdf` only after validation passes.

There is no hidden SRDF artifact. The generated `.srdf` is the MoveIt inventory handed to `$cad-viewer` for a live CAD Viewer link and optional MoveIt2 controls.

## Execution safety

The CLI imports generator modules directly. Top-level Python code in the generator file will execute. Use this command only for trusted project sources.
