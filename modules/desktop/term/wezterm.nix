 
{ options, config, pkgs, lib, inputs, ... }:

with lib;
with lib.my;
let
  cfg = config.modules.desktop.term.wezterm;
in
{
  options.modules.desktop.term.wezterm = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    home-manager.users.funforgiven.programs.wezterm = {
      enable = true;
    };
  };
}
