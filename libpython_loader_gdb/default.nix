{
  stdenv,
  portableStdenv,
  patchelf,
  darwin,
  lib,
}:
# Linux: zig + glibc 2.28 (portable across old distros), macOS: normal stdenv
portableStdenv.mkDerivation {
  pname = "libpython_loader_gdb";
  version = "1";

  src = ./libpython_loader.c;

  # Single C file, no configure/make needed
  dontUnpack = true;

  nativeBuildInputs =
    lib.optionals stdenv.hostPlatform.isLinux [ patchelf ]
    ++ lib.optionals stdenv.hostPlatform.isDarwin [ darwin.cctools ];

  buildPhase =
    if stdenv.targetPlatform.isLinux then
      ''
        $CC -shared -fPIC -o libpython_loader_gdb.so $src -ldl \
            -Wl,--soname=libpython_loader_gdb.so \
            -Wl,--no-undefined
      ''
    else
      ''
        $CC -shared -o libpython_loader_gdb.dylib $src \
            -install_name libpython_loader_gdb.dylib
      '';

  installPhase = ''
    mkdir -p $out/lib
    ${
      if stdenv.targetPlatform.isLinux then
        ''
          patchelf --remove-rpath libpython_loader_gdb.so
          cp libpython_loader_gdb.so $out/lib/
        ''
      else
        ''
          cp libpython_loader_gdb.dylib $out/lib/
        ''
    }
  '';

  dontStrip = false;
  dontFixup = true;
}
