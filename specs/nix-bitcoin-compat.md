# Spec: nix-bitcoin compatibility

## Goal

Make `services.boltz-client` work cleanly alongside nix-bitcoin without breaking standalone usage. Opt-in, not forced.

## Design

### New option

```nix
services.boltz-client.nixBitcoin.enable  # bool, default: false
```

When enabled:
- Explicit user/group (`isSystemUser = true`) instead of `DynamicUser`
- Data directory managed via `systemd.tmpfiles.rules`

When disabled (default):
- Current behavior unchanged (DynamicUser, StateDirectory)

### What stays the same

- `pkgs.formats.toml` for config
- `preStart` copies config to dataDir
- `environment.systemPackages` includes the package
- `settings` passthrough design
- Standalone hardening (ProtectSystem, ProtectHome, NoNewPrivileges, PrivateTmp)

### What we decided NOT to do

- **No auto-detection of nix-bitcoin** — `config.nix-bitcoin` throws in NixOS module system when namespace doesn't exist. `builtins.tryEval` doesn't catch it. Explicit toggle is cleaner.
- **No `nix-bitcoin.lib.defaultHardening` integration** — accessing it requires the nix-bitcoin module to be present. Can't probe safely. Our standalone hardening is good enough.
- **No `nix-bitcoin.operator.groups` registration** — can't define options in other modules' namespaces without them being imported. Users add this themselves.
- **No switching to `pkgs.writeText`** — `pkgs.formats.toml` is more nixpkgs-conventional.

### Future: nix-bitcoin upstream contribution

When we contribute this to nix-bitcoin:
- The module will live in nix-bitcoin's `modules/` directory
- It will have access to `config.nix-bitcoin.lib.defaultHardening` and `operator.groups` natively
- Can use their conventions (`isSystemUser`, tmpfiles, etc.) directly
- This flake's standalone module remains for non-nix-bitcoin users

### Acceptance criteria

1. `nix flake check` passes ✓
2. `services.boltz-client.enable = true` works standalone (DynamicUser) ✓
3. `services.boltz-client.nixBitcoin.enable = true` uses explicit user/group ✓
4. No changes to package derivation ✓
5. No changes to update automation ✓
