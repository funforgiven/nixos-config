{ options, config, pkgs, lib, inputs, ... }:

with lib;
with lib.my;
let cfg = config.modules.shell.starship;
in
{
  options.modules.shell.starship = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    home-manager.users.funforgiven.programs.starship = {
      enable = true;
      enableZshIntegration = true;
      settings = {
        line_break.disabled = true;
      };
    };
  };
}
