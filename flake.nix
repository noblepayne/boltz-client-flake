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
    archForPkgs = pkgs:
      if pkgs.stdenv.isAarch64
      then "arm64"
      else "amd64";
    hashByArch = arch:
      if arch == "arm64"
      then "sha256-vfz/oJrxZCeJ1yVIE95ynKpVwRu+dbBVdzu7onl748w="
      else "sha256-K4rtfPh3KW+6ON/3HLMDrbBcBiQGjpxCbsikZ34bNSU=";
    version = "2.8.4";

    boltzClientFor = pkgs:
      pkgs.stdenv.mkDerivation {
        inherit version;
        pname = "boltz-client";

        src = let
          arch = archForPkgs pkgs;
          hash = hashByArch arch;
        in
          pkgs.fetchzip {
            inherit hash;
            url = "https://github.com/BoltzExchange/boltz-client/releases/download/v${version}/boltz-client-linux-${arch}-v${version}.tar.gz";
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
