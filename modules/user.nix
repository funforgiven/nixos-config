{ config, pkgs, lib, inputs, ... }:

{
  config = {
    users.users.funforgiven = {
      isNormalUser = true;
      description = "Fahrican Elidemir";
      extraGroups = [ "networkmanager" "wheel" "input" "power" ];
      shell = pkgs.zsh;
    };

    home-manager.users.funforgiven.home.stateVersion = config.system.stateVersion;
    home-manager.users.funforgiven.nixpkgs.config.allowUnfree = true;
  };
}
