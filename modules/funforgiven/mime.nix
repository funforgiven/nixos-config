_: {
  home.gui =
    { pkgs, ... }:
    {
      xdg.mimeApps = {
        enable = true;

        defaultApplicationPackages = [
          pkgs.kdePackages.ark
        ];

        defaultApplications = {
          "application/json" = "dev.zed.Zed.desktop";
          "application/xhtml+xml" = "firefox.desktop";
          "application/x-bittorrent" = "org.qbittorrent.qBittorrent.desktop";
          "application/x-shellscript" = "dev.zed.Zed.desktop";
          "application/x-zerosize" = "dev.zed.Zed.desktop";
          "inode/directory" = "org.kde.dolphin.desktop";
          "text/html" = "firefox.desktop";
          "text/markdown" = "dev.zed.Zed.desktop";
          "text/plain" = "dev.zed.Zed.desktop";
          "x-scheme-handler/http" = "firefox.desktop";
          "x-scheme-handler/https" = "firefox.desktop";
          "x-scheme-handler/magnet" = "org.qbittorrent.qBittorrent.desktop";
        };
      };
    };
}
