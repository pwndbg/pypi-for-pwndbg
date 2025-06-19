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

    PY_VERSION="${removeDot lldb_drv.pythonVersion}"
    LLDB_DIR="${lldb_drv}"

    mkdir -p ./src/lldb_for_pwndbg/_vendor/bin
    mkdir -p ./src/lldb_for_pwndbg/_vendor/lib

    cp $LLDB_DIR/bin/lldb ./src/lldb_for_pwndbg/_vendor/bin/
    cp $LLDB_DIR/bin/lldb-server ./src/lldb_for_pwndbg/_vendor/bin/

    cp -a $LLDB_DIR/lib/liblldb.* ./src/lldb_for_pwndbg/_vendor/lib/
    cp -rf $LLDB_DIR/lib/python*/site-packages/lldb/ ./src/
    chmod -R +w ./src/

    if [ "$IS_LINUX" -eq 1 ]; then
        # ld-$ORIGIN is not working good with symlinks
        patchelf --set-rpath '$ORIGIN/../../../../lib:$ORIGIN/../../../../../../lib' ./src/lldb_for_pwndbg/_vendor/lib/liblldb.so

        patchelf --set-interpreter ${interpreterPath} ./src/lldb_for_pwndbg/_vendor/bin/lldb
        patchelf --set-rpath '$ORIGIN/../lib' ./src/lldb_for_pwndbg/_vendor/bin/lldb

        patchelf --set-interpreter ${interpreterPath} ./src/lldb_for_pwndbg/_vendor/bin/lldb-server
        patchelf --remove-rpath ./src/lldb_for_pwndbg/_vendor/bin/lldb-server
    fi

    strip ./src/lldb_for_pwndbg/_vendor/bin/lldb
    nuke-refs ./src/lldb_for_pwndbg/_vendor/bin/lldb

    strip ./src/lldb_for_pwndbg/_vendor/bin/lldb-server
    nuke-refs ./src/lldb_for_pwndbg/_vendor/bin/lldb-server

    strip ./src/lldb_for_pwndbg/_vendor/lib/liblldb.so
    nuke-refs ./src/lldb_for_pwndbg/_vendor/lib/liblldb.so

    # this file is unused
    rm ./src/lldb/lldb-argdumper

    # fix symlink to _vendor
    lldb_target_so=$(ls ./src/lldb/_lldb*.so)
    rm $lldb_target_so
    ln -s '../lldb_for_pwndbg/_vendor/lib/liblldb.so' $lldb_target_so

    python3 setup.py bdist_wheel
    mkdir $out
    mv dist/*.whl $out/lldb_for_pwndbg-${wheelVersion}-cp$PY_VERSION-cp$PY_VERSION-${wheelType}.whl
  ''
