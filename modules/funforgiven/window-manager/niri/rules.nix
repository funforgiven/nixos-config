_: {
  home.gui = {
    programs.niri.settings.window-rules = [
      {
        matches = [
          {
            at-startup = true;
            app-id = "(?i)^discord$";
          }
        ];
        open-on-workspace = "discord";
        open-maximized = true;
      }
      {
        matches = [
          {
            at-startup = true;
            app-id = "^org\\.telegram\\.desktop$";
          }
        ];
        excludes = [
          {
            app-id = "^org\\.telegram\\.desktop$";
            title = "^Media viewer$";
          }
        ];
        open-on-workspace = "telegram";
        open-maximized = true;
      }
      {
        matches = [
          {
            app-id = "^org\\.telegram\\.desktop$";
            title = "^Media viewer$";
          }
        ];
        open-floating = true;
      }
      {
        matches = [
          {
            at-startup = true;
            app-id = "^steam$";
            title = "^Steam$";
          }
        ];
        open-on-workspace = "steam";
        open-maximized = true;
      }
      {
        matches = [
          {
            app-id = "^steam$";
            title = "^notificationtoasts";
          }
        ];
        open-floating = true;
        open-focused = false;
      }
      {
        matches = [
          {
            app-id = "(?i)^(1password|onepassword)$";
          }
        ];
        open-on-workspace = "passwords";
        open-maximized = true;
        block-out-from = "screencast";
      }
      {
        matches = [
          {
            app-id = "^firefox$";
            title = "^Picture-in-Picture$";
          }
        ];
        open-floating = true;
        default-column-width.fixed = 480;
        default-window-height.fixed = 270;
        default-floating-position = {
          x = 32;
          y = 32;
          relative-to = "bottom-left";
        };
      }
      {
        matches = [
          { app-id = "^steam_app_.*"; }
          { app-id = "^gamescope$"; }
        ];
        variable-refresh-rate = true;
      }
    ];
  };
}
