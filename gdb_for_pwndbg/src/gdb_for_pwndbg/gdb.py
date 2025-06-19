import sys
import os
import subprocess
import pathlib
from glob import glob
from sysconfig import get_config_var


here = pathlib.Path(__file__).parent.resolve()
gdb_path = here / pathlib.Path('_vendor/bin/gdb')


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


def main():
    check_lib_python()

    envs = os.environ.copy()
    envs['PYTHONNOUSERSITE'] = '1'
    envs['PYTHONPATH'] = ':'.join(sys.path)
    envs['PYTHONHOME'] = ':'.join([sys.prefix, sys.exec_prefix])

    # todo: ld-path? /proc/self/exe? /proc/self/maps?
    os.execve(str(gdb_path), sys.argv, env=envs)


if __name__ == '__main__':
    main()
