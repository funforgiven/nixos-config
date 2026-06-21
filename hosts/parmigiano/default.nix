{
  inputs,
  hostname,
  username,
  ...
}:
{
  imports = [
    ./disko.nix
    ./hardware.nix
    ../../modules/nixos
  ];

  networking.hostName = hostname;
  system.stateVersion = "25.11";

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-bak";
    extraSpecialArgs = {
      inherit inputs hostname username;
    };
    users.${username} = import ../../modules/home;
  };
}
