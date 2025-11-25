{
  gdb_drv,
  lib,
  runCommand,
  stdenv,
  nukeReferences,
  patchelf,
  python3,
  python3Packages,
  bintools,
  libxcrypt,
  darwin,
  llvm,
}:
let
  removeDot = str: builtins.replaceStrings [ "." ] [ "" ] str;
  targetPrefix = lib.optionalString (
    stdenv.buildPlatform != stdenv.targetPlatform
  ) "${stdenv.targetPlatform.config}-";
  interpreterPath =
    {
      "x86_64-linux" = "/lib64/ld-linux-x86-64.so.2";
      "aarch64-linux" = "/lib/ld-linux-aarch64.so.1";

      "loongarch64-linux" = "/lib64/ld-linux-loongarch-lp64d.so.1";
      "s390x-linux" = "/lib/ld64.so.1";
      "riscv64-linux" = "/lib/ld-linux-riscv64-lp64d.so.1";
      "powerpc64le-linux" = "/lib64/ld64.so.2";
      "armv7l-linux" = "/lib/ld-linux-armhf.so.3";
      "i686-linux" = "/lib/ld-linux.so.2";

      "x86_64-darwin" = "";
      "aarch64-darwin" = "";
    }
    .${stdenv.targetPlatform.system};
  wheelType =
    {
      "x86_64-linux" = "manylinux_2_28_x86_64";
      "aarch64-linux" = "manylinux_2_28_aarch64";

      "loongarch64-linux" = "manylinux_2_36_loongarch64";
      "s390x-linux" = "manylinux_2_28_s390x";
      "riscv64-linux" = "manylinux_2_39_riscv64";
      "powerpc64le-linux" = "manylinux_2_28_ppc64le";
      "armv7l-linux" = "manylinux_2_31_armv7l";
      "i686-linux" = "manylinux_2_28_i686";

      "x86_64-darwin" = "macosx_10_13_x86_64";
      "aarch64-darwin" = "macosx_11_0_arm64";
    }
    .${stdenv.targetPlatform.system};

  final =
    runCommand "build-wheel"
      {
        nativeBuildInputs = [
          nukeReferences
          llvm
          python3
          python3Packages.setuptools
          python3Packages.wheel
        ]
        ++ lib.optionals stdenv.hostPlatform.isLinux [
          patchelf
        ]
        ++ lib.optionals stdenv.hostPlatform.isDarwin [
          darwin.cctools
        ];
        env.IS_LINUX = if stdenv.hostPlatform.isLinux then "1" else "0";
        env.BUILD_DEBUG_TARBALL = "0";

        passthru = {
          debug = final.overrideAttrs (old: {
            env = old.env // {
              BUILD_DEBUG_TARBALL = "1";
            };
          });
        };
      }
      ''
        set -ex
        mkdir $out
        mkdir build

        cd build
        cp ${./setup.py} setup.py
        substituteInPlace setup.py \
          --replace-fail '@version@' "${gdb_drv.pypiVersion}"

        cp ${./MANIFEST.in} MANIFEST.in
        cp -rf ${./src} src
        chmod -R +w ./src/

        PY_VERSION="${removeDot gdb_drv.pythonVersion}"
        GDB_DIR="${gdb_drv}"
        WHEEL_OUT_NAME=gdb_for_pwndbg-${gdb_drv.pypiVersion}-cp$PY_VERSION-cp$PY_VERSION-${wheelType}

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
        else
            install_name_tool \
                -change \
                ${gdb_drv.python}/lib/libpython${gdb_drv.pythonVersion}.dylib \
                '@executable_path/../../../../../../lib/libpython${gdb_drv.pythonVersion}.dylib' \
                ./src/gdb_for_pwndbg/_vendor/bin/gdb
        fi

        if [ "$BUILD_DEBUG_TARBALL" -eq 1 ]; then
          tar cvfJ $out/$WHEEL_OUT_NAME.debug.tar.xz \
            --owner=0 --group=0 --mode=u+rw,uga+r \
            --mtime='1970-01-01' \
            -C ./src \
            --transform="s|^./|./$WHEEL_OUT_NAME/|" \
            .
        fi

        llvm-strip ./src/gdb_for_pwndbg/_vendor/bin/gdb
        nuke-refs ./src/gdb_for_pwndbg/_vendor/bin/gdb

        if [ "$IS_LINUX" -eq 1 ]; then
            llvm-strip ./src/gdb_for_pwndbg/_vendor/bin/gdbserver
            nuke-refs ./src/gdb_for_pwndbg/_vendor/bin/gdbserver
        fi

        python3 ${./verify.py} ${stdenv.targetPlatform.system} ${gdb_drv.pythonVersion} ./src/gdb_for_pwndbg/_vendor/bin/gdb
        if [ "$IS_LINUX" -eq 1 ]; then
            python3 ${./verify.py} ${stdenv.targetPlatform.system} ${gdb_drv.pythonVersion} ./src/gdb_for_pwndbg/_vendor/bin/gdbserver
        fi

        python3 setup.py bdist_wheel
        mv dist/*.whl $out/$WHEEL_OUT_NAME.whl
      '';
in
final
