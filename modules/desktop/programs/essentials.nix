{ options, config, lib, pkgs, inputs, ... }:

with lib;
with lib.my;
let cfg = config.modules.desktop.programs.essentials;
in
{
  options.modules.desktop.programs.essentials = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      kate
      ark
      p7zip
      unrar
      mpv
      gimp
      qbittorrent
      obs-studio
      tdesktop
      kitty
    ];
  };
}
