import sys
import os
import subprocess
import pathlib
from glob import glob
from sysconfig import get_config_var


here = pathlib.Path(__file__).parent.resolve()
gdb_path = here / pathlib.Path('_vendor/bin/gdb')


def check_dynamic_linked():
    enable_shared = get_config_var("PY_ENABLE_SHARED") or get_config_var("Py_ENABLE_SHARED")
    if not enable_shared or not int(enable_shared):
        message = (
            "GDB requires dynamic linking to the `libpython` "
            "but current instance of CPython was built without `--enable-shared`."
        )
        raise NotImplementedError(message)


def iter_libpython_paths():
    py_libpath = pathlib.Path(sys.base_exec_prefix) / 'lib' / get_config_var("INSTSONAME")
    yield py_libpath

    libpython_path = pathlib.Path(get_config_var("LIBDIR")) / get_config_var("INSTSONAME")
    yield libpython_path


def check_lib_python():
    in_venv = sys.base_exec_prefix != sys.exec_prefix
    if in_venv:
        # Install libpython into venv

        venv_libpath = pathlib.Path(sys.exec_prefix) / 'lib' / get_config_var("INSTSONAME")
        if not venv_libpath.exists():
            py_libpath = next(filter(lambda p: p.exists(), iter_libpython_paths()), None)
            if py_libpath is None:
                # TODO: only debian like?
                message = (
                    "[error] missing libpython."
                    "Please install python3-dev or python3-devel"
                )
                raise NotImplementedError(message)

            venv_libpath.symlink_to(py_libpath)


def main():
    check_dynamic_linked()
    check_lib_python()

    envs = os.environ.copy()
    envs['PYTHONNOUSERSITE'] = '1'  # TODO: remove?
    envs['PYTHONPATH'] = ':'.join(sys.path)
    envs['PYTHONHOME'] = ':'.join([sys.prefix, sys.exec_prefix])

    # todo: ld-path? /proc/self/exe? /proc/self/maps?
    os.execve(str(gdb_path), sys.argv, env=envs)


if __name__ == '__main__':
    main()
