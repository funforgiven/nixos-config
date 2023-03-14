{ config, options, lib, pkgs, ... }:

with lib;
with lib.my;
let cfg = config.modules.editors;
in
{
  options.modules.editors = {
    editor = mkOpt types.str "nano";
    visual = mkOpt types.str "nano";
  };

  config = {
    home-manager.users.funforgiven.home.sessionVariables.EDITOR = mkIf (cfg.editor != null) cfg.editor;
    home-manager.users.funforgiven.home.sessionVariables.VISUAL = mkIf (cfg.visual != null) cfg.visual;
  };
}
