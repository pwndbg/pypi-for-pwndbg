{
  lldb_drv,
  lib,
  runCommand,
  stdenv,
  nukeReferences,
  patchelf,
  python3,
  python3Packages,
  bintools,
  darwin,
  llvm,
}:
let
  targetPrefix = lib.optionalString (
    stdenv.buildPlatform != stdenv.targetPlatform
  ) "${stdenv.targetPlatform.config}-";
  lldbMajorMinorVersionArr = lib.versions.splitVersion lldb_drv.version;
  lldbPatchSuffix =
    if (builtins.length lldbMajorMinorVersionArr) >= 4 then
      (builtins.elemAt lldbMajorMinorVersionArr 3)
    else
      "";
  lldbMajorMinorVersion = "${builtins.elemAt lldbMajorMinorVersionArr 0}.${builtins.elemAt lldbMajorMinorVersionArr 1}${lldbPatchSuffix}";

  removeDot = str: builtins.replaceStrings [ "." ] [ "" ] str;
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
          --replace-fail '@version@' "${lldb_drv.pypiVersion}"

        cp ${./MANIFEST.in} MANIFEST.in
        cp -rf ${./src} src
        chmod -R +w ./src/

        PY_VERSION="${removeDot lldb_drv.pythonVersion}"
        LLDB_DIR="${lldb_drv}"
        WHEEL_OUT_NAME=lldb_for_pwndbg-${lldb_drv.pypiVersion}-cp$PY_VERSION-cp$PY_VERSION-${wheelType}

        mkdir -p ./src/lldb_for_pwndbg/_vendor/bin
        mkdir -p ./src/lldb_for_pwndbg/_vendor/lib

        cp $LLDB_DIR/bin/lldb ./src/lldb_for_pwndbg/_vendor/bin/

        cp -rf $LLDB_DIR/lib/python*/site-packages/lldb/ ./src/
        chmod -R +w ./src/

        if [ "$IS_LINUX" -eq 1 ]; then
            cp $LLDB_DIR/bin/lldb-server ./src/lldb_for_pwndbg/_vendor/bin/

            # Fix lib
            lldb_python_so=$(basename $(ls ./src/lldb/native/_lldb*.so))
            rm ./src/lldb/native/$lldb_python_so
            cp $LLDB_DIR/lib/liblldb.so ./src/lldb/native/$lldb_python_so
            chmod -R +w ./src/

            patchelf --set-rpath '$ORIGIN/../../../../../lib' ./src/lldb/native/$lldb_python_so

            patchelf --set-interpreter ${interpreterPath} ./src/lldb_for_pwndbg/_vendor/bin/lldb
            patchelf --set-rpath '$ORIGIN/../../../lldb/native' ./src/lldb_for_pwndbg/_vendor/bin/lldb
            patchelf --replace-needed liblldb.so.${lldbMajorMinorVersion} $lldb_python_so ./src/lldb_for_pwndbg/_vendor/bin/lldb

            patchelf --set-interpreter ${interpreterPath} ./src/lldb_for_pwndbg/_vendor/bin/lldb-server
            patchelf --remove-rpath ./src/lldb_for_pwndbg/_vendor/bin/lldb-server

            # libpython is only needed for `lldb` not _lldb.so itself
            libpython_name=$(patchelf --print-needed ./src/lldb/native/$lldb_python_so | grep libpython)
            patchelf --add-needed $libpython_name --add-rpath '$ORIGIN/../../../../../../lib' ./src/lldb_for_pwndbg/_vendor/bin/lldb
            patchelf --remove-needed $libpython_name --remove-rpath ./src/lldb/native/$lldb_python_so
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

            # extra patch libcurl.4.dylib
            org_libcurl_path=$(otool -L ./src/lldb/$lldb_python_so | grep libcurl.4.dylib | awk '{print $1}')
            cp $org_libcurl_path ./src/lldb/libcurl.4.dylib

            install_name_tool \
                -id "libcurl.4.dylib" \
                ./src/lldb/libcurl.4.dylib

            install_name_tool \
                -change \
                $org_libcurl_path \
                "@loader_path/libcurl.4.dylib" \
                ./src/lldb/$lldb_python_so
        fi

        # this file is unused
        rm ./src/lldb/lldb-argdumper

        if [ "$BUILD_DEBUG_TARBALL" -eq 1 ]; then
          tar cvfJ $out/$WHEEL_OUT_NAME.debug.tar.xz \
            --owner=0 --group=0 --mode=u+rw,uga+r \
            --mtime='1970-01-01' \
            -C ./src \
            --transform="s|^./|./$WHEEL_OUT_NAME/|" \
            .
        fi

        llvm-strip ./src/lldb_for_pwndbg/_vendor/bin/lldb
        nuke-refs ./src/lldb_for_pwndbg/_vendor/bin/lldb

        if [ "$IS_LINUX" -eq 1 ]; then
            llvm-strip ./src/lldb_for_pwndbg/_vendor/bin/lldb-server
            nuke-refs ./src/lldb_for_pwndbg/_vendor/bin/lldb-server
        fi

        llvm-strip -S ./src/lldb/native/$lldb_python_so
        nuke-refs ./src/lldb/native/$lldb_python_so

        python3 ${./verify.py} ${stdenv.targetPlatform.system} ${lldb_drv.pythonVersion} ./src/lldb_for_pwndbg/_vendor/bin/lldb
        if [ "$IS_LINUX" -eq 1 ]; then
            python3 ${./verify.py} ${stdenv.targetPlatform.system} ${lldb_drv.pythonVersion} ./src/lldb_for_pwndbg/_vendor/bin/lldb-server
        fi
        python3 ${./verify.py} ${stdenv.targetPlatform.system} ${lldb_drv.pythonVersion} ./src/lldb/native/$lldb_python_so

        python3 setup.py bdist_wheel
        mv dist/*.whl $out/$WHEEL_OUT_NAME.whl
      '';
in
final
