{ config, ... }:
let
  physicalLayout = config.dendritic.input.physicalXkbLayout;
in
{
  config.home.gui =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      fcitxGroupName = "Turkish or Japanese";
      desiredFcitxGlobalOptions = {
        "Hotkey/TriggerKeys"."0" = "Control+space";
        Hotkey = {
          EnumerateWithTriggerKeys = false;
          EnumerateSkipFirst = true;
        };
        Behavior = {
          ActiveByDefault = false;
          ShareInputState = "All";
          PreeditEnabledByDefault = true;
          ShowInputMethodInformation = true;
          CompactInputMethodInformation = true;
          PreloadInputMethod = true;
        };
      };
      desiredFcitxProfile = {
        GroupOrder."0" = fcitxGroupName;
        "Groups/0" = {
          Name = fcitxGroupName;
          "Default Layout" = physicalLayout;
          DefaultIM = "mozc";
        };
        "Groups/0/Items/0".Name = "keyboard-${physicalLayout}";
        "Groups/0/Items/1" = {
          Name = "mozc";
          Layout = "us";
        };
      };
      niriKeyboard = config.programs.niri.settings.input.keyboard;
      niriBinds = config.programs.niri.settings.binds;
      niriHasLayoutSwitch = lib.any (
        bind:
        let
          action = bind.action or { };
        in
        builtins.isAttrs action && builtins.hasAttr "switch-layout" action
      ) (builtins.attrValues niriBinds);
      fcitxSettings = config.i18n.inputMethod.fcitx5.settings;
    in
    {
      assertions = [
        {
          assertion = niriKeyboard.xkb.layout == physicalLayout && !niriHasLayoutSwitch;
          message = "Niri must keep one fixed Turkish layout and must not own language-switching binds.";
        }
        {
          assertion = fcitxSettings.globalOptions == desiredFcitxGlobalOptions;
          message = "Fcitx must own one global binary Ctrl+Space Turkish/Mozc state.";
        }
        {
          assertion = fcitxSettings.inputMethod == desiredFcitxProfile;
          message = "Fcitx must expose exactly direct Turkish followed by Mozc with internal US romaji mapping.";
        }
      ];

      i18n.inputMethod = {
        enable = true;
        type = "fcitx5";

        fcitx5 = {
          addons = [ pkgs.fcitx5-mozc ];
          waylandFrontend = true;

          settings = {
            globalOptions = desiredFcitxGlobalOptions;
            inputMethod = desiredFcitxProfile;

            addons.mozc.globalSection = {
              InitialMode = "Hiragana";
              InputState = "All";
              Vertical = true;
            };
          };
        };
      };

      programs.niri.settings = {
        environment = {
          GLFW_IM_MODULE = "ibus";
          QT_IM_MODULE = "fcitx";
          QT_IM_MODULES = "wayland;fcitx";
          SDL_IM_MODULE = "fcitx";
          XMODIFIERS = "@im=fcitx";
        };

        input = {
          keyboard = {
            numlock = true;
            repeat-delay = 300;
            repeat-rate = 50;
            xkb.layout = physicalLayout;
          };

          mouse.accel-profile = "flat";
        };
      };

      home.sessionVariables = {
        QT_IM_MODULE = "fcitx";
        QT_IM_MODULES = "wayland;fcitx";
      };

      systemd.user.services.fcitx5-daemon = {
        Unit = {
          ConditionEnvironment = "WAYLAND_DISPLAY";
          Requisite = [ "graphical-session.target" ];
        };
        Service = {
          PassEnvironment = [ "WAYLAND_DISPLAY" ];
          Restart = "on-failure";
          RestartSec = "2s";
        };
      };

      xdg.configFile."autostart/org.fcitx.Fcitx5.desktop".text = ''
        [Desktop Entry]
        Hidden=true
      '';
    };
}
