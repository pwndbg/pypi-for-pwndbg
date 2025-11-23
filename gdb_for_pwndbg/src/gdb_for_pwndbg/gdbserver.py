import sys
import os
import subprocess
import pathlib
from glob import glob
from sysconfig import get_config_var


here = pathlib.Path(__file__).parent.resolve()
gdb_server_path = here / pathlib.Path('_vendor/bin/gdbserver')


def get_loader():
    if sys.platform != "linux":
        return None

    known_loaders = {
        "x86_64-linux": "ld-linux-x86-64.so.2",
        "aarch64-linux": "ld-linux-aarch64.so.1",
        "loongarch64-linux": "ld-linux-loongarch-lp64d.so.1",
        "s390x-linux": "ld64.so.1",
        "riscv64-linux": "ld-linux-riscv64-lp64d.so.1",
        "powerpc64le-linux": "ld64.so.2",
        "armv7l-linux": "ld-linux-armhf.so.3",
        "i686-linux": "ld-linux.so.2",
    }
    try:
        with open("/proc/self/maps") as f:
            for line in f:
                parts = line.split()
                if len(parts) < 6:
                    continue
                _, perms, _, _, _, path = parts[:6]
                if "r-xp" not in perms:
                    continue
                for loader_name in known_loaders.values():
                    if path.endswith("/"+loader_name):
                        return path
    except:
        pass
    return None


def exec_prog(prog, args, envs):
    ld_path = get_loader()
    if ld_path is None:
        os.execve(prog, args, env=envs)
    else:
        args.insert(0, ld_path)
        args[1] = prog
        os.execve(ld_path, args, env=envs)


def main():
    if sys.platform == "darwin":
        print("gdbserver is not supported on macOS. Use Apple's 'debugserver' instead.")
        os._exit(1)

    envs = os.environ.copy()
    exec_prog(str(gdb_server_path), sys.argv, envs)

if __name__ == '__main__':
    main()
