{
  version,
  pypiVersion,
  src,

  lib,
  stdenv,
  stdenvNoCC,
  targetPackages,
  pkgsStatic,
  pkgsBuildHost,

  # Build time
  fetchurl,
  pkg-config,
  texinfo,
  buildPackages,

  breakpointHook,
  python3,
  libcxx,

  safePaths ? [
    # $debugdir:$datadir/auto-load are whitelisted by default by GDB
    "$debugdir"
    "$datadir/auto-load"
  ],
  writeScript,
}:
let
  # Dynamic libiconv causes issues with our portable build.
  # It reads /some-path/lib/gconv/gconv-modules.d/gconv-modules-extra.conf,
  # then loads /some-path/lib/gconv/UTF-32.so dynamically.
  libiconv = pkgsStatic.libiconvReal;

  libdebuginfod = pkgsBuildHost.callPackage ./libdebuginfod-zig.nix {};

  # For macos we use normal llvm compiler
  # For linux we need zig + forced glibc==2.28
  stdenvOver = if stdenv.hostPlatform.isLinux then buildPackages.zig_glibc_2_28.stdenv else stdenv;
in
stdenvOver.mkDerivation (finalAttrs: {
  pname = "gdb";
  inherit version src;

  patches = [
    ./patches/gdb-fix-cross-python.patch
    ./patches/enable-silent.patch
    ./patches/darwin-target-match.patch
    ./patches/enable-debuginfod.patch
  ];

  postPatch = lib.optionalString stdenv.hostPlatform.isDarwin ''
    substituteInPlace gdb/darwin-nat.c \
      --replace-fail '#include "bfd/mach-o.h"' '#include "mach-o.h"'
  '';

  strictDeps = true;

  nativeBuildInputs =
    [
      pkg-config
      texinfo
    ]
    ++ lib.optionals stdenv.hostPlatform.isDarwin [
    ];

  buildInputs = [
    pkgsStatic.ncurses
    pkgsStatic.gmp
    pkgsStatic.mpfr
    pkgsStatic.expat
    pkgsStatic.libipt
    pkgsStatic.zlib
    pkgsStatic.zstd
    pkgsStatic.xz
    pkgsStatic.sourceHighlight
    libdebuginfod

    python3
  ];

  passthru = {
    pythonVersion = python3.pythonVersion;
    python = python3;
    pypiVersion = pypiVersion;
  };

  env.NIX_CFLAGS_COMPILE = builtins.concatStringsSep " " (
    [
      "-Wno-format-nonliteral"
    ]
    ++ lib.optionals stdenv.hostPlatform.isDarwin [
    ]
  );

  env.CPPFLAGS = builtins.concatStringsSep " " ([
    "-I${libiconv}/include"
  ]);

  env.LDFLAGS = builtins.concatStringsSep " " (
    [
      "-L${libiconv}/lib"
    ]
    ++ lib.optionals stdenv.hostPlatform.isDarwin [
      # Force static linking libc++ on Darwin, see: https://github.com/llvm/llvm-project/issues/76945#issuecomment-2002557889
      "-nostdlib++"
      "-Wl,${libcxx}/lib/libc++.a,${libcxx}/lib/libc++abi.a"
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
      "--disable-inprocess-agent"
      "--with-python=${python3.pythonOnBuildForHost.interpreter}"
      "--with-debuginfod=yes"
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
  dontFixup = true;
})
