{ config, ... }:
let
  user = config.users.funforgiven;
in
{
  nixos.modules.funforgiven-account =
    { pkgs, ... }:
    {
      users = {
        mutableUsers = false;

        users.${user.username} = {
          isNormalUser = true;
          description = user.name;
          home = user.homeDirectory;
          shell = pkgs.fish;
          extraGroups = [
            "wheel"
            "networkmanager"
            "audio"
            "video"
            "input"
            "render"
            "systemd-journal"
          ];
        };
      };
    };
}
