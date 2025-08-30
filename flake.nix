{
  description = "A nix flake for boltz-client.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
    ...
  }: let
    supportedSystems = ["x86_64-linux" "aarch64-linux"];
    pkgsBySystem = nixpkgs.lib.getAttrs supportedSystems nixpkgs.legacyPackages;
    forAllPkgs = fn: nixpkgs.lib.mapAttrs (system: pkgs: (fn pkgs)) pkgsBySystem;
  in {
    formatter = forAllPkgs (pkgs: pkgs.alejandra);
    overlays.default = final: prev: {
      boltzClient = final.callPackage ./boltzClient.nix {};
    };
    packages = forAllPkgs (pkgs: {
      default = (self.overlays.default pkgs pkgs).boltzClient;
      boltzClient = self.packages.${pkgs.system}.default;
    });
  };
}
