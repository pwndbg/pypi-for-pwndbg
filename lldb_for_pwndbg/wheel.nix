{
  lldb_drv,
  lib,
  runCommand,
  stdenv,
  nukeReferences,
  patchelf,
  python3,
  bintools,
  darwin,
}:
let
  lldbMajorMinorVersionArr = lib.versions.splitVersion lldb_drv.version;
  lldbPatchSuffix = if (builtins.length lldbMajorMinorVersionArr) >= 4 then (builtins.elemAt lldbMajorMinorVersionArr 3) else "";
  lldbMajorMinorVersion = "${builtins.elemAt lldbMajorMinorVersionArr 0}.${builtins.elemAt lldbMajorMinorVersionArr 1}${lldbPatchSuffix}";

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
    substituteInPlace setup.py \
      --replace-fail '@version@' "${lldb_drv.pypiVersion}"

    cp ${./MANIFEST.in} MANIFEST.in
    cp -rf ${./src} src
    chmod -R +w ./src/

    PY_VERSION="${removeDot lldb_drv.pythonVersion}"
    LLDB_DIR="${lldb_drv}"

    mkdir -p ./src/lldb_for_pwndbg/_vendor/bin
    mkdir -p ./src/lldb_for_pwndbg/_vendor/lib

    cp $LLDB_DIR/bin/lldb ./src/lldb_for_pwndbg/_vendor/bin/

    cp -rf $LLDB_DIR/lib/python*/site-packages/lldb/ ./src/
    chmod -R +w ./src/

    if [ "$IS_LINUX" -eq 1 ]; then
        cp $LLDB_DIR/bin/lldb-server ./src/lldb_for_pwndbg/_vendor/bin/

        # Fix lib
        lldb_python_so=$(basename $(ls ./src/lldb/_lldb*.so))
        rm ./src/lldb/$lldb_python_so
        cp $LLDB_DIR/lib/liblldb.so ./src/lldb/$lldb_python_so
        chmod -R +w ./src/

        patchelf --set-rpath '$ORIGIN/../../../../lib' ./src/lldb/$lldb_python_so

        patchelf --set-interpreter ${interpreterPath} ./src/lldb_for_pwndbg/_vendor/bin/lldb
        patchelf --set-rpath '$ORIGIN/../../../lldb' ./src/lldb_for_pwndbg/_vendor/bin/lldb
        patchelf --replace-needed liblldb.so.${lldbMajorMinorVersion} $lldb_python_so ./src/lldb_for_pwndbg/_vendor/bin/lldb

        patchelf --set-interpreter ${interpreterPath} ./src/lldb_for_pwndbg/_vendor/bin/lldb-server
        patchelf --remove-rpath ./src/lldb_for_pwndbg/_vendor/bin/lldb-server
    else
        # Fix lib
        lldb_python_so=$(basename $(ls ./src/lldb/_lldb*.so))
        rm ./src/lldb/$lldb_python_so
        cp $LLDB_DIR/lib/liblldb.dylib ./src/lldb/$lldb_python_so
        ls -al ./src/
        chmod -R +w ./src/

        install_name_tool \
            -change \
            ${lldb_drv.python}/lib/libpython${lldb_drv.pythonVersion}.dylib \
            '@loader_path/../../../../lib/libpython${lldb_drv.pythonVersion}.dylib' \
            ./src/lldb/$lldb_python_so

        install_name_tool \
            -id $lldb_python_so \
            ./src/lldb/$lldb_python_so

        install_name_tool \
            -change \
            '@rpath/liblldb.${lldb_drv.version}.dylib' \
            "@executable_path/../../../lldb/$lldb_python_so" \
            ./src/lldb_for_pwndbg/_vendor/bin/lldb
    fi

    strip ./src/lldb_for_pwndbg/_vendor/bin/lldb
    nuke-refs ./src/lldb_for_pwndbg/_vendor/bin/lldb

    if [ "$IS_LINUX" -eq 1 ]; then
        strip ./src/lldb_for_pwndbg/_vendor/bin/lldb-server
        nuke-refs ./src/lldb_for_pwndbg/_vendor/bin/lldb-server
    fi

    strip -S ./src/lldb/$lldb_python_so
    nuke-refs ./src/lldb/$lldb_python_so

    # this file is unused
    rm ./src/lldb/lldb-argdumper

    python3 ${./verify.py} ${stdenv.targetPlatform.system} ${lldb_drv.pythonVersion} ./src/lldb_for_pwndbg/_vendor/bin/lldb
    if [ "$IS_LINUX" -eq 1 ]; then
        python3 ${./verify.py} ${stdenv.targetPlatform.system} ${lldb_drv.pythonVersion} ./src/lldb_for_pwndbg/_vendor/bin/lldb-server
    fi
    python3 ${./verify.py} ${stdenv.targetPlatform.system} ${lldb_drv.pythonVersion} ./src/lldb/$lldb_python_so

    python3 setup.py bdist_wheel
    mkdir $out
    mv dist/*.whl $out/lldb_for_pwndbg-${lldb_drv.pypiVersion}-cp$PY_VERSION-cp$PY_VERSION-${wheelType}.whl
  ''
