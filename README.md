# nixos-config

Personal NixOS configuration for `parmigiano`, built on NixOS unstable
with Home Manager and the dendritic module pattern.

This is a machine-specific configuration rather than a reusable distribution.
It can still be useful as a reference for a dendritic flake, a Niri desktop,
or a declarative PipeWire setup.

## What It Configures

- AMD Ryzen desktop with an NVIDIA GPU
- Niri with a repository-owned Quickshell bar, dock, launcher, and mixer
- Fish for interactive use, with Bash available for scripts
- Home Manager profiles for command-line and graphical applications
- Four logical PipeWire/WirePlumber audio channels
- Turkish and Japanese input through Fcitx5 and Mozc
- Btrfs on NVMe through disko, with systemd-boot
- Wallpaper-derived colors shared through Matugen and Stylix
- 1Password for credentials that are needed at runtime

## Repository Layout

- `flake.nix` is generated; `outputs.nix` loads the module tree.
- `modules/computers/` contains host facts and disk layout.
- `modules/funforgiven/` contains personal applications and desktop settings.
- `modules/hardware/` contains reusable hardware features.
- `modules/packages/` contains local packages and overlays.
- `modules/repository/` contains checks, formatting, and generated-file support.
- `modules/docs/` contains the sources for generated documentation.

`parmigiano` is assembled in `modules/computers/parmigiano.nix` by
selecting focused features and the user's Home Manager profiles.

## Dendritic Pattern

This repository follows the dendritic pattern from `mightyiam/dendritic`: every
Nix file under `modules/` is a top-level flake-parts module, and feature
modules register named NixOS and Home Manager modules instead of importing
distant paths directly.

## Local Files

Two machine-local inputs are deliberately kept out of Git:

- The wallpaper is expected at `/home/funforgiven/Pictures/Wallpapers/current.png`. Refresh its locked
  content after replacing it with:

  ```sh
  nix flake update wallpaper --accept-flake-config
  ```

- The account password hash is expected at
  `/var/lib/nixos-secrets/funforgiven-password.hash` with owner
  `root` and mode `0600`.

Runtime API credentials are read from 1Password. The repository contains
references to those items, not their values.

## Generated Files

`flake.nix`, `.gitignore`, `README.md`, `LICENSE`, and
`THIRD_PARTY_NOTICES.md` are generated. Edit their source modules, then run:

```sh
nix run .#write-flake --accept-flake-config
nix run .#write-files --accept-flake-config
```

The flake checks fail when a committed generated file is stale.

## Day-to-Day Use

Enter the development shell to install the checkout's pre-commit hook:

```sh
nix develop --accept-flake-config
```

Format and validate before rebuilding:

```sh
nix fmt --accept-flake-config
nix flake check --no-build --accept-flake-config
```

Apply the host configuration with:

```sh
sudo nixos-rebuild switch --flake .#parmigiano --accept-flake-config
```

A compositor update takes effect after logging out and back in. Once inside
the new Niri session, the deployed desktop and audio contracts can be checked
without changing state:

```sh
funforgiven-runtime-check
```

## Fresh Installation

The disko command below destroys the configured target disk. Read
`modules/computers/parmigiano-disko.nix` and verify the device path first.

1. Provide the local wallpaper file described above.

2. Partition and mount the verified disk:

   ```sh
   sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko -- \
     --mode destroy,format,mount --flake .#parmigiano
   ```

3. Create the password hash expected by the user module:

   ```sh
   sudo mkdir -p /mnt/var/lib/nixos-secrets
   mkpasswd -m yescrypt | sudo tee /mnt/var/lib/nixos-secrets/funforgiven-password.hash >/dev/null
   sudo chmod 600 /mnt/var/lib/nixos-secrets/funforgiven-password.hash
   ```

4. Install NixOS:

   ```sh
   sudo nixos-install --flake .#parmigiano
   ```

## Validation

Run the full flake evaluation and build the host and Home Manager outputs:

```sh
nix flake check --no-build --accept-flake-config
nix build \
  .#checks.x86_64-linux.parmigiano-home \
  .#checks.x86_64-linux.parmigiano-toplevel \
  --no-link --accept-flake-config
```

Useful targeted evaluations are:

```sh
nix eval .#diskoConfigurations.parmigiano.disko.devices.disk.main.device
nix eval .#nixosConfigurations.parmigiano.config.system.build.toplevel.drvPath
nix eval .#homeConfigurations."funforgiven@parmigiano".activationPackage.drvPath
```

## Credits

The repository architecture follows
[mightyiam's dendritic pattern](https://github.com/mightyiam/dendritic),
with [mightyiam/infra](https://github.com/mightyiam/infra) as its primary
reference configuration.

The Quickshell design draws on
[Noctalia v4](https://github.com/noctalia-dev/noctalia/tree/legacy-v4)
and [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell).

Exact snapshots and licenses for adapted source are recorded in
`THIRD_PARTY_NOTICES.md`.
