{ config, lib, ... }:
{
  systems = lib.unique (lib.mapAttrsToList (_: host: host.system) config.dendritic.hosts);
}
