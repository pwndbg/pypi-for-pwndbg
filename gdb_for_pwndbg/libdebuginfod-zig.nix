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
  version = "0.188";

  src = fetchFromGitHub {
    owner = "pwndbg";
    repo = "debuginfod-zig";
    rev = "df8ec9fd01cc9d61b8ffb290115ff7c14253059d";
    hash = "sha256-+ncYCnnZypC6P4GaGYhU6PUcIYaK/kxwq0YlYa0T3G0=";
    #          hash = lib.fakeHash;
  };

  zigBuildFlags = [
    target
  ];

  nativeBuildInputs = [
    zig.hook
  ];
}
