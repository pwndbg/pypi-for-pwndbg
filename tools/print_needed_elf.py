#!/usr/bin/env python3
# Prints resolved paths to needed libraries for an ELF executable.
# ldd also does this, but it segfaults in some odd scenarios so we avoid it.
import sys
import os
import subprocess
from glob import glob
from typing import Any, Iterable, List


def eprint(msg: Any):
    print(msg, file=sys.stderr)


def run(args: List[str]) -> str:
    try:
        result = subprocess.run(args, capture_output=True)
    except TypeError:
        # old python
        result = subprocess.run(args, stderr=subprocess.DEVNULL, stdout=subprocess.PIPE)
    if result.returncode != 0:
        eprint(result.stderr)
        eprint("Command failed with return code {}: {}".format(result.returncode, args))
        sys.exit(result.returncode)
    return result.stdout.decode("utf-8")


def stripped_strs(strs: Iterable[str]) -> Iterable[str]:
    return (cleaned for x in strs for cleaned in [x.strip()] if cleaned != "")


def parse_ld_conf_file(fn):
    paths = []
    for line in open(fn).read().splitlines():
        line = line.strip()
        if not line:
            continue
        if line.startswith("#"):
            continue
        if line.startswith("include "):
            for sub_fn in glob(line[len("include "):]):
                paths.extend(parse_ld_conf_file(sub_fn))
            continue
        paths.append(line)
    return paths


def get_ld_paths():
    # To be very correct, see man-page of ld.so.
    # And here: http://unix.stackexchange.com/questions/354295/what-is-the-default-value-of-ld-library-path/354296
    # Short version, not specific to an executable, in this order:
    # - LD_LIBRARY_PATH
    # - /etc/ld.so.cache (instead we will parse /etc/ld.so.conf)
    # - /lib, /usr/lib (or maybe /lib64, /usr/lib64)
    LDPATH = os.getenv("LD_LIBRARY_PATH")
    PREFIX = os.getenv("PREFIX")
    paths = []
    if LDPATH:
        paths.extend(LDPATH.split(":"))
    if os.path.exists("/etc/ld.so.conf"):
        paths.extend(parse_ld_conf_file("/etc/ld.so.conf"))
    else:
        eprint('WARNING: file "/etc/ld.so.conf" not found.')

    if PREFIX:
        if os.path.exists(PREFIX + "/etc/ld.so.conf"):
            paths.extend(parse_ld_conf_file(PREFIX + "/etc/ld.so.conf"))
        else:
            eprint('WARNING: file "' + PREFIX + '/etc/ld.so.conf" not found.')
        paths.extend([PREFIX + "/lib", PREFIX + "/usr/lib", PREFIX + "/lib64", PREFIX + "/usr/lib64"])

    paths.extend(["/lib", "/usr/lib", "/lib64", "/usr/lib64"])
    return paths


def get_rpaths(exe: str) -> List[str]:
    base = list(stripped_strs(run(["patchelf", "--print-rpath", exe]).split(":")))
    base.extend(get_ld_paths())
    return base


def resolve_origin(origin: str, paths: Iterable[str]) -> Iterable[str]:
    return (path.replace("$ORIGIN", origin) for path in paths)


def get_needed(exe: str) -> Iterable[str]:
    return stripped_strs(run(["patchelf", "--print-needed", exe]).splitlines())


def resolve_paths(needed: Iterable[str], rpaths: List[str]) -> Iterable[str]:
    existing_paths = lambda lib, paths: (
        abs_path for path in paths for abs_path in [os.path.join(path, lib)]
        if os.path.exists(abs_path)
    )
    return (
        found if found is not None else eprint("Warning: can't find {} in {}".format(lib, rpaths))
        for lib in needed for found in [next(existing_paths(lib, rpaths), None)]
    )


def main(exe: str):
    dirname = os.path.dirname(exe)
    rpaths_raw = list(get_rpaths(exe))
    rpaths_raw = [dirname] if rpaths_raw == [] else rpaths_raw
    rpaths = list(resolve_origin(dirname, rpaths_raw))
    for path in (x for x in resolve_paths(get_needed(exe), rpaths) if x is not None):
        print(path)


if __name__ == "__main__":
    main(*sys.argv[1:])
