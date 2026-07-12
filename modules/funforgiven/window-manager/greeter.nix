_: {
  nixos.modules.niri-greeter =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      assertions = [
        {
          assertion = config.programs.niri.enable;
          message = "The Niri greetd session requires programs.niri.enable.";
        }
        {
          assertion = !(builtins.hasAttr "dank-material-shell" config.programs);
          message = "The DMS NixOS modules and greeter must remain absent after cutover.";
        }
      ];

      services = {
        displayManager.defaultSession = "niri";

        greetd = {
          enable = true;
          useTextGreeter = true;
          settings.default_session = {
            command = lib.escapeShellArgs [
              (lib.getExe pkgs.tuigreet)
              "--time"
              "--remember"
              "--asterisks"
              "--cmd"
              "${config.programs.niri.package}/bin/niri-session"
            ];
            user = "greeter";
          };
        };
      };
    };
}
