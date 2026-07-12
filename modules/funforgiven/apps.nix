_: {
  dendritic.nixpkgs.allowUnfreePackages = [
    "discord"
    "r2modman"
  ];

  home.gui =
    { pkgs, ... }:
    {
      home.packages = [
        pkgs.discord
        pkgs.ffmpegthumbnailer
        pkgs.telegram-desktop
        pkgs.kdePackages.ark
        pkgs.kdePackages.dolphin
        pkgs.kdePackages.dolphin-plugins
        pkgs.kdePackages.ffmpegthumbs
        pkgs.kdePackages.kio-extras
        pkgs.fastfetch
        pkgs.hayase
        pkgs.pavucontrol
        pkgs.qbittorrent
        pkgs.r2modman
      ];
    };
}
