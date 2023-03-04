{ options, config, lib, pkgs, ... }:

with lib;
with lib.my;
let cfg = config.modules.services.docker;
in
{
  options.modules.services.docker = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    virtualisation.docker.enable = true;
    users.users.funforgiven.extraGroups = [ "docker" ];
    virtualisation.docker.storageDriver = "btrfs";
  };
}

