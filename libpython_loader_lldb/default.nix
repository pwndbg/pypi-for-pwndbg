{
  stdenv,
  buildPackages,
  patchelf,
  darwin,
  lib,
}:
let
  # Mirror the same stdenv override as lldb.nix:
  # Linux  → zig glibc 2.28 (for portability across old distros)
  # macOS  → normal stdenv
  stdenvOver = if stdenv.targetPlatform.isLinux then buildPackages.zig_glibc_2_28.stdenv else stdenv;
in
stdenvOver.mkDerivation {
  pname = "libpython_loader_lldb";
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
        $CC -shared -fPIC -o libpython_loader_lldb.so $src -ldl \
            -Wl,--soname=libpython_loader_lldb.so \
            -Wl,--no-undefined
      ''
    else
      ''
        $CC -shared -o libpython_loader_lldb.dylib $src \
            -install_name @rpath/libpython_loader_lldb.dylib
      '';

  installPhase = ''
    mkdir -p $out/lib
    ${
      if stdenv.targetPlatform.isLinux then
        ''
          patchelf --set-rpath '$ORIGIN' libpython_loader_lldb.so
          cp libpython_loader_lldb.so $out/lib/
        ''
      else
        ''
          install_name_tool -add_rpath "@loader_path/" libpython_loader_lldb.dylib
          cp libpython_loader_lldb.dylib $out/lib/
        ''
    }
  '';

  dontStrip = false;
  dontFixup = true;
}
