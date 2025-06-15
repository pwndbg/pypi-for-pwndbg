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
        in
        {
          gdb_310 = pkgs.callPackage ./gdb.nix {
            python3 = pkgs.python310;
          };
          gdb_311 = pkgs.callPackage ./gdb.nix {
            python3 = pkgs.python311;
          };
          gdb_312 = pkgs.callPackage ./gdb.nix {
            python3 = pkgs.python312;
          };
          gdb_313 = pkgs.callPackage ./gdb.nix {
            python3 = pkgs.python313;
          };
          gdb_314 = pkgs.callPackage ./gdb.nix {
            python3 = pkgs.python314;
          };
        }
      );
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);
    };
}
