_:
let
  features = [
    "boot"
    "efi"
    "disko"
    "parmigiano-disko"
    "firmware"
    "parmigiano-hardware"
    "amd-desktop"
    "amd-x3d"
    "gpu"
    "nvidia"
    "funforgiven-locale"
    "funforgiven-time"
    "networking"
    "nix"
    "funforgiven-account"
    "funforgiven-secrets"
    "sudo"
    "fish"
    "udisks"
    "zed"
    "power"
    "session-shutdown"
    "storage"
    "zram"
    "audio"
    "audio-channels"
    "fonts"
    "funforgiven-input"
    "session-env"
    "niri-portals"
    "qt"
    "firefox"
    "onepassword"
    "syncthing"
    "gaming"
    "niri"
    "niri-greeter"
    "polkit-agent"
    "stylix"
  ];
in
{
  dendritic = {
    hosts.parmigiano = {
      system = "x86_64-linux";
      stateVersion = "25.11";
      user = "funforgiven";
      homeProfiles = [
        "base"
        "gui"
      ];
      inherit features;

      niri.outputs = {
        primary = {
          connector = "DP-1";
          identifier = "ASUSTek COMPUTER INC PG27UCDM T1LMAS011449";
          mode = {
            width = 3840;
            height = 2160;
            refresh = 240.000;
          };
          scale = 1.5;
          position = {
            x = 2560;
            y = 560;
          };
          transform.rotation = 0;
          variableRefreshRate = "on-demand";
          focusAtStartup = true;
        };

        secondary = {
          connector = "HDMI-A-2";
          identifier = "ASUSTek COMPUTER INC XG27UCS S4LMTF194503";
          mode = {
            width = 3840;
            height = 2160;
            refresh = 160.001;
          };
          scale = 1.5;
          position = {
            x = 0;
            y = 100;
          };
          transform.rotation = 0;
          variableRefreshRate = "on-demand";
          focusAtStartup = false;
        };

        portrait = {
          connector = "HDMI-A-1";
          identifier = "ASUSTek COMPUTER INC XG27UCS S4LMTF194498";
          mode = {
            width = 3840;
            height = 2160;
            refresh = 160.001;
          };
          scale = 1.5;
          position = {
            x = 5120;
            y = -490;
          };
          transform.rotation = 90;
          variableRefreshRate = "on-demand";
          focusAtStartup = false;
        };
      };

      polkit.agent = "kde";
    };
  };
}
