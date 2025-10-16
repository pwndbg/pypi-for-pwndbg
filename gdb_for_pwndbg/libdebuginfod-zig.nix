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
      rev = "3c1ea47a45c3e9e891b5c00f53373cd51bd69e45";
      hash = "sha256-kXW98KHB3gq9Xeo/VEzZ/zW7tVhcRFXKcPOLf/KIVDI=";
#      hash = lib.fakeHash;
    };

    nativeBuildInputs = [
      zig_0_15.hook
    ];
}