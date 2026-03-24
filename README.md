# boltz-client-flake

A Nix Flake packaging [boltz-client](https://github.com/BoltzExchange/boltz-client) — submarine swaps, channel rebalancing, and wallet management for CLN & LND.

Uses precompiled binaries from upstream releases (building from source is infeasible due to Docker-based GDK builds and Rust/C FFI).

## Usage

### Run directly

```bash
nix run github:noblepayne/boltz-client-flake -- --version
```

### In a flake

```nix
{
  inputs.boltz-client-flake.url = "github:noblepayne/boltz-client-flake";

  outputs = { self, nixpkgs, boltz-client-flake, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        boltz-client-flake.nixosModules.default
        {
          services.boltz-client.enable = true;
        }
      ];
    };
  };
}
```

### Overlay

```nix
{
  nixpkgs.overlays = [ boltz-client-flake.overlays.default ];
}
# then use pkgs.boltz-client
```

## NixOS Module

When enabled, the module runs `boltzd` as a systemd service and makes `boltzcli` available in your PATH.

```nix
{
  services.boltz-client = {
    enable = true;

    # Pass-through config as Nix attrs, rendered to TOML
    settings = {
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
    };

    # Extra CLI flags
    extraArgs = ["--loglevel=debug"];
  };
}
```

### Options

| Option | Default | Description |
|--------|---------|-------------|
| `services.boltz-client.enable` | `false` | Enable the boltzd service |
| `services.boltz-client.package` | flake package | Package providing `boltzd` and `boltzcli` |
| `services.boltz-client.dataDir` | `/var/lib/boltz` | Data directory for boltzd |
| `services.boltz-client.settings` | `{}` | Boltz config as Nix attrs, converted to TOML |
| `services.boltz-client.extraArgs` | `[]` | Extra CLI args passed to boltzd |

## Updates

The flake uses [nix-update](https://github.com/Mic92/nix-update) for automated version tracking:

```bash
# Manual update
nix develop --command ./update.sh

# Automated (GitHub Actions)
# Twice daily: checks for new releases, validates build, pushes to main
```
