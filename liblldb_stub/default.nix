{
  stdenv,
  buildPackages,
  patchelf,
  darwin,
  lib,
  llvmVersion ? "XX.X",
}:
let
  # Mirror the same stdenv override as lldb.nix:
  # Linux  → zig glibc 2.28 (for portability across old distros)
  # macOS  → normal stdenv
  stdenvOver = if stdenv.targetPlatform.isLinux then buildPackages.zig_glibc_2_28.stdenv else stdenv;
in
stdenvOver.mkDerivation {
  pname = "liblldb_stub";
  version = llvmVersion;

  src = ./stub.c;

  # Single C file, no configure/make needed
  dontUnpack = true;

  nativeBuildInputs =
    lib.optionals stdenv.hostPlatform.isLinux [ patchelf ]
    ++ lib.optionals stdenv.hostPlatform.isDarwin [ darwin.cctools ];

  buildPhase =
    if stdenv.targetPlatform.isLinux then
      ''
        cp ${./version.map} ./version.map
        substituteInPlace ./version.map \
          --replace-fail 'LLVM_VERSION' 'LLVM_${llvmVersion}'

        $CC -shared -fPIC -o liblldb_stub.so $src \
            -Wl,--soname=liblldb_stub.so \
            -Wl,--version-script=./version.map \
            -Wl,--no-undefined
      ''
    else
      ''
        cp ${./version.map} ./version.map
        substituteInPlace ./version.map \
          --replace-fail 'LLVM_VERSION' 'LLVM_${llvmVersion}'

        $CC -shared -o liblldb_stub.dylib $src \
            -install_name liblldb_stub.dylib
      '';

  installPhase = ''
    mkdir -p $out/lib
    ${
      if stdenv.targetPlatform.isLinux then
        ''
          patchelf --remove-rpath liblldb_stub.so
          cp liblldb_stub.so $out/lib/
        ''
      else
        ''
          cp liblldb_stub.dylib $out/lib/
        ''
    }
  '';

  dontStrip = false;
  dontFixup = true;
}
