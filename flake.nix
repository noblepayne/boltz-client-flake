{
  description = "A nix flake for boltz-client.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
  };

  outputs = {
    self,
    nixpkgs,
    ...
  }: let
    supportedSystems = ["x86_64-linux" "aarch64-linux"];
    pkgsBySystem = nixpkgs.lib.getAttrs supportedSystems nixpkgs.legacyPackages;
    forAllPkgs = fn: nixpkgs.lib.mapAttrs (system: pkgs: (fn pkgs)) pkgsBySystem;
    version = "2.3.4";

    boltzClientFor = pkgs:
      pkgs.stdenv.mkDerivation {
        inherit version;
        pname = "boltz-client";

        src = pkgs.fetchzip {
          url = "https://github.com/BoltzExchange/boltz-client/releases/download/v2.3.4/boltz-client-linux-amd64-v2.3.4.tar.gz";
          hash = "sha256-HcPlxsDoxXn9NS7KR3+3Q/q/Lsj+dWMEyFemQ0vStwg=";
        };

        nativeBuildInputs = [
          pkgs.autoPatchelfHook
        ];

        buildInputs = [
          pkgs.stdenv.cc.cc.lib # for libstdc++
        ];

        installPhase = ''
          mkdir -p $out/bin
          cp **/* $out/bin/
        '';
      };
  in {
    formatter = forAllPkgs (pkgs: pkgs.alejandra);
    packages = forAllPkgs (pkgs: {
      default = boltzClientFor pkgs;
    });
  };
}
