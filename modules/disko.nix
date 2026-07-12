{ inputs, ... }:
{
  imports = [ inputs.disko.flakeModule ];

  nixos.modules.disko.imports = [ inputs.disko.nixosModules.disko ];
}
