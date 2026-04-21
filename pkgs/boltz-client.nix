{
  stdenv,
  lib,
  fetchzip,
  autoPatchelfHook,
  ...
}: let
  version = "2.11.3";
  archMap = {
    x86_64-linux = "amd64";
    aarch64-linux = "arm64";
  };
  system = stdenv.hostPlatform.system;
  arch = archMap.${system} or (throw "unsupported system: ${system}");
in
  stdenv.mkDerivation {
    pname = "boltz-client";
    inherit version;

    src = fetchzip {
      url = "https://github.com/BoltzExchange/boltz-client/releases/download/v${version}/boltz-client-linux-${arch}-v${version}.tar.gz";
      hash =
        {
          amd64 = "sha256-/8Wt4in0biqHjC2ORzEKuqtf/KcquKwhihhZi8mqrv8=";
          arm64 = "sha256-HWHzcqQVtAmyhskzAHqNCA62U9wWRlXXH2y1lUxFIsg=";
        }
      .${
          arch
        };
    };

    nativeBuildInputs = [autoPatchelfHook];
    buildInputs = [stdenv.cc.cc.lib];

    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall

      install -Dm755 linux_${arch}/boltzd $out/bin/boltzd
      install -Dm755 linux_${arch}/boltzcli $out/bin/boltzcli

      runHook postInstall
    '';

    meta = with lib; {
      description = "Boltz client for CLN & LND — submarine swaps, channel rebalancing";
      homepage = "https://github.com/BoltzExchange/boltz-client";
      license = licenses.mit;
      platforms = ["x86_64-linux" "aarch64-linux"];
      mainProgram = "boltzd";
    };
  }
