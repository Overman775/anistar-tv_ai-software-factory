import os

from factory.paths import TOOLS

CLI = [str(TOOLS / "bin" / ("cli.cmd" if os.name == "nt" else "cli"))]
