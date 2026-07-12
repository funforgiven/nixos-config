{
  config,
  inputs,
  lib,
  ...
}:
let
  cfg = config.dendritic.stylix;
in
{
  options.dendritic.stylix.commonModule = lib.mkOption {
    type = lib.types.deferredModule;
    default = { };
    description = "Shared Stylix configuration evaluated by NixOS and standalone Home Manager.";
  };

  config = {
    nixos.modules.stylix.imports = [
      inputs.stylix.nixosModules.stylix
      cfg.commonModule
    ];

    homeManager.standaloneModules.stylix.imports = [
      inputs.stylix.homeModules.stylix
    ];

    home.gui.imports = [ cfg.commonModule ];
  };
}
