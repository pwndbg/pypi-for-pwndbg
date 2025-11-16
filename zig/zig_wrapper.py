#!/usr/bin/env python3
import os
import sys
import re

args = sys.argv[1:]

def is_loongarch64():
    global args

    has_strict_align = "-mno-strict-align" in args
    if not has_strict_align:
        return False

    prev_arg = ''
    for arg in args:
        if has_strict_align and prev_arg == "-target" and arg.startswith("loongarch64-"):
            return True
        prev_arg = arg
    return False


if is_loongarch64():
    args.remove("-mno-strict-align")

PROGRAM = "@zig@"
#print(f'ARGS: {args}', flush=True, file=sys.stderr)
os.execve(PROGRAM, [PROGRAM] + args, os.environ)
