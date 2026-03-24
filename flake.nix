{
  description = "Boltz Client binaries for CLN & LND";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {
    self,
    nixpkgs,
    treefmt-nix,
  }: let
    supportedSystems = ["x86_64-linux" "aarch64-linux"];
    pkgsBySystem = nixpkgs.lib.getAttrs supportedSystems nixpkgs.legacyPackages;
    forAllPkgs = fn: nixpkgs.lib.mapAttrs (system: pkgs: (fn system pkgs)) pkgsBySystem;

    treefmtEval = forAllPkgs (system: pkgs:
      treefmt-nix.lib.evalModule pkgs {
        projectRootFile = "flake.nix";
        programs.alejandra.enable = true;
      });
  in {
    formatter = forAllPkgs (system: pkgs: treefmtEval.${system}.config.build.wrapper);

    checks = forAllPkgs (system: pkgs: {
      formatting = treefmtEval.${system}.config.build.check self;
    });

    overlays.default = final: prev: {
      boltz-client = final.callPackage ./pkgs/boltz-client.nix {};
    };

    packages = forAllPkgs (system: pkgs: {
      default = pkgs.callPackage ./pkgs/boltz-client.nix {};
      boltz-client = pkgs.callPackage ./pkgs/boltz-client.nix {};
    });

    devShells = forAllPkgs (system: pkgs: {
      default = pkgs.mkShell {
        packages = [
          pkgs.nix-update
          treefmtEval.${system}.config.build.wrapper
        ];
      };
    });

    nixosModules.default = import ./nixos/module.nix self;
  };
}
