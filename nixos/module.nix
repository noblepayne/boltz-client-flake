self: {
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.boltz-client;
  tomlFormat = pkgs.formats.toml {};
  configFile = tomlFormat.generate "boltz.toml" cfg.settings;
in {
  options.services.boltz-client = {
    enable = lib.mkEnableOption "Boltz client daemon";

    package = lib.mkOption {
      type = lib.types.package;
      default =
        self.packages.${pkgs.system}.boltz-client
        or self.packages.${pkgs.system}.default;
      defaultText = lib.literalExpression "inputs.boltz-client-flake.packages.\${system}.default";
      description = "The boltz-client package to use (provides both boltzd and boltzcli).";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/boltz";
      description = "Data directory for boltzd.";
    };

    settings = lib.mkOption {
      type = tomlFormat.type;
      default = {};
      description = ''
        Boltz client configuration as a Nix attrset.
        Converted to TOML at build time. See
        <https://docs.boltz.exchange/boltz-client/configuration>
        for available options.

        Example:
        ```nix
        {
          node = "lnd";
          network = "mainnet";
          lnd = {
            host = "127.0.0.1";
            port = 10009;
            macaroon = "/path/to/admin.macaroon";
            certificate = "/path/to/tls.cert";
          };
          rpc = {
            host = "127.0.0.1";
            port = 9002;
          };
        }
        ```
      '';
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Extra command-line arguments passed to boltzd.";
      example = ["--loglevel=debug"];
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [cfg.package];

    systemd.services.boltzd = {
      description = "Boltz Client Daemon";
      wantedBy = ["multi-user.target"];
      after = ["network-online.target"];
      wants = ["network-online.target"];

      serviceConfig = let
        args =
          ["--datadir" cfg.dataDir]
          ++ cfg.extraArgs;
      in {
        ExecStart = "${cfg.package}/bin/boltzd ${lib.escapeShellArgs args}";
        StateDirectory = "boltz";
        StateDirectoryMode = "0750";
        DynamicUser = true;
        Restart = "on-failure";
        RestartSec = "10s";

        # Hardening
        ProtectSystem = "strict";
        ProtectHome = true;
        NoNewPrivileges = true;
        PrivateTmp = true;
        ReadWritePaths = [cfg.dataDir];
      };

      preStart = ''
        cp -f ${configFile} ${cfg.dataDir}/boltz.toml
        chmod 640 ${cfg.dataDir}/boltz.toml
      '';
    };
  };
}
