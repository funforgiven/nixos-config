{ options, config, lib, pkgs, inputs, ... }:

with lib;
with lib.my;
let cfg = config.modules.desktop.programs;
in
{
  options.modules.desktop.programs = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      ark
      p7zip
      unrar
      mpv
      gimp
      qbittorrent
      obs-studio
      tdesktop
      neofetch
      tokei
    ];
  };
}
