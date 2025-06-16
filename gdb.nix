{
  lib,
  stdenv,
  stdenvNoCC,
  targetPackages,
  pkgsStatic,

  # Build time
  fetchurl,
  pkg-config,
  perl,
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
in
stdenvNoCC.mkDerivation (finalAttrs: {
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

  strictDeps = true;

  nativeBuildInputs = [
    pkg-config
    texinfo
    libiconv
    buildPackages.zig_new.cc
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
    pkgsStatic.libiconv

    python3
  ];

  passthru = {
    pythonVersion = python3.pythonVersion;
  };

  #  depsBuildBuild = [ buildPackages.stdenv.cc ];
  #  depsBuildBuild = [ buildPackages.zig.cc ];

  env.NIX_CFLAGS_COMPILE = "-Wno-format-nonliteral";

  configurePlatforms = [
    "build"
    "host"
    "target"
  ];

  preConfigure = ''
    mkdir _build
    cd _build
  '';
  configureScript = "../configure";

  configureFlags = [
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

    "--with-gmp=${pkgsStatic.gmp.dev}"
    "--with-mpfr=${pkgsStatic.mpfr.dev}"
    "--with-expat"
    "--with-libexpat-prefix=${pkgsStatic.expat.dev}"
    "--with-auto-load-safe-path=${builtins.concatStringsSep ":" safePaths}"

    "--disable-sim"
    "--disable-gdbserver"
    "--with-python=${python3.pythonOnBuildForHost.interpreter}"

    #    "--target=x86_64-apple-darwin"
  ];

  # TODO:
  # fix: --with-separate-debug-dir=/nix/store/cgal8dan40165178zjzgfyahzd5hm596-gdb-16.2/lib/debug
  # fix: --with-python=/nix/store/g61j9ws03l841jyb2wxin8ab0dqh5viv-python3-3.14.0a6
  # fix: --with-python-libdir=/nix/store/g61j9ws03l841jyb2wxin8ab0dqh5viv-python3-3.14.0a6/lib

  # TODO: to powinno byc lib/python3.12/site-packages/gdb/
  # TODO: __init__.py powinno zwraca komunikat jakis lepszy jak _gdb import sie wywali
  # fix: --with-gdb-datadir=/nix/store/cgal8dan40165178zjzgfyahzd5hm596-gdb-16.2/share/gdb
  # fix: --with-jit-reader-dir=/nix/store/cgal8dan40165178zjzgfyahzd5hm596-gdb-16.2/lib/gdb

  enableParallelBuilding = true;

  dontStrip = true;
  doCheck = false;
})
