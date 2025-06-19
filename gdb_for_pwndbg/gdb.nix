{
  lib,
  stdenv,
  stdenvNoCC,
  targetPackages,
  pkgsStatic,

  # Build time
  fetchurl,
  pkg-config,
  texinfo,
  buildPackages,

  # Run time
  readline,
  libiconv,
  #  ncurses,
  #  gmp,
  #  mpfr,
  #  expat,
  #  libipt,
  #  zlib,
  #  zstd,
  #  xz,
  #  sourceHighlight,

  breakpointHook,
  python3,

  safePaths ? [
    # $debugdir:$datadir/auto-load are whitelisted by default by GDB
    "$debugdir"
    "$datadir/auto-load"
  ],
  writeScript,
}:
let
  x = 1;
  #  readlineStatic = readline.overrideAttrs (old': {
  #    configureFlags = (old'.configureFlags or [ ]) ++ [
  #      "--enable-static"
  #      "--disable-shared"
  #    ];
  #    postInstall = ''
  #      cp -v ./libhistory.a $out/lib/
  #      cp -v ./libreadline.a $out/lib/
  #    '';
  #  });

  # For macos we use normal llvm compiler
  # For linux we need zig + forced glibc==2.28
  stdenvOver = if stdenv.hostPlatform.isLinux then stdenvNoCC else stdenv;
in
stdenvOver.mkDerivation (finalAttrs: {
  pname = "gdb";
  version = "16.2";

  src = fetchurl {
    url = "mirror://gnu/gdb/gdb-${finalAttrs.version}.tar.xz";
    hash = "sha256-QALLfyP0XDfHkFNqE6cglCzkvgQC2SnJCF6S8Q1IARk=";
  };

  patches = [
    ./patches/gdb-fix-cross-python.patch
    ./patches/enable-silent.patch
    ./patches/darwin-target-match.patch
  ];

  postPatch = lib.optionalString stdenv.hostPlatform.isDarwin ''
    substituteInPlace gdb/darwin-nat.c \
      --replace '#include "bfd/mach-o.h"' '#include "mach-o.h"'
  '';

  strictDeps = true;

  nativeBuildInputs =
    [
      pkg-config
      texinfo
      libiconv
    ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [
      buildPackages.zig_glibc_2_28.cc
    ]
    ++ lib.optionals stdenv.hostPlatform.isDarwin [
    ];

  buildInputs =
    [
      pkgsStatic.ncurses
      pkgsStatic.gmp
      pkgsStatic.mpfr
      pkgsStatic.expat
      pkgsStatic.libipt
      pkgsStatic.zlib
      pkgsStatic.zstd
      pkgsStatic.xz
      pkgsStatic.sourceHighlight

      python3
    ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [
      pkgsStatic.libiconv
    ]
    ++ lib.optionals stdenv.hostPlatform.isDarwin [
      # Darwin version of libiconv use too much dlopen, but gnu version not.
      pkgsStatic.libiconvReal
    ];

  passthru = {
    pythonVersion = python3.pythonVersion;
    python = python3;
  };

  env.NIX_CFLAGS_COMPILE = builtins.concatStringsSep " " (
    [
      "-Wno-format-nonliteral"
    ]
    ++ lib.optionals stdenv.hostPlatform.isDarwin [
    ]
  );

  env.LDFLAGS = builtins.concatStringsSep " " (
    lib.optionals stdenv.hostPlatform.isDarwin [
      # Force static linking libc++ on Darwin, see: https://github.com/llvm/llvm-project/issues/76945#issuecomment-2002557889
      "-nostdlib++"
      "-Wl,${stdenv.cc.libcxx}/lib/libc++.a,${stdenv.cc.libcxx}/lib/libc++abi.a"
    ]
  );

  configurePlatforms = lib.optionals (!stdenv.hostPlatform.isDarwin) [
    "build"
    "host"
    "target"
  ];

  preConfigure = ''
    mkdir _build
    cd _build
  '';
  configureScript = "../configure";

  configureFlags =
    [
      "--program-prefix="
      "--disable-werror"

      "--enable-targets=all"
      "--enable-64-bit-bfd"
      "--disable-install-libbfd"
      "--disable-shared"
      "--enable-static"
      "--with-system-zlib"
      "--without-system-readline"

      "--with-system-gdbinit=/etc/gdb/gdbinit"
      "--with-system-gdbinit-dir=/etc/gdb/gdbinit.d"
      "--with-separate-debug-dir=/usr/lib/debug"
      "--with-jit-reader-dir=/usr/lib/gdb"
      "--with-auto-load-safe-path=${builtins.concatStringsSep ":" safePaths}"

      "--with-gmp=${pkgsStatic.gmp.dev}"
      "--with-mpfr=${pkgsStatic.mpfr.dev}"
      "--with-expat"
      "--with-libexpat-prefix=${pkgsStatic.expat.dev}"

      "--disable-sim"
      "--disable-gdbserver"
      "--with-python=${python3.pythonOnBuildForHost.interpreter}"
    ]
    ++ lib.optionals stdenv.hostPlatform.isDarwin [
      "--target=x86_64-apple-darwin"
    ];

  # TODO:
  # fix: --with-python=/nix/store/g61j9ws03l841jyb2wxin8ab0dqh5viv-python3-3.14.0a6
  # fix: --with-python-libdir=/nix/store/g61j9ws03l841jyb2wxin8ab0dqh5viv-python3-3.14.0a6/lib

  # TODO: to powinno byc lib/python3.12/site-packages/gdb/
  # TODO: __init__.py powinno zwraca komunikat jakis lepszy jak _gdb import sie wywali
  # fix: --with-gdb-datadir=/nix/store/cgal8dan40165178zjzgfyahzd5hm596-gdb-16.2/share/gdb

  enableParallelBuilding = true;

  dontStrip = true;
  doCheck = false;
})
