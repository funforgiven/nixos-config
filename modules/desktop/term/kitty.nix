{ options, config, pkgs, lib, inputs, ... }:

with lib;
with lib.my;
let
  cfg = config.modules.desktop.term.kitty;
in
{
  options.modules.desktop.term.kitty = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    home-manager.users.funforgiven.programs.kitty = {
      enable = true;
      theme = "Rosé Pine";
      font = {
        name = "FiraCode Nerd Font";
        size = 12;
      };
      settings = {
        window_padding_width = 15;
      };
    };
  };
}
