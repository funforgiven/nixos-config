{ options, config, lib, pkgs, inputs, ... }:

with lib;
with lib.my;
let cfg = config.modules.desktop.browsers.firefox;
in
{
  options.modules.desktop.browsers.firefox = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    programs.firefox = {
      enable = true;
    };

    home-manager.users.funforgiven.xdg.mimeApps.defaultApplications = {
      "text/html" = [ "firefox.desktop" ];
      "text/xml" = [ "firefox.desktop" ];
      "x-scheme-handler/http" = [ "firefox.desktop" ];
      "x-scheme-handler/https" = [ "firefox.desktop" ];
      "application/pdf" = [ "firefox.desktop" ];
    };
  };
}
