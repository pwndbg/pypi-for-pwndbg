{
  gdb_drv,
  lib,
  runCommand,
  stdenv,
  nukeReferences,
  patchelf,
  python3,
  bintools,
  libxcrypt,
  darwin,
}:
let
  removeDot = str: builtins.replaceStrings [ "." ] [ "" ] str;
  interpreterPath =
    {
      "x86_64-linux" = "/lib64/ld-linux-x86-64.so.2";
      "aarch64-linux" = "/lib/ld-linux-aarch64.so.1";

      "x86_64-darwin" = "";
      "aarch64-darwin" = "";
    }
    .${stdenv.targetPlatform.system};
  wheelType =
    {
      "x86_64-linux" = "manylinux_2_28_x86_64";
      "aarch64-linux" = "manylinux_2_28_aarch64";

      "x86_64-darwin" = "macosx_10_13_x86_64";
      "aarch64-darwin" = "macosx_11_0_arm64";
    }
    .${stdenv.targetPlatform.system};

  wheelVersion =
    let
      versionFile = builtins.readFile ./setup.py;
      versionMatch = builtins.match ".*\n[\t ]*version=\"([0-9]+.[0-9]+.[0-9]+)\".*" versionFile;
      version = if versionMatch == null then "unknown" else (builtins.elemAt versionMatch 0);
    in
    version;
in
runCommand "build-wheel"
  {
    nativeBuildInputs =
      [
        nukeReferences
        (python3.withPackages (ps: [
          ps.setuptools
          ps.wheel
        ]))
      ]
      ++ lib.optionals stdenv.hostPlatform.isLinux [
        bintools
        patchelf
      ]
      ++ lib.optionals stdenv.hostPlatform.isDarwin [
        darwin.cctools
        darwin.binutils
      ];
    env.IS_LINUX = if stdenv.hostPlatform.isLinux then "1" else "0";
  }
  ''
    set -ex
    mkdir build
    cd build
    cp ${./setup.py} setup.py
    cp ${./MANIFEST.in} MANIFEST.in
    cp -rf ${./src} src
    chmod -R +w ./src/

    PY_VERSION="${removeDot gdb_drv.pythonVersion}"
    GDB_DIR="${gdb_drv}"

    mkdir -p ./src/gdb_for_pwndbg/_vendor/bin
    mkdir -p ./src/gdb_for_pwndbg/_vendor/share

    cp $GDB_DIR/bin/gdb ./src/gdb_for_pwndbg/_vendor/bin/
    cp -rf $GDB_DIR/share/gdb/python/gdb/ ./src/

    mkdir -p ./src/gdb_for_pwndbg/_vendor/share/gdb/
    cp -rf $GDB_DIR/share/gdb/syscalls/ ./src/gdb_for_pwndbg/_vendor/share/gdb/
    chmod -R +w ./src/

    if [ "$IS_LINUX" -eq 1 ]; then
        cp $GDB_DIR/bin/gdbserver ./src/gdb_for_pwndbg/_vendor/bin/
        chmod -R +w ./src/

        patchelf --set-interpreter ${interpreterPath} ./src/gdb_for_pwndbg/_vendor/bin/gdbserver
        patchelf --set-interpreter ${interpreterPath} ./src/gdb_for_pwndbg/_vendor/bin/gdb

        patchelf --set-rpath '$ORIGIN/../../../../../../lib' ./src/gdb_for_pwndbg/_vendor/bin/gdb

        if [ "$PY_VERSION" -eq "310" ]; then
            # libcrypt is not needed for `gdb`, only libpython still is depending on it
            patchelf --remove-needed 'libcrypt.so.2' ./src/gdb_for_pwndbg/_vendor/bin/gdb
        fi
    else
        install_name_tool \
            -change \
            ${gdb_drv.python}/lib/libpython${gdb_drv.pythonVersion}.dylib \
            '@executable_path/../../../../../../lib/libpython${gdb_drv.pythonVersion}.dylib' \
            ./src/gdb_for_pwndbg/_vendor/bin/gdb

        if [ "$PY_VERSION" -eq "310" ]; then
            mkdir -p ./src/gdb_for_pwndbg/_vendor/lib
            cp ${libxcrypt}/lib/libcrypt.2.dylib ./src/gdb_for_pwndbg/_vendor/lib/

            install_name_tool \
                -change \
                ${libxcrypt}/lib/libcrypt.2.dylib \
                '@executable_path/../lib/libcrypt.2.dylib' \
                ./src/gdb_for_pwndbg/_vendor/bin/gdb
        fi
    fi

    strip ./src/gdb_for_pwndbg/_vendor/bin/gdb
    nuke-refs ./src/gdb_for_pwndbg/_vendor/bin/gdb

    if [ "$IS_LINUX" -eq 1 ]; then
        strip ./src/gdb_for_pwndbg/_vendor/bin/gdbserver
        nuke-refs ./src/gdb_for_pwndbg/_vendor/bin/gdbserver
    fi

    python3 ${./verify.py} ${stdenv.targetPlatform.system} ${gdb_drv.pythonVersion} ./src/gdb_for_pwndbg/_vendor/bin/gdb
    if [ "$IS_LINUX" -eq 1 ]; then
        python3 ${./verify.py} ${stdenv.targetPlatform.system} ${gdb_drv.pythonVersion} ./src/gdb_for_pwndbg/_vendor/bin/gdbserver
    fi

    python3 setup.py bdist_wheel
    mkdir $out
    mv dist/*.whl $out/gdb_for_pwndbg-${wheelVersion}-cp$PY_VERSION-cp$PY_VERSION-${wheelType}.whl
  ''
