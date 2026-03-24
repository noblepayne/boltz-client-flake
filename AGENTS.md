# AGENTS.md - boltz-client-flake

> "Simple is the opposite of complex."

## Context

Nix Flake packaging [boltz-client](https://github.com/BoltzExchange/boltz-client) — submarine swaps, channel rebalancing, and wallet management for CLN & LND.

Uses precompiled binaries from upstream releases. Building from source is infeasible (Docker-based GDK builds, Rust/C FFI via uniffi-bindgen-go).

### What's In The Box

| Binary | What it does |
|--------|-------------|
| `boltzd` | Daemon — gRPC/REST API, manages swaps, connects to LND/CLN |
| `boltzcli` | CLI client — talks to boltzd over gRPC |

### Binary Dependencies (Why We Need autoPatchelfHook)

| Binary | Interpreter | NEEDED libraries |
|--------|------------|-----------------|
| `boltzd` | `/lib64/ld-linux-x86-64.so.2` | libresolv, **libstdc++**, libm, **libgcc_s**, libc, ld-linux |
| `boltzcli` | `/lib64/ld-linux-x86-64.so.2` | libc only |

The interpreter path doesn't exist on NixOS. `autoPatchelfHook` rewrites it. `stdenv.cc.cc.lib` in `buildInputs` provides libstdc++ and libgcc_s.

### Tarball Structure

```
bin/linux_amd64/boltzd      (fetched to: linux_amd64/boltzd — fetchzip strips bin/)
bin/linux_amd64/boltzcli
```

---

## Project Layout

```
flake.nix                       # Thin orchestrator — forAllPkgs, treefmt-nix, overlay, devShell
flake.lock                      # nixpkgs + treefmt-nix pins
pkgs/
  boltz-client.nix              # Self-contained: version, hashes, autoPatchelfHook, build
update.sh                       # nix-update --flake --commit
nixos/
  module.nix                    # NixOS module: services.boltz-client
.github/workflows/
  auto-update.yml               # Twice daily: update, validate, push
  build-test.yml                # Daily + PR: build validation
```

---

## Research-First Workflow

Before implementing, ALWAYS:

### 1. "Does this already exist?"

- Search upstream for existing solutions
- Check nixpkgs for the package
- Look at similar flakes for patterns

### 2. Research Phase

1. Read the existing codebase to understand current patterns
2. Check upstream release notes and changelogs
3. Verify assumptions about binary structure, dependencies, file layouts
4. Web search for known issues (e.g., libstdc++ on NixOS)

### 3. Specify Phase

Write before coding:

- What exists, what needs building
- Acceptance criteria
- Edge cases (tarball structure, hash format, platform differences)

### 4. Break Into Branches

- Small, focused branches
- Each independently testable
- `nix flake check` must pass after every branch

---

## How To Do Good Changes

### Branch Workflow

1. Create branch from `main` (or the branch it depends on)
2. Make changes in small logical commits
3. Run validation after every change (see below)
4. Merge when ready

### Validation Gate (Run After Every Change)

```bash
# Always run before committing:
nix fmt                  # Format nix files
nix flake check          # Eval + formatting check + NixOS module check
nix build .#boltz-client # Build succeeds
./result/bin/boltzd --version    # Binary works
./result/bin/boltzcli --version  # Both binaries work
```

If `nix flake check` fails, fix it. Don't commit broken checks.

### Commit Messages

```
<type>: <subject>

<optional body>
```

Types: `feat`, `fix`, `refactor`, `chore`, `docs`, `ci`

Examples:
```
feat: add NixOS module for boltzd

- services.boltz-client.settings: Nix attrs -> TOML passthrough
- DynamicUser, hardened systemd service

ci: add auto-update workflow

Runs twice daily, validates build before pushing.
```

### Updating Upstream Version

```bash
# Automated (preferred):
nix develop --command ./update.sh

# Manual:
nix-prefetch-url --unpack "<tarball-url>"
nix hash to-sri --type sha256 <hash>
# Edit pkgs/boltz-client.nix: version + hashes
nix build .#boltz-client
./result/bin/boltzd --version  # Verify
```

---

## Nix Style Conventions

### Flake Structure

- **Thin flake.nix** — no package logic, just `callPackage` dispatcher
- **Self-contained packages** — version, hashes, build in one file per package
- **`forAllPkgs` pattern** — `lib.getAttrs` + `lib.mapAttrs`, no flake-utils
- **treefmt-nix** for formatting (alejandra), not bare `pkgs.alejandra`

### Package Derivations

- `stdenv.mkDerivation` with `dontConfigure = true; dontBuild = true;` for binary packaging
- `autoPatchelfHook` in `nativeBuildInputs`
- Runtime libs in `buildInputs` (e.g., `stdenv.cc.cc.lib`)
- `installPhase` with `install -Dm755` — explicit paths, not `cp -r $src/*`
- Always use `runHook preInstall` / `runHook postInstall`
- `meta` block: description, homepage, license, platforms, mainProgram

### NixOS Modules

- `settings` option with `pkgs.formats.toml` type — passthrough, don't enumerate options
- `preStart` copies generated config to mutable dataDir
- `DynamicUser = true` — no manual user/group management
- `environment.systemPackages = [cfg.package]` — make CLI tools available
- Hardened systemd: `ProtectSystem = "strict"`, `NoNewPrivileges`, `PrivateTmp`

### Formatting

- Alejandra via treefmt-nix
- Run `nix fmt` before committing
- `nix flake check` enforces formatting

---

## Anti-Patterns

- **Don't `cp -r $src/* $out`** — use `install -Dm755` for explicit binary targets
- **Don't enumerate NixOS options you don't own** — passthrough via `settings` attrset
- **Don't skip `nix flake check`** — it catches eval errors, formatting issues, module problems
- **Don't commit without testing both binaries** — `boltzd` and `boltzcli` have different dependency profiles
- **Don't forget `stdenv.cc.cc.lib`** — libstdc++ crash is a known gotcha for CGO Go binaries on NixOS
- **Don't build from source when precompiled exists** — upstream build uses Docker, uniffi-bindgen-go, cargo; not worth fighting
- **Don't pin to stable nixpkgs without reason** — we track upstream closely, unstable is fine

---

## Debugging

### Binary Won't Start

```bash
# Check interpreter path
readelf -l ./result/bin/boltzd | grep interpreter

# Check dynamic dependencies
readelf -d ./result/bin/boltzd | grep NEEDED

# Verify autoPatchelfHook worked — interpreter should be in /nix/store/
# NOT /lib64/ld-linux-x86-64.so.2
```

### Hash Mismatch

```bash
# Get new hash for updated version
nix hash to-sri --type sha256 $(nix-prefetch-url --unpack "<new-url>")
```

### Flake Check Fails on Formatting

```bash
nix fmt       # Fix formatting
git add -A    # Stage formatted files (flake check sees git-tracked files only)
nix flake check
```

### Nix Flakes Only See Git-Tracked Files

Always `git add` new files before `nix build` or `nix flake check`. Nix flakes ignore untracked files.

---

## The Most Important Lesson

> "AI coding tools make you fast at building. They don't make you fast at knowing what to build."

**Always research first:**
1. Check if upstream already solved it
2. Check nixpkgs for existing patterns
3. Check if other flakes have the same problem
4. Read the code before changing it

**When to research vs. build:**

| Build it | Research first |
|----------|---------------|
| Version bumps | New packaging approaches |
| Hash updates | NixOS module design |
| Bug fixes in code you wrote | New CI workflows |
| Formatting fixes | Dependency management |
| | Upstream API changes |
