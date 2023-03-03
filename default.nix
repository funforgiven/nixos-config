{ inputs, config, lib, pkgs, ... }:

with lib;
with lib.my;
{
  imports = [
    inputs.home-manager.nixosModules.home-manager
  ] ++ (mapModulesRec' (toString ./modules) import);

  # https://nix-community.github.io/home-manager/index.html#sec-install-nixos-module
  # "use the global pkgs that is configured via the system level nixpkgs options"
  # "This saves an extra Nixpkgs evaluation, adds consistency, and removes the dependency on NIX_PATH,
  #  which is otherwise used for importing Nixpkgs."
  home-manager.useGlobalPkgs = true;

  # Configure nix
  nix = {
    settings = {
      substituters = [
        "https://cache.nixos.org?priority=10"
        "https://nix-community.cachix.org"
      ];

      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];

      trusted-users = [
        "root"
        "@wheel"
      ];

      auto-optimise-store = true;
      builders-use-substitutes = true;
      experimental-features = ["nix-command" "flakes" "repl-flake"];
      keep-derivations = true;
      keep-outputs = true;
      max-jobs = "auto";
      warn-dirty = false;
    };

    gc = {
      automatic = true;
      dates = "daily";
      options = "--delete-older-than 3d";
    };
  };

  system.configurationRevision = with inputs; mkIf (self ? rev) self.rev;

  environment.systemPackages = with pkgs; [
    bind
    cached-nix-shell
    git
    nano
    wget
    gnumake
    unzip
  ];

  security = {
    pam = {
      loginLimits = [
        {
          domain = "@wheel";
          item = "nofile";
          type = "soft";
          value = "524288";
        }
        {
          domain = "@wheel";
          item = "nofile";
          type = "hard";
          value = "1048576";
        }
      ];
    };

    polkit.enable = true;
  };
}
