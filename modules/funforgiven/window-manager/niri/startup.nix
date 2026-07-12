_: {
  home.gui =
    { lib, pkgs, ... }:
    let
      niriSessionService =
        {
          command,
          description,
        }:
        {
          Unit = {
            Description = description;
            PartOf = [ "graphical-session.target" ];
            After = [
              "graphical-session.target"
              "quickshell.service"
            ];
            Wants = [ "quickshell.service" ];
            Requisite = [ "graphical-session.target" ];
          };
          Service = {
            ExecStart = command;
            Slice = "app.slice";
            TimeoutStopSec = "20s";
          };
          Install.WantedBy = [ "graphical-session.target" ];
        };
    in
    {
      systemd.user.services = {
        discord = niriSessionService {
          description = "Discord";
          command = lib.getExe pkgs.discord;
        };

        telegram = niriSessionService {
          description = "Telegram Desktop";
          command = lib.getExe pkgs.telegram-desktop;
        };

        "1password" = niriSessionService {
          description = "1Password";
          command = "${lib.getExe pkgs._1password-gui} --silent";
        };

        steam = niriSessionService {
          description = "Steam";
          command = "${lib.getExe pkgs.steam} -silent";
        };
      };
    };
}
