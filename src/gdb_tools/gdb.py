import sys
import os
import subprocess
import pathlib
from sysconfig import get_config_var
try:
    import ctypes
except ImportError:
    raise NotImplementedError('[error] python is static compiled')


here = pathlib.Path(__file__).parent.resolve()
gdb_path = here / pathlib.Path('_vendor/exe/gdb')


def main():
    libpython_path = get_config_var("LIBDIR") + "/" + get_config_var("INSTSONAME")
    libpython_dir = get_config_var("LIBDIR")
    if not os.path.exists(libpython_path):
        raise NotImplementedError(f'[error] missing libpython in {libpython_path}, please install python3-dev or python3-devel')

    envs = os.environ.copy()
    envs['PYTHONPATH'] = ':'.join(sys.path)
    # envs['PYTHONHOME'] = sys.prefix + ':' + sys.exec_prefix # TODO: check pythonhome issues
    envs['PYTHONHOME'] = '/usr' + ':' + '/usr'
    envs['LD_LIBRARY_PATH'] = libpython_dir

    subprocess.run([str(gdb_path)] + sys.argv, env=envs)
