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
    if stdenv.targetPlatform.isLinux && stdenv.targetPlatform.is32bit then
      "-Dtarget=${stdenv.targetPlatform.parsed.cpu.family}-linux-${stdenv.targetPlatform.parsed.abi.name}.2.28"
    else if stdenv.targetPlatform.isLinux then
      "-Dtarget=${stdenv.targetPlatform.parsed.cpu.name}-linux-${stdenv.targetPlatform.parsed.abi.name}.2.28"
    else if stdenv.targetPlatform.isDarwin then
      "-Dtarget=${stdenv.targetPlatform.parsed.cpu.name}-macos.${stdenv.targetPlatform.darwinSdkVersion}"
    else
      (throw "not supported target");

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

  postPatch = ''
    substituteInPlace src/client.zig \
      --replace-fail 'response.head.content_length.?;' '@truncate(response.head.content_length.?);'

    substituteInPlace src/binding.zig \
      --replace-fail 'comptime std.debug.assert(@sizeOf(@TypeOf(section)) == 8);' '//'
  '';

  zigBuildFlags = [
    target
  ];

  nativeBuildInputs = [
    zig.hook
  ];
}
