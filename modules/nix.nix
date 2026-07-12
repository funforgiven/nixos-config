{ config, inputs, ... }:
{
  nixos.modules.nix = {
    nixpkgs = {
      config = config.dendritic.nixpkgs.effectiveConfig;
      overlays = [ config.flake.overlays.default ];
    };

    nix = {
      settings = {
        experimental-features = [
          "nix-command"
          "flakes"
        ];
        trusted-users = [
          "@wheel"
        ];
        warn-dirty = false;
      };

      gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 14d";
      };

      optimise = {
        automatic = true;
        dates = [ "weekly" ];
      };

      registry.nixpkgs.flake = inputs.nixpkgs;
      nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
    };
  };
}
