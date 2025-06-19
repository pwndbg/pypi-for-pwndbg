# Copied from: https://github.com/NixOS/nixpkgs/pull/377225
{
  cmake,
  lib,
  monorepoSrc ? null,
  ninja,
  python3,
  stdenv,
  version,
}:

let
  pname = "llvm-tblgen";

  self = stdenv.mkDerivation (finalAttrs: rec {
    inherit pname version;

    src = monorepoSrc;
    sourceRoot = "${finalAttrs.src.name}/llvm";
    enableParallelBuilding = true;

    nativeBuildInputs = [
      cmake
      ninja
      python3
    ];

    cmakeFlags =
      [
        # Projects with tablegen-like tools.
        "-DLLVM_ENABLE_PROJECTS=${
          lib.concatStringsSep ";" ([
            "llvm"
            "clang"
            "clang-tools-extra"
            "lldb"
          ])
        }"
      ]
      # LLDB test suite requires libc++ on darwin, but we need compile only lldb-tblgen
      # These flags are needed only for evaluating the CMake file.
      ++ lib.optionals stdenv.hostPlatform.isDarwin [
        "-DLLDB_INCLUDE_TESTS=OFF"
        "-DLIBXML2_INCLUDE_DIR=/non-existent"
      ];

    ninjaFlags = [
      "clang-tblgen"
      "llvm-tblgen"
      "lldb-tblgen"
    ];

    installPhase = ''
      mkdir -p $out
      cp -ar bin $out/bin
    '';
  });
in
self
