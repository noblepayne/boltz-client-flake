self: {
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.boltz-client;
  useNb = cfg.nixBitcoin.enable;
  tomlFormat = pkgs.formats.toml {};
  configFile = tomlFormat.generate "boltz.toml" cfg.settings;

  standaloneHardening = {
    ProtectSystem = "strict";
    ProtectHome = true;
    NoNewPrivileges = true;
    PrivateTmp = true;
  };
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

    user = lib.mkOption {
      type = lib.types.str;
      default = "boltz";
      description = "User to run boltzd as.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = cfg.user;
      description = "Group to run boltzd as.";
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

    nixBitcoin.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable nix-bitcoin integration:
        - Run as dedicated user (isSystemUser) instead of DynamicUser
        - Use nix-bitcoin's defaultHardening when available
        - Register with nix-bitcoin.operator.groups for CLI access
        - Manage data directory via tmpfiles.rules
      '';
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

        baseConfig =
          {
            ExecStart = "${cfg.package}/bin/boltzd ${lib.escapeShellArgs args}";
            Restart = "on-failure";
            RestartSec = "10s";
            ReadWritePaths = [cfg.dataDir];
          }
          // standaloneHardening;

        userConfig = lib.optionalAttrs useNb {
          User = cfg.user;
          Group = cfg.group;
        };

        dynamicConfig = lib.optionalAttrs (!useNb) {
          DynamicUser = true;
          StateDirectory = "boltz";
          StateDirectoryMode = "0750";
        };
      in
        baseConfig // userConfig // dynamicConfig;

      preStart = ''
        cp -f ${configFile} ${cfg.dataDir}/boltz.toml
        chmod 640 ${cfg.dataDir}/boltz.toml
      '';
    };

    systemd.tmpfiles.rules = lib.mkIf useNb [
      "d '${cfg.dataDir}' 0750 ${cfg.user} ${cfg.group} - -"
    ];

    users.users.${cfg.user} = lib.mkIf useNb {
      isSystemUser = true;
      group = cfg.group;
    };

    users.groups.${cfg.group} = lib.mkIf useNb {};
  };
}
