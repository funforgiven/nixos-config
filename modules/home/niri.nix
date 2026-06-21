{ pkgs, ... }:
{
  home.packages = with pkgs; [
    brightnessctl
    fuzzel
    playerctl
    swaylock
    wl-clipboard
    xwayland-satellite
  ];

  systemd.user.services.xwayland-satellite = {
    Unit = {
      Description = "Xwayland satellite for niri";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.xwayland-satellite}/bin/xwayland-satellite";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  xdg.configFile."niri/config.kdl".text = ''
    input {
        keyboard {
            xkb {
                layout "tr"
            }
            repeat-delay 600
            repeat-rate 25
            track-layout "global"
            numlock
        }

        touchpad {
            tap
            dwt
            natural-scroll
            click-method "clickfinger"
        }

        mouse {
        }

        workspace-auto-back-and-forth
        mod-key "Super"
    }

    layout {
        gaps 12
        center-focused-column "never"

        preset-column-widths {
            proportion 0.33333
            proportion 0.5
            proportion 0.66667
        }

        default-column-width { proportion 0.5; }

        focus-ring {
            width 3
            active-color "#7fc8ff"
            inactive-color "#505050"
        }

        border {
            off
        }
    }

    prefer-no-csd
    screenshot-path "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png"

    window-rule {
        geometry-corner-radius 20
        clip-to-geometry true
    }

    window-rule {
        match app-id="dev.noctalia.Noctalia.Settings"
        open-floating true
        default-column-width { fixed 1080; }
        default-window-height { fixed 920; }
    }

    window-rule {
        match app-id="^firefox$" title="^Picture-in-Picture$"
        open-floating true
    }

    layer-rule {
        match namespace="^noctalia-backdrop"
        place-within-backdrop true
    }

    debug {
        honor-xdg-activation-with-invalid-serial
    }

    binds {
        Mod+Shift+Slash { show-hotkey-overlay; }

        Mod+T hotkey-overlay-title="Open a Terminal: foot" { spawn "foot"; }
        Mod+Return hotkey-overlay-title="Open a Terminal: foot" { spawn "foot"; }
        Mod+D hotkey-overlay-title="Run an Application: fuzzel" { spawn "fuzzel"; }
        Super+Alt+L hotkey-overlay-title="Lock the Screen" { spawn "swaylock"; }

        Mod+Space hotkey-overlay-title="Noctalia Launcher" {
            spawn-sh "noctalia msg panel-toggle launcher";
        }
        Mod+S hotkey-overlay-title="Noctalia Control Center" {
            spawn-sh "noctalia msg panel-toggle control-center";
        }
        Mod+Comma hotkey-overlay-title="Noctalia Settings" {
            spawn-sh "noctalia msg settings-toggle";
        }

        XF86AudioRaiseVolume allow-when-locked=true { spawn-sh "noctalia msg volume-up"; }
        XF86AudioLowerVolume allow-when-locked=true { spawn-sh "noctalia msg volume-down"; }
        XF86AudioMute allow-when-locked=true { spawn-sh "noctalia msg volume-mute"; }
        XF86AudioMicMute allow-when-locked=true { spawn-sh "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"; }
        XF86MonBrightnessUp allow-when-locked=true { spawn-sh "noctalia msg brightness-up"; }
        XF86MonBrightnessDown allow-when-locked=true { spawn-sh "noctalia msg brightness-down"; }

        XF86AudioPlay allow-when-locked=true { spawn-sh "playerctl play-pause"; }
        XF86AudioPause allow-when-locked=true { spawn-sh "playerctl play-pause"; }
        XF86AudioStop allow-when-locked=true { spawn-sh "playerctl stop"; }
        XF86AudioPrev allow-when-locked=true { spawn-sh "playerctl previous"; }
        XF86AudioNext allow-when-locked=true { spawn-sh "playerctl next"; }

        Mod+O repeat=false { toggle-overview; }
        Mod+Q repeat=false { close-window; }

        Mod+Left { focus-column-left; }
        Mod+Down { focus-window-down; }
        Mod+Up { focus-window-up; }
        Mod+Right { focus-column-right; }
        Mod+H { focus-column-left; }
        Mod+J { focus-window-down; }
        Mod+K { focus-window-up; }
        Mod+L { focus-column-right; }

        Mod+Ctrl+Left { move-column-left; }
        Mod+Ctrl+Down { move-window-down; }
        Mod+Ctrl+Up { move-window-up; }
        Mod+Ctrl+Right { move-column-right; }
        Mod+Ctrl+H { move-column-left; }
        Mod+Ctrl+J { move-window-down; }
        Mod+Ctrl+K { move-window-up; }
        Mod+Ctrl+L { move-column-right; }

        Mod+Shift+Left { focus-monitor-left; }
        Mod+Shift+Down { focus-monitor-down; }
        Mod+Shift+Up { focus-monitor-up; }
        Mod+Shift+Right { focus-monitor-right; }
        Mod+Shift+H { focus-monitor-left; }
        Mod+Shift+J { focus-monitor-down; }
        Mod+Shift+K { focus-monitor-up; }
        Mod+Shift+L { focus-monitor-right; }

        Mod+Shift+Ctrl+Left { move-column-to-monitor-left; }
        Mod+Shift+Ctrl+Down { move-column-to-monitor-down; }
        Mod+Shift+Ctrl+Up { move-column-to-monitor-up; }
        Mod+Shift+Ctrl+Right { move-column-to-monitor-right; }
        Mod+Shift+Ctrl+H { move-column-to-monitor-left; }
        Mod+Shift+Ctrl+J { move-column-to-monitor-down; }
        Mod+Shift+Ctrl+K { move-column-to-monitor-up; }
        Mod+Shift+Ctrl+L { move-column-to-monitor-right; }

        Mod+Page_Down { focus-workspace-down; }
        Mod+Page_Up { focus-workspace-up; }
        Mod+U { focus-workspace-down; }
        Mod+I { focus-workspace-up; }
        Mod+Ctrl+Page_Down { move-column-to-workspace-down; }
        Mod+Ctrl+Page_Up { move-column-to-workspace-up; }
        Mod+Ctrl+U { move-column-to-workspace-down; }
        Mod+Ctrl+I { move-column-to-workspace-up; }

        Mod+Shift+Page_Down { move-workspace-down; }
        Mod+Shift+Page_Up { move-workspace-up; }
        Mod+Shift+U { move-workspace-down; }
        Mod+Shift+I { move-workspace-up; }

        Mod+1 { focus-workspace 1; }
        Mod+2 { focus-workspace 2; }
        Mod+3 { focus-workspace 3; }
        Mod+4 { focus-workspace 4; }
        Mod+5 { focus-workspace 5; }
        Mod+6 { focus-workspace 6; }
        Mod+7 { focus-workspace 7; }
        Mod+8 { focus-workspace 8; }
        Mod+9 { focus-workspace 9; }
        Mod+Ctrl+1 { move-column-to-workspace 1; }
        Mod+Ctrl+2 { move-column-to-workspace 2; }
        Mod+Ctrl+3 { move-column-to-workspace 3; }
        Mod+Ctrl+4 { move-column-to-workspace 4; }
        Mod+Ctrl+5 { move-column-to-workspace 5; }
        Mod+Ctrl+6 { move-column-to-workspace 6; }
        Mod+Ctrl+7 { move-column-to-workspace 7; }
        Mod+Ctrl+8 { move-column-to-workspace 8; }
        Mod+Ctrl+9 { move-column-to-workspace 9; }

        Mod+BracketLeft { consume-or-expel-window-left; }
        Mod+BracketRight { consume-or-expel-window-right; }
        Mod+R { switch-preset-column-width; }
        Mod+Shift+R { switch-preset-column-width-back; }
        Mod+Ctrl+Shift+R { switch-preset-window-height; }
        Mod+Ctrl+R { reset-window-height; }
        Mod+F { maximize-column; }
        Mod+Shift+F { fullscreen-window; }
        Mod+M { maximize-window-to-edges; }
        Mod+Ctrl+F { expand-column-to-available-width; }
        Mod+C { center-column; }
        Mod+Ctrl+C { center-visible-columns; }
        Mod+Minus { set-column-width "-10%"; }
        Mod+Equal { set-column-width "+10%"; }
        Mod+Shift+Minus { set-window-height "-10%"; }
        Mod+Shift+Equal { set-window-height "+10%"; }
        Mod+V { toggle-window-floating; }
        Mod+Shift+V { switch-focus-between-floating-and-tiling; }
        Mod+W { toggle-column-tabbed-display; }

        Print { screenshot; }
        Ctrl+Print { screenshot-screen; }
        Alt+Print { screenshot-window; }
        Mod+Escape allow-inhibiting=false { toggle-keyboard-shortcuts-inhibit; }
        Mod+Shift+E { quit; }
        Ctrl+Alt+Delete { quit; }
        Mod+Shift+P { power-off-monitors; }
    }
  '';
}
