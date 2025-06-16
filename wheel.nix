{
  gdb_drv,
  runCommand,
  stdenv,
  nukeReferences,
  patchelf,
  python3,
  bintools,
}:
let
  removeDot = str: builtins.replaceStrings [ "." ] [ "" ] str;
  interpreterPath =
    {
      "x86_64-linux" = "/lib64/ld-linux-x86_64.so.2";
      "aarch64-linux" = "/lib/ld-linux-aarch64.so.1";
    }
    .${stdenv.targetPlatform.system};
  wheelType =
    {
      "x86_64-linux" = "manylinux_2_28_x86_64";
      "aarch64-linux" = "manylinux_2_28_aarch64";
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
    nativeBuildInputs = [
      patchelf
      nukeReferences
      bintools
      (python3.withPackages (ps: [
        ps.setuptools
        ps.wheel
      ]))
    ];
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
    chmod -R +w ./src/gdb_for_pwndbg/_vendor

    patchelf --set-interpreter ${interpreterPath} ./src/gdb_for_pwndbg/_vendor/bin/gdb
    patchelf --set-rpath '$ORIGIN/../../../../../../lib' ./src/gdb_for_pwndbg/_vendor/bin/gdb
    strip ./src/gdb_for_pwndbg/_vendor/bin/gdb
    nuke-refs ./src/gdb_for_pwndbg/_vendor/bin/gdb

    cp -rf $GDB_DIR/share/gdb/python/gdb/ ./src/

    python3 setup.py bdist_wheel
    mkdir $out
    mv dist/*.whl $out/gdb_for_pwndbg-${wheelVersion}-cp$PY_VERSION-cp$PY_VERSION-${wheelType}.whl
  ''
