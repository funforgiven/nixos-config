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
  };
}
