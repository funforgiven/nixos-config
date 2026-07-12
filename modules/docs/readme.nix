{ config, lib, ... }:
let
  hostName = "parmigiano";
  host = config.dendritic.hosts.${hostName};
  user = config.users.${host.user};
  homeConfigurationName = "${user.username}@${hostName}";
  wallpaperPath = config.dendritic.wallpaper.path;
in
{
  perSystem = psArgs: {
    text.readme = {
      order = [
        "intro"
        "overview"
        "layout"
        "dendritic"
        "local-files"
        "generated-files"
        "daily-use"
        "install"
        "checks"
        "credits"
      ];

      parts = {
        intro = ''
          # nixos-config

          Personal NixOS configuration for `${hostName}`, built on NixOS unstable
          with Home Manager and the dendritic module pattern.

          This is a machine-specific configuration rather than a reusable distribution.
          It can still be useful as a reference for a dendritic flake, a Niri desktop,
          or a declarative PipeWire setup.

        '';

        overview = ''
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

        '';

        layout = ''
          ## Repository Layout

          - `flake.nix` is generated; `outputs.nix` loads the module tree.
          - `modules/computers/` contains host facts and disk layout.
          - `modules/${host.user}/` contains personal applications and desktop settings.
          - `modules/hardware/` contains reusable hardware features.
          - `modules/packages/` contains local packages and overlays.
          - `modules/repository/` contains checks, formatting, and generated-file support.
          - `modules/docs/` contains the sources for generated documentation.

          `${hostName}` is assembled in `modules/computers/${hostName}.nix` by
          selecting focused features and the user's Home Manager profiles.

        '';

        local-files = ''
          ## Local Files

          Two machine-local inputs are deliberately kept out of Git:

          - The wallpaper is expected at `${wallpaperPath}`. Refresh its locked
            content after replacing it with:

            ```sh
            nix flake update wallpaper --accept-flake-config
            ```

          - The account password hash is expected at
            `/var/lib/nixos-secrets/${user.username}-password.hash` with owner
            `root` and mode `0600`.

          Runtime API credentials are read from 1Password. The repository contains
          references to those items, not their values.

        '';

        generated-files = ''
          ## Generated Files

          `flake.nix`, `.gitignore`, `README.md`, `LICENSE`, and
          `THIRD_PARTY_NOTICES.md` are generated. Edit their source modules, then run:

          ```sh
          nix run .#write-flake --accept-flake-config
          nix run .#write-files --accept-flake-config
          ```

          The flake checks fail when a committed generated file is stale.

        '';

        daily-use = ''
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
          sudo nixos-rebuild switch --flake .#${hostName} --accept-flake-config
          ```

          A compositor update takes effect after logging out and back in. Once inside
          the new Niri session, the deployed desktop and audio contracts can be checked
          without changing state:

          ```sh
          funforgiven-runtime-check
          ```

        '';

        install = ''
          ## Fresh Installation

          The disko command below destroys the configured target disk. Read
          `modules/computers/${hostName}-disko.nix` and verify the device path first.

          1. Provide the local wallpaper file described above.

          2. Partition and mount the verified disk:

             ```sh
             sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko -- \
               --mode destroy,format,mount --flake .#${hostName}
             ```

          3. Create the password hash expected by the user module:

             ```sh
             sudo mkdir -p /mnt/var/lib/nixos-secrets
             mkpasswd -m yescrypt | sudo tee /mnt/var/lib/nixos-secrets/${user.username}-password.hash >/dev/null
             sudo chmod 600 /mnt/var/lib/nixos-secrets/${user.username}-password.hash
             ```

          4. Install NixOS:

             ```sh
             sudo nixos-install --flake .#${hostName}
             ```

        '';

        checks = ''
          ## Validation

          Run the full flake evaluation and build the host and Home Manager outputs:

          ```sh
          nix flake check --no-build --accept-flake-config
          nix build \
            .#checks.${host.system}.${hostName}-home \
            .#checks.${host.system}.${hostName}-toplevel \
            --no-link --accept-flake-config
          ```

          Useful targeted evaluations are:

          ```sh
          nix eval .#diskoConfigurations.${hostName}.disko.devices.disk.main.device
          nix eval .#nixosConfigurations.${hostName}.config.system.build.toplevel.drvPath
          nix eval .#homeConfigurations."${homeConfigurationName}".activationPackage.drvPath
          ```

        '';

        credits = ''
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

        '';
      };
    };

    files.file."README.md".text = lib.removeSuffix "\n\n" psArgs.config.text.readme + "\n";
  };
}
