{ options, config, pkgs, lib, inputs, ... }:

with lib;
with lib.my;
let
  cfg = config.modules.editors.helix;
in
{
  options.modules.editors.helix = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    home-manager.users.funforgiven.programs.helix = {
      enable = true;
    };
  };
}
