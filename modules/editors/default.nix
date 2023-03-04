{ config, options, lib, pkgs, ... }:

with lib;
with lib.my;
let cfg = config.modules.editors;
in {
  options.modules.editors = {
    default = mkOpt types.str "nano";
  };

  config = mkIf (cfg.default != null) {
    environment.variables.EDITOR = cfg.default;
  };
}
