{ options, config, lib, pkgs, ... }:

with lib;
with lib.my;
let cfg = config.modules.services.tailscale;
in
{
  options.modules.services.tailscale = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    services.tailscale.enable = true;

    networking = {
        networkmanager.enable = true;
        nameservers = [ "100.100.100.100" "1.1.1.1" ];
        search = [ "tail47254.ts.net" ];
        firewall.checkReversePath = "loose";
    };
  };
}
