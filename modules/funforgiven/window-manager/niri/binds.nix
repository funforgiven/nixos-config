{ config, ... }:
let
  quickshellConfigName = config.dendritic.quickshell.configName;
in
{
  home.gui =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      spawn = command: { action.spawn = command; };
      niriAction = action: { action.${action} = [ ]; };
      niriActionWith = action: argument: { action.${action} = argument; };
      mapActions = lib.mapAttrs (_: niriAction);
      quickshell = lib.getExe' config.programs.quickshell.package "qs";
      launcherCommand = [
        quickshell
        "-c"
        quickshellConfigName
        "ipc"
        "call"
        "launcher"
        "toggle"
      ];

      workspaceNumbers = lib.range 1 9;
      focusWorkspaceBinds = lib.listToAttrs (
        map (index: {
          name = "Mod+${toString index}";
          value = niriActionWith "focus-workspace" index;
        }) workspaceNumbers
      );
      moveWorkspaceBinds = lib.listToAttrs (
        map (index: {
          name = "Mod+Shift+${toString index}";
          value = niriActionWith "move-column-to-workspace" index;
        }) workspaceNumbers
      );
      alternateMoveWorkspaceBinds = lib.listToAttrs (
        map (index: {
          name = "Mod+Ctrl+${toString index}";
          value = niriActionWith "move-column-to-workspace" index;
        }) workspaceNumbers
      );
    in
    {
      programs.niri.settings.binds = {
        "Mod+D" = (niriAction "toggle-overview") // {
          repeat = false;
        };
        "Mod+Tab" = (niriAction "toggle-overview") // {
          repeat = false;
        };
        "Mod+Shift+Slash" = niriAction "show-hotkey-overlay";

        "Mod+T" = spawn (lib.getExe pkgs.foot);
        "Mod+Return" = spawn (lib.getExe pkgs.foot);
        "Mod+Shift+E" = niriAction "quit";

        "Mod+Q" = (niriAction "close-window") // {
          repeat = false;
        };
        "Mod+F" = niriAction "maximize-column";
        "Mod+Shift+F" = niriAction "fullscreen-window";
        "Mod+Ctrl+Shift+F" = niriAction "toggle-windowed-fullscreen";
        "Mod+Shift+T" = niriAction "toggle-window-floating";
        "Mod+Shift+V" = niriAction "switch-focus-between-floating-and-tiling";
        "Mod+W" = niriAction "toggle-column-tabbed-display";

        "Mod+Space" = (spawn launcherCommand) // {
          repeat = false;
        };

        "Mod+Home" = niriAction "focus-column-first";
        "Mod+End" = niriAction "focus-column-last";
        "Mod+Ctrl+Home" = niriAction "move-column-to-first";
        "Mod+Ctrl+End" = niriAction "move-column-to-last";

        "Mod+Page_Down" = niriAction "focus-workspace-down";
        "Mod+Page_Up" = niriAction "focus-workspace-up";
        "Mod+U" = niriAction "focus-workspace-down";
        "Mod+I" = niriAction "focus-workspace-up";
        "Mod+Ctrl+Down" = niriAction "move-column-to-workspace-down";
        "Mod+Ctrl+Up" = niriAction "move-column-to-workspace-up";
        "Mod+Ctrl+U" = niriAction "move-column-to-workspace-down";
        "Mod+Ctrl+I" = niriAction "move-column-to-workspace-up";
        "Mod+Shift+Page_Down" = niriAction "move-workspace-down";
        "Mod+Shift+Page_Up" = niriAction "move-workspace-up";
        "Mod+Shift+U" = niriAction "move-workspace-down";
        "Mod+Shift+I" = niriAction "move-workspace-up";

        "Mod+WheelScrollDown" = (niriAction "focus-workspace-down") // {
          cooldown-ms = 150;
        };
        "Mod+WheelScrollUp" = (niriAction "focus-workspace-up") // {
          cooldown-ms = 150;
        };
        "Mod+Ctrl+WheelScrollDown" = (niriAction "move-column-to-workspace-down") // {
          cooldown-ms = 150;
        };
        "Mod+Ctrl+WheelScrollUp" = (niriAction "move-column-to-workspace-up") // {
          cooldown-ms = 150;
        };
        "Mod+WheelScrollRight" = niriAction "focus-column-right";
        "Mod+WheelScrollLeft" = niriAction "focus-column-left";
        "Mod+Ctrl+WheelScrollRight" = niriAction "move-column-right";
        "Mod+Ctrl+WheelScrollLeft" = niriAction "move-column-left";
        "Mod+Shift+WheelScrollDown" = niriAction "focus-column-right";
        "Mod+Shift+WheelScrollUp" = niriAction "focus-column-left";
        "Mod+Ctrl+Shift+WheelScrollDown" = niriAction "move-column-right";
        "Mod+Ctrl+Shift+WheelScrollUp" = niriAction "move-column-left";

        "Mod+BracketLeft" = niriAction "consume-or-expel-window-left";
        "Mod+BracketRight" = niriAction "consume-or-expel-window-right";
        "Mod+Period" = niriAction "expel-window-from-column";

        "Mod+R" = niriAction "switch-preset-column-width";
        "Mod+Shift+R" = niriAction "switch-preset-window-height";
        "Mod+Ctrl+R" = niriAction "reset-window-height";
        "Mod+Ctrl+F" = niriAction "expand-column-to-available-width";
        "Mod+C" = niriAction "center-column";
        "Mod+Ctrl+C" = niriAction "center-visible-columns";
        "Mod+Minus" = niriActionWith "set-column-width" "-10%";
        "Mod+Equal" = niriActionWith "set-column-width" "+10%";
        "Mod+Shift+Minus" = niriActionWith "set-window-height" "-10%";
        "Mod+Shift+Equal" = niriActionWith "set-window-height" "+10%";

        "XF86Launch1" = niriAction "screenshot";
        "Ctrl+XF86Launch1" = niriAction "screenshot-screen";
        "Alt+XF86Launch1" = niriAction "screenshot-window";
        "Print" = niriAction "screenshot";
        "Ctrl+Print" = niriAction "screenshot-screen";
        "Alt+Print" = niriAction "screenshot-window";
        "Mod+Escape" = (niriAction "toggle-keyboard-shortcuts-inhibit") // {
          allow-inhibiting = false;
        };
      }
      // mapActions {
        "Mod+Left" = "focus-column-left";
        "Mod+Down" = "focus-window-down";
        "Mod+Up" = "focus-window-up";
        "Mod+Right" = "focus-column-right";
        "Mod+H" = "focus-column-left";
        "Mod+J" = "focus-window-down";
        "Mod+K" = "focus-window-up";
        "Mod+L" = "focus-column-right";

        "Mod+Shift+Left" = "move-column-left";
        "Mod+Shift+Down" = "move-window-down";
        "Mod+Shift+Up" = "move-window-up";
        "Mod+Shift+Right" = "move-column-right";
        "Mod+Shift+H" = "move-column-left";
        "Mod+Shift+J" = "move-window-down";
        "Mod+Shift+K" = "move-window-up";
        "Mod+Shift+L" = "move-column-right";

        "Mod+Ctrl+Left" = "focus-monitor-left";
        "Mod+Ctrl+Right" = "focus-monitor-right";
        "Mod+Ctrl+H" = "focus-monitor-left";
        "Mod+Ctrl+J" = "focus-monitor-down";
        "Mod+Ctrl+K" = "focus-monitor-up";
        "Mod+Ctrl+L" = "focus-monitor-right";

        "Mod+Ctrl+Shift+Left" = "move-column-to-monitor-left";
        "Mod+Ctrl+Shift+Down" = "move-column-to-monitor-down";
        "Mod+Ctrl+Shift+Up" = "move-column-to-monitor-up";
        "Mod+Ctrl+Shift+Right" = "move-column-to-monitor-right";
        "Mod+Ctrl+Shift+H" = "move-column-to-monitor-left";
        "Mod+Ctrl+Shift+J" = "move-column-to-monitor-down";
        "Mod+Ctrl+Shift+K" = "move-column-to-monitor-up";
        "Mod+Ctrl+Shift+L" = "move-column-to-monitor-right";
      }
      // focusWorkspaceBinds
      // moveWorkspaceBinds
      // alternateMoveWorkspaceBinds;
    };
}
