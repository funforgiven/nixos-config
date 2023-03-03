{ options, config, lib, pkgs, inputs, ... }:

with lib;
with lib.my;
let cfg = config.modules.desktop.apps;
in
{
  options.modules.desktop.apps = {
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
