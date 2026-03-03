import sys
import os
import subprocess
import pathlib
from glob import glob
from sysconfig import get_config_var


here = pathlib.Path(__file__).parent.resolve()
gdb_path = here / pathlib.Path('_vendor/bin/gdb')
data_path = here / pathlib.Path('_vendor/share/gdb')


def iter_libpython_paths():
    py_libpath = pathlib.Path(sys.base_exec_prefix) / 'lib' / get_libpython_name()
    yield py_libpath

    libpython_path = pathlib.Path(get_config_var("LIBDIR")) / get_libpython_name()
    yield libpython_path


def get_libpython_name():
    libpy = get_config_var("INSTSONAME")
    is_valid_path = False
    if sys.platform == "linux":
        is_valid_path = libpy.endswith(".so") or ".so." in libpy
    elif sys.platform == "darwin":
        is_valid_path = libpy.endswith(".dylib")
    else:
        raise RuntimeError(f'Unsupported platform {sys.platform}')

    if is_valid_path:
        return libpy

    # When PY_ENABLE_SHARED=0, then INSTSONAME returns invalid value on MacOS (wtf?)
    py_version = f'{sys.version_info.major}.{sys.version_info.minor}'
    if sys.platform == 'darwin':
        return f'libpython{py_version}.dylib'

    raise RuntimeError(f'INSTSONAME has invalid path: {libpy}')


def check_lib_python():
    in_venv = sys.base_exec_prefix != sys.exec_prefix
    if in_venv:
        # Install libpython into venv

        venv_libpath = pathlib.Path(sys.exec_prefix) / 'lib' / get_libpython_name()
        if not venv_libpath.exists():
            py_libpath = next(filter(lambda p: p.exists(), iter_libpython_paths()), None)
            if py_libpath is None:
                # TODO: only debian like?
                message = (
                    "[error] missing libpython. "
                    "Please install python3-dev or python3-devel"
                )
                raise NotImplementedError(message)

            venv_libpath.symlink_to(py_libpath)

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
    check_lib_python()

    envs = os.environ.copy()
    envs['PYTHONNOUSERSITE'] = '1'
    envs['PYTHONPATH'] = ':'.join(sys.path)
    envs['PYTHONHOME'] = ':'.join([sys.prefix, sys.exec_prefix])

    sys.argv.insert(1, str(data_path))
    sys.argv.insert(1, "--data-directory")
    exec_prog(str(gdb_path), sys.argv, envs)


if __name__ == '__main__':
    main()
