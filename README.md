# nixos-config

Modular NixOS unstable flake for `parmigiano`.

## Defaults

- Host: `parmigiano`
- User: `funforgiven`
- System: `x86_64-linux`
- Hardware target: AMD Ryzen 9 9950X3D with NVIDIA RTX 5090
- Desktop: Niri with Noctalia v5 and Noctalia greeter
- Storage: plain btrfs on NVMe through disko, no LUKS, no disk swap, no btrfs snapshots
- Boot: systemd-boot, with room to add lanzaboote later
- Graphics: NVIDIA open kernel module with the latest packaged driver and Niri's Wayland compositor profile workaround
- Codex: Home Manager-managed Codex package and stable `config.toml` settings, with `github:utensils/mcp-nixos` as the NixOS MCP server

Host-specific disk and hardware configuration lives under `hosts/parmigiano/`.
Reusable NixOS and Home Manager modules live under `modules/nixos/` and `modules/home/`.

## Install Guide

1. Create or update the flake lock on a NixOS system or installer ISO:

   ```sh
   nix flake lock
   ```

2. Replace the placeholder disk in `hosts/parmigiano/disko.nix`:

   ```sh
   ls -l /dev/disk/by-id/
   ```

3. Format and mount with disko only after confirming the disk path:

   ```sh
   sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko -- \
     --mode destroy,format,mount ./hosts/parmigiano/disko.nix
   ```

   This creates the filesystems and mounts the target system at `/mnt`.

4. Create the password hash file inside the mounted target system:

   ```sh
   sudo mkdir -p /mnt/var/lib/nixos-secrets
   mkpasswd -m yescrypt | sudo tee /mnt/var/lib/nixos-secrets/funforgiven-password.hash >/dev/null
   sudo chmod 600 /mnt/var/lib/nixos-secrets/funforgiven-password.hash
   ```

5. Install:

   ```sh
   sudo nixos-install --flake .#parmigiano
   ```

## Managed State

Nix/Home Manager manages the Codex binary, stable Codex settings, MCP server commands, and tool dependencies such as `nodejs`, `uv`, `gh`, `ripgrep`, and `fd`.

Codex login state, `auth.json`, caches, logs, history, and other runtime files under `~/.codex` remain unmanaged.

## Checks

Run these on NixOS or the installer ISO:

```sh
nix flake check
nix eval .#nixosConfigurations.parmigiano.config.system.build.toplevel.drvPath
```
