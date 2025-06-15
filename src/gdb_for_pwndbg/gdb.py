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


def check_lib_python():
    in_venv = sys.base_exec_prefix != sys.exec_prefix
    # is_user_site = self.lib_dir.startswith(site.USER_SITE)

    # # Find libpython library names and locations
    # shared_library_path = LIBDIR
    # all_ld_library_names = list(set(n for n in (sysconfig.get_config_var("LDLIBRARY"),
    #                                             sysconfig.get_config_var("INSTSONAME")) if n))
    if in_venv:
        pass

    # libpython_name = pathlib.Path(get_config_var("INSTSONAME"))
    # libpython_dir = pathlib.Path(get_config_var("LIBDIR"))
    # if (libpython_dir / libpython_name).exists():
    #     return True
    #
    # for path in get_ld_paths():
    #     if (pathlib.Path(path) / libpython_name).exists():
    #         return True
    #
    # # TODO: only debian like?
    # raise NotImplementedError(f'[error] missing libpython. Please install python3-dev or python3-devel')


def main():
    check_dynamic_linked()
    check_lib_python()

    envs = os.environ.copy()
    envs['PYTHONNOUSERSITE'] = '1'  # TODO: remove?
    envs['PYTHONPATH'] = ':'.join(sys.path)
    envs['PYTHONHOME'] = ':'.join([sys.prefix, sys.exec_prefix])

    os.execve(str(gdb_path), sys.argv, env=envs)


if __name__ == '__main__':
    main()
