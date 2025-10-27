{
  lib,
  stdenv,
  fetchFromGitHub,
  zig_0_15,
}:
let
  zig =
    if stdenv.hostPlatform.system == "x86_64-darwin" then
      (zig_0_15.overrideAttrs (old: {
        meta = old.meta // {
          broken = false;
        };
        doCheck = false;
        doInstallCheck = false;
      }))
    else
      zig_0_15;

  target =
    if stdenv.hostPlatform.isLinux then
      "-Dtarget=native-linux-gnu.2.28"
    else
      "-Dtarget=native-macos.${stdenv.hostPlatform.darwinSdkVersion}";
in
stdenv.mkDerivation {
  name = "libdebuginfod-zig";
  version = "0.194";

  src = fetchFromGitHub {
    owner = "pwndbg";
    repo = "debuginfod-zig";
    rev = "d5fbc578562fdad5a92e0c3d4e06c34756a226e5";
    hash = "sha256-PyUCkqyX0vMEHOBtf1SIdarQgdKWl4WSUO6gmXB4r3U=";
#              hash = lib.fakeHash;
  };

  zigBuildFlags = [
    target
  ];

  nativeBuildInputs = [
    zig.hook
  ];
}
