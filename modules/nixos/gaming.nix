{
  programs = {
    steam = {
      enable = true;
      extest.enable = true;
      protontricks.enable = true;
      remotePlay.openFirewall = false;
      dedicatedServer.openFirewall = false;
      localNetworkGameTransfers.openFirewall = false;
      gamescopeSession.enable = false;
    };

    gamemode = {
      enable = true;
      enableRenice = true;
    };

    gamescope = {
      enable = true;
      capSysNice = true;
    };
  };
}
