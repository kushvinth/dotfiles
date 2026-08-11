from __future__ import annotations

import sys
from pathlib import Path

TOOL_DIR = Path(__file__).resolve().parent
tool_path = str(TOOL_DIR)
if tool_path not in sys.path:
    sys.path.insert(0, tool_path)

from cli import main


if __name__ == "__main__":
    raise SystemExit(main())
