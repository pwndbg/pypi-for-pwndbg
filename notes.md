

```

https://github.com/karellen/wheel-axle-runtime/blob/master/src/main/python/wheel_axle/runtime/_libpython.py


    enable_shared = sysconfig.get_config_var("PY_ENABLE_SHARED") or sysconfig.get_config_var("Py_ENABLE_SHARED")
    if not enable_shared or not int(enable_shared):
        message = (
            "The distribution {!r} requires dynamic linking to the `libpython` "
            "but current instance of CPython was built without `--enable-shared`."
        )
        raise InstallationError(
            message.format(self.dist_meta.project_name)
        )

    in_venv = sys.base_exec_prefix != sys.exec_prefix
    is_user_site = self.lib_dir.startswith(site.USER_SITE)

    # Find libpython library names and locations
    shared_library_path = LIBDIR
    all_ld_library_names = list(set(n for n in (sysconfig.get_config_var("LDLIBRARY"),
                                                sysconfig.get_config_var("INSTSONAME")) if n))


py_libpath = os.path.join(sys.base_exec_prefix, 'lib')
venv_libpath = os.path.join(sys.exec_prefix, 'lib')

```

todo:
- debuginfod w llvm nie dodaje user-agenta :(
- lldb brakuje source kodu: https://github.com/llvm/llvm-project/pull/141773/changes
