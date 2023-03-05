{ config, options, lib, pkgs, ... }:

with lib;
with lib.my;
let cfg = config.modules.editors;
in {
  options.modules.editors = {
    editor = mkOpt types.str "nano";
    visual = mkOpt types.str "nano";
  };

  config = {
    environment.variables.EDITOR = mkIf (cfg.editor != null) cfg.editor;
    environment.variables.VISUAL = mkIf (cfg.visual != null) cfg.visual;
  };
}
