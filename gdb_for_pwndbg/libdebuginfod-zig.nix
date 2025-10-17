{
  lib,
  stdenv,
  fetchFromGitHub,
  zig_0_15,
}:
let
    zig = if stdenv.hostPlatform.system == "x86_64-darwin" then (zig_0_15.overrideAttrs (old: {
        meta = old.meta // { broken = false; };
        doCheck = false;
        doInstallCheck = false;
    })) else zig_0_15;
in stdenv.mkDerivation {
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
      zig.hook
    ];
}