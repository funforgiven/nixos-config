{ config, lib, ... }:
{
  options.dendritic.input.physicalXkbLayout = lib.mkOption {
    type = lib.types.singleLineStr;
    readOnly = true;
    description = "Physical XKB layout shared by NixOS and Niri.";
  };

  config = {
    dendritic.input.physicalXkbLayout = "tr";

    nixos.modules.funforgiven-input = {
      services = {
        libinput.enable = true;
        xserver.xkb.layout = config.dendritic.input.physicalXkbLayout;
      };

      console.keyMap = "trq";
    };
  };
}
