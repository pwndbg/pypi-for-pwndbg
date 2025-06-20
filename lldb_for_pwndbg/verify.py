import sys
import re
import typing
import subprocess
import os
from pathlib import Path

system = sys.argv[1]
python_version = sys.argv[2]
binary_path = Path(sys.argv[3])


def eprint(msg: str):
    print(msg, file=sys.stderr)

def run(args: typing.List[str], no_error=False) -> str:
    result = subprocess.run(args, capture_output=True)
    if result.returncode != 0:
        if no_error:
            eprint(result.stderr)
            eprint("WARNING: Command failed with return code {}: {}".format(result.returncode, args))
            return ''

        eprint(result.stderr)
        eprint("Command failed with return code {}: {}".format(result.returncode, args))
        sys.exit(result.returncode)
    return result.stdout.decode("utf-8")

def iter_macho_deps(exe: Path) -> typing.Iterator[Path]:
    for line in run(["otool", "-L", str(exe)]).splitlines():
        line = line.strip()
        if not line:
            continue

        splited = line.split(' (', 1)
        if len(splited) != 2:
            continue

        lib_path = Path(splited[0])
        yield lib_path

def iter_elf_deps(exe: Path) -> typing.Iterator[Path]:
    for line in run(["patchelf", "--print-needed", str(exe)]).splitlines():
        line = line.strip()
        if not line:
            continue

        lib_path = Path(splited[0])
        yield lib_path


if sys.platform == "darwin":
    iter_deps = iter_macho_deps
else:
    iter_deps = iter_elf_deps


libpython_dependencies = {
    "3.10": {
        "linux": [
            "_lldb.cpython-310-x86_64-linux-gnu.so",
            "_lldb.cpython-310-aarch64-linux-gnu.so",
            "libpython3.10.so.1.0",
        ],
        "darwin": [
            "_lldb.cpython-310-darwin.so",
            "@executable_path/../../../lldb/_lldb.cpython-310-darwin.so",
            "@loader_path/../../../../lib/libpython3.10.dylib",
        ],
    },
    "3.11": {
        "linux": [
            "_lldb.cpython-311-x86_64-linux-gnu.so",
            "_lldb.cpython-311-aarch64-linux-gnu.so",
            "libpython3.11.so.1.0",
        ],
        "darwin": [
            "_lldb.cpython-311-darwin.so",
            "@executable_path/../../../lldb/_lldb.cpython-311-darwin.so",
            "@loader_path/../../../../lib/libpython3.11.dylib",
        ],
    },
    "3.12": {
        "linux": [
            "_lldb.cpython-312-x86_64-linux-gnu.so",
            "_lldb.cpython-312-aarch64-linux-gnu.so",
            "libpython3.12.so.1.0",
        ],
        "darwin": [
            "_lldb.cpython-312-darwin.so",
            "@executable_path/../../../lldb/_lldb.cpython-312-darwin.so",
            "@loader_path/../../../../lib/libpython3.12.dylib",
        ],
    },
    "3.13": {
        "linux": [
            "_lldb.cpython-313-x86_64-linux-gnu.so",
            "_lldb.cpython-313-aarch64-linux-gnu.so",
            "libpython3.13.so.1.0",
        ],
        "darwin": [
            "_lldb.cpython-313-darwin.so",
            "@executable_path/../../../lldb/_lldb.cpython-313-darwin.so",
            "@loader_path/../../../../lib/libpython3.13.dylib",
        ],
    },
    "3.14": {
        "linux": [
            "_lldb.cpython-314-x86_64-linux-gnu.so",
            "_lldb.cpython-314-aarch64-linux-gnu.so",
            "libpython3.14.so.1.0",
        ],
        "darwin": [
            "_lldb.cpython-314-darwin.so",
            "@executable_path/../../../lldb/_lldb.cpython-314-darwin.so",
            "@loader_path/../../../../lib/libpython3.14.dylib",
        ],
    },
}[python_version][system.split("-")[1]]

allowlist_dependencies = {
    "x86_64-linux": [
        "libm.so.6",
        "libpthread.so.0",
        "libc.so.6",
        "libdl.so.2",
        "ld-linux-x86-64.so.2",
    ],
    "aarch64-linux": [
        "libm.so.6",
        "libpthread.so.0",
        "libc.so.6",
        "libdl.so.2",
        "ld-linux-aarch64.so.1",
    ],
    "x86_64-darwin": [
        "/usr/lib/libcompression.dylib",
        "/System/Library/Frameworks/Foundation.framework/Versions/C/Foundation",
        "/System/Library/Frameworks/CoreFoundation.framework/Versions/A/CoreFoundation",
        "/System/Library/Frameworks/CoreServices.framework/Versions/A/CoreServices",
        "/System/Library/Frameworks/Security.framework/Versions/A/Security",
        "/usr/lib/libSystem.B.dylib",
        "/usr/lib/libobjc.A.dylib",
    ],
    "aarch64-darwin": [
        "/usr/lib/libcompression.dylib",
        "/System/Library/Frameworks/Foundation.framework/Versions/C/Foundation",
        "/System/Library/Frameworks/CoreFoundation.framework/Versions/A/CoreFoundation",
        "/System/Library/Frameworks/CoreServices.framework/Versions/A/CoreServices",
        "/System/Library/Frameworks/Security.framework/Versions/A/Security",
        "/usr/lib/libSystem.B.dylib",
        "/usr/lib/libobjc.A.dylib",
    ],
}[system]


def is_valid(library: str) -> bool:
    if library in allowlist_dependencies:
        return True
    if library in libpython_dependencies:
        return True

    for dep in allowlist_dependencies:
        if isinstance(dep, re.Pattern):
            if dep.match(library):
                return True

    for dep in libpython_dependencies:
        if isinstance(dep, re.Pattern):
            if dep.match(library):
                return True

    return False


for library in iter_deps(binary_path):
    library = str(library)
    if not is_valid(library):
        print("{} is not allowed".format(library), flush=True)
        os._exit(1)

os._exit(0)