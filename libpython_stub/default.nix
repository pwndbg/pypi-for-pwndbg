{
  stdenv,
  portableStdenv,
  patchelf,
  darwin,
  lib,
}:
# Linux: zig + glibc 2.28 (portable across old distros), macOS: normal stdenv
portableStdenv.mkDerivation {
  pname = "libpython_stub";
  version = "1";

  src = ./stub.c;

  # Single C file, no configure/make needed
  dontUnpack = true;

  nativeBuildInputs =
    lib.optionals stdenv.hostPlatform.isLinux [ patchelf ]
    ++ lib.optionals stdenv.hostPlatform.isDarwin [ darwin.cctools ];

  buildPhase =
    if stdenv.targetPlatform.isLinux then
      ''
        $CC -shared -fPIC -o libpython_stub.so $src \
            -Wl,--soname=libpython_stub.so \
            -Wl,--no-undefined
      ''
    else
      ''
        $CC -shared -o libpython_stub.dylib $src \
            -install_name libpython_stub.dylib
      '';

  installPhase = ''
    mkdir -p $out/lib
    ${
      if stdenv.targetPlatform.isLinux then
        ''
          patchelf --remove-rpath libpython_stub.so
          cp libpython_stub.so $out/lib/
        ''
      else
        ''
          cp libpython_stub.dylib $out/lib/
        ''
    }
  '';

  dontStrip = false;
  dontFixup = true;
}
