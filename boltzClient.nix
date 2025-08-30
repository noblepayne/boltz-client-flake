{
  autoPatchelfHook,
  fetchzip,
  stdenv,
  ...
}: let
  arch =
    if stdenv.isAarch64
    then "arm64"
    else "amd64";
  hash =
    if arch == "arm64"
    then "sha256-vfz/oJrxZCeJ1yVIE95ynKpVwRu+dbBVdzu7onl748w="
    else "sha256-K4rtfPh3KW+6ON/3HLMDrbBcBiQGjpxCbsikZ34bNSU=";
  version = "2.8.4";
in
  stdenv.mkDerivation {
    inherit version;
    pname = "boltz-client";

    src = fetchzip {
      inherit hash;
      url = "https://github.com/BoltzExchange/boltz-client/releases/download/v${version}/boltz-client-linux-${arch}-v${version}.tar.gz";
    };

    nativeBuildInputs = [
      autoPatchelfHook
    ];

    buildInputs = [
      stdenv.cc.cc.lib # for libstdc++
    ];

    installPhase = ''
      mkdir -p $out/bin
      cp **/* $out/bin/
    '';
  }
