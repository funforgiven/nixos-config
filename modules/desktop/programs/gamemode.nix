{ options, config, pkgs, lib, inputs, ... }:

with lib;
with lib.my;
let cfg = config.modules.desktop.programs.gamemode;
in
{
  options.modules.desktop.programs.gamemode = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    programs.gamemode = {
      enable = true;
      enableRenice = true;
      settings = {
        general = {
          renice = 10;
        };

        custom = {
          start = "${pkgs.libnotify}/bin/notify-send 'GameMode started'";
          end = "${pkgs.libnotify}/bin/notify-send 'GameMode ended'";
        };
      };
    };
  };
}


