_: {
  nixos.modules.fish = {
    programs.fish.enable = true;
  };

  home.base = {
    home.shell = {
      enableShellIntegration = false;
      enableFishIntegration = true;
    };

    programs.fish.enable = true;
  };
}
