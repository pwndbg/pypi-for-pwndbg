{
  description = "gdb for pwndbg";

  nixConfig = {
    #    extra-substituters = [
    #      "https://pwndbg.cachix.org"
    #    ];
    #    extra-trusted-public-keys = [
    #      "pwndbg.cachix.org-1:HhtIpP7j73SnuzLgobqqa8LVTng5Qi36sQtNt79cD3k="
    #    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      ...
    }:
    let
      forAllSystems = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed;
      lib = nixpkgs.lib;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [
              (final: prev: {
                zig_new = (prev.callPackage ./zig { })."0.13";
              })
            ];
          };
          pythonVersions = [
            "310"
            "311"
            "312"
            "313"
            "314"
          ];
        in
        {
          gdb = (
            lib.genAttrs pythonVersions (
              v:
              pkgs.callPackage ./gdb.nix {
                python3 = pkgs."python${v}";
              }
            )
          );
          wheel = (
            lib.genAttrs pythonVersions (
              v:
              pkgs.callPackage ./wheel.nix {
                gdb_drv = self.packages.${system}.gdb.${v};
              }
            )
          );
        }
      );
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);
    };
}
