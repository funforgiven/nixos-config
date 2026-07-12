_: {
  dendritic.nixpkgs.allowUnfreePackages = [
    "steam"
    "steam-original"
    "steam-run"
    "steam-unwrapped"
  ];

  nixos.modules.gaming.imports = [
    {
      programs = {
        steam = {
          enable = true;
          extest.enable = true;
          localNetworkGameTransfers.openFirewall = true;
          protontricks.enable = true;
        };

        gamemode = {
          enable = true;
        };

        gamescope = {
          enable = true;
        };
      };
    }
  ];
}
