_: {
  nixos.modules.syncthing =
    { config, ... }:
    let
      primaryUser = config.dendritic.primaryUser;
    in
    {
      services.syncthing = {
        enable = true;
        user = primaryUser.username;
        dataDir = primaryUser.homeDirectory;
        configDir = "${primaryUser.homeDirectory}/.config/syncthing";
        overrideDevices = false;
        overrideFolders = false;
        openDefaultPorts = true;
      };
    };
}
