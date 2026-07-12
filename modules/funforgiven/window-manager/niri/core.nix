{ inputs, ... }:
let
  niriPackage =
    pkgs:
    pkgs.niri-unstable.overrideAttrs (previous: {
      patches = (previous.patches or [ ]) ++ [ ./patches/niri-focus-window-no-pointer-warp.patch ];
    });
in
{
  dendritic.nixpkgs.overlays = [ inputs.niri.overlays.niri ];

  homeManager.standaloneModules.niri.imports = [
    inputs.niri.homeModules.config
    inputs.niri.homeModules.stylix
  ];

  nixos.modules.niri =
    { pkgs, ... }:
    {
      imports = [ inputs.niri.nixosModules.niri ];

      programs.niri = {
        enable = true;
        package = niriPackage pkgs;
      };
    };

  home.gui =
    { lib, pkgs, ... }:
    {
      home.packages = [ pkgs.wl-clipboard ];

      programs.niri = {
        package = niriPackage pkgs;

        settings = {
          prefer-no-csd = true;
          screenshot-path = "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png";

          cursor = {
            hide-when-typing = true;
          };

          xwayland-satellite.path = lib.getExe pkgs.xwayland-satellite-unstable;
        };
      };
    };
}
