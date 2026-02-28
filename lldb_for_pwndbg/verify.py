import sys
import re
import typing
import subprocess
import os
from pathlib import Path

system = sys.argv[1]
binary_path = Path(sys.argv[2])


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

        yield Path(line)


if sys.platform == "darwin":
    iter_deps = iter_macho_deps
else:
    iter_deps = iter_elf_deps


# libpython_loader.so/dylib is the shim that reads LLDB_LIBPYTHON at runtime
# and dlopen's the real libpython - no version-specific dependency needed.
libpython_dependencies = {
    "linux": [
        "_lldb.abi3.so",
        "liblldb_stub.so",
        "libpython_loader_lldb.so",
    ],
    "darwin": [
        "_lldb.abi3.so",
        "@executable_path/../../../lldb/native/_lldb.abi3.so",
        "@loader_path/libpython_loader_lldb.dylib",
    ],
}[system.split("-")[1]]

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
    "loongarch64-linux": [
        "libm.so.6",
        "libpthread.so.0",
        "libc.so.6",
        "libdl.so.2",
        "ld-linux-loongarch-lp64d.so.1",
    ],
    "s390x-linux": [
        "libm.so.6",
        "libpthread.so.0",
        "libc.so.6",
        "libdl.so.2",
        "ld64.so.1",
    ],
    "riscv64-linux": [
        "libm.so.6",
        "libpthread.so.0",
        "libc.so.6",
        "libdl.so.2",
        "ld-linux-riscv64-lp64d.so.1",
    ],
    "powerpc64le-linux": [
        "libm.so.6",
        "libpthread.so.0",
        "libc.so.6",
        "libdl.so.2",
        "ld64.so.2",
    ],
    "armv7l-linux": [
        "libm.so.6",
        "libpthread.so.0",
        "libc.so.6",
        "libdl.so.2",
        "ld-linux-armhf.so.3",
    ],
    "i686-linux": [
        "libm.so.6",
        "libpthread.so.0",
        "libc.so.6",
        "libdl.so.2",
        "ld-linux.so.2",
    ],
    "x86_64-darwin": [
        "/usr/lib/libcompression.dylib",
        "/System/Library/Frameworks/Foundation.framework/Versions/C/Foundation",
        "/System/Library/Frameworks/CoreFoundation.framework/Versions/A/CoreFoundation",
        "/System/Library/Frameworks/CoreServices.framework/Versions/A/CoreServices",
        "/System/Library/Frameworks/Security.framework/Versions/A/Security",
        "/usr/lib/libSystem.B.dylib",
        "/usr/lib/libobjc.A.dylib",
        "@loader_path/libcurl.4.dylib",
    ],
    "aarch64-darwin": [
        "/usr/lib/libcompression.dylib",
        "/System/Library/Frameworks/Foundation.framework/Versions/C/Foundation",
        "/System/Library/Frameworks/CoreFoundation.framework/Versions/A/CoreFoundation",
        "/System/Library/Frameworks/CoreServices.framework/Versions/A/CoreServices",
        "/System/Library/Frameworks/Security.framework/Versions/A/Security",
        "/usr/lib/libSystem.B.dylib",
        "/usr/lib/libobjc.A.dylib",
        "@loader_path/libcurl.4.dylib",
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