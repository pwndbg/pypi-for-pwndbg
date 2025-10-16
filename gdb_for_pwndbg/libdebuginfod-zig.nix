{
  lib,
  stdenv,
  fetchFromGitHub,
  zig_0_15,
}:
stdenv.mkDerivation {
    name = "libdebuginfod-zig";
    version = "0.188";

    src =  fetchFromGitHub {
      owner = "pwndbg";
      repo = "debuginfod-zig";
      rev = "f929387eb889108baa370d83d9ca66a607f1aea7";
      hash = "sha256-hbQQ0EeulmCYvJQwjXu/FE+gaqCq7KM8CgEpFwI2Ac4=";
#      hash = lib.fakeHash;
    };

    nativeBuildInputs = [
      zig_0_15.hook
    ];
}