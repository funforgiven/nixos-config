{
  inputs,
  username,
  ...
}:
{
  imports = [
    inputs.noctalia.homeModules.default
    ./codex.nix
    ./niri.nix
    ./noctalia.nix
    ./packages.nix
    ./shell.nix
    ./terminal.nix
  ];

  home = {
    inherit username;
    homeDirectory = "/home/${username}";
    stateVersion = "25.11";
    sessionVariables = {
      BROWSER = "firefox";
      EDITOR = "vim";
      MOZ_ENABLE_WAYLAND = "1";
      NIXOS_OZONE_WL = "1";
      TERMINAL = "foot";
      XDG_CURRENT_DESKTOP = "niri";
      XDG_SESSION_DESKTOP = "niri";
    };
  };

  programs.home-manager.enable = true;

  xdg = {
    enable = true;
    userDirs = {
      enable = true;
      createDirectories = true;
    };
  };
}
