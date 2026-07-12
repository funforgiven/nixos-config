{
  config,
  inputs,
  lib,
  ...
}:
{
  perSystem =
    { pkgs, ... }:
    let
      hostName = "parmigiano";
      hostModel = config.dendritic.hosts.${hostName};
      userName = config.users.${hostModel.user}.username;
      homeConfigurationName = "${userName}@${hostName}";
      shellConfigName = config.dendritic.quickshell.configName;
      host = config.flake.nixosConfigurations.${hostName}.config;
      home = config.flake.homeConfigurations.${homeConfigurationName}.config;
      outputRoles = hostModel.niri.outputs;
      primaryOutput = outputRoles.primary;
      secondaryOutput = outputRoles.secondary;
      portraitOutput = outputRoles.portrait;
      shellConfig = home.programs.quickshell.configs.${shellConfigName};
      fcitxConfig = home.xdg.configFile.fcitx5.source;
      fcitxPackage = home.i18n.inputMethod.package;
      fcitxAutostartMask = home.xdg.configFile."autostart/org.fcitx.Fcitx5.desktop".source;
      firefoxColorStorage =
        home.home.file.".mozilla/firefox/default/browser-extension-data/FirefoxColor@mozilla.com/storage.js".source;
      firefoxUserJs = home.home.file.".mozilla/firefox/default/user.js".source;
      zedTheme = home.programs.zed-editor.themes.stylix;
      qt5ctPalette = home.xdg.configFile."qt5ct/colors/MaterialYou.conf".source;
      qt6ctPalette = home.xdg.configFile."qt6ct/colors/MaterialYou.conf".source;
      kdeColorScheme = home.xdg.dataFile."color-schemes/MaterialYou.colors".source;
      kvantumTheme = builtins.head home.qt.kvantum.themes;
      kvantumConfig = "${kvantumTheme}/share/Kvantum/MaterialYou/MaterialYou.kvconfig";
      kvantumSvg = "${kvantumTheme}/share/Kvantum/MaterialYou/MaterialYou.svg";
      qtThemeContract = ../funforgiven/style/QtThemeContract.mjs;
      expectedSwayidle = pkgs.swayidle.override { systemdSupport = false; };
      runtimeValidationScript = ../funforgiven/window-manager/runtime-validation.sh;
      audioGraphTests = ../audio-channels/tests;
      runtimeValidator = lib.findFirst (
        package: lib.getName package == "funforgiven-runtime-check"
      ) (throw "funforgiven-runtime-check is missing from ${homeConfigurationName}") home.home.packages;
      runtimeValidatorExecutable = lib.getExe' runtimeValidator "funforgiven-runtime-check";
      inherit (runtimeValidator) runtimeValidationExpected;
      evaluatedNiriExecutable = lib.getExe home.programs.niri.package;
      evaluatedQuickshellExecutable = "${home.programs.quickshell.package}/bin/.quickshell-wrapped";
      expectedNiriProbe = "${evaluatedNiriExecutable} msg --json version";
      niriCoreModule = ../funforgiven/window-manager/niri/core.nix;
      niriFocusPatch = ../funforgiven/window-manager/niri/patches/niri-focus-window-no-pointer-warp.patch;
      niriConfig = home.programs.niri.finalConfig;
      lowerNiriConfig = lib.toLower niriConfig;
      niriHasLayoutSwitch = lib.any (
        bind:
        let
          action = bind.action or { };
        in
        builtins.isAttrs action && builtins.hasAttr "switch-layout" action
      ) (builtins.attrValues home.programs.niri.settings.binds);
      contract = pkgs.writeText "funforgiven-desktop-runtime-contract.json" (
        builtins.toJSON {
          greetd = host.services.greetd.enable;
          defaultSession = host.services.displayManager.defaultSession;
          greeterCommand = host.services.greetd.settings.default_session.command;
          portalEnabled = host.xdg.portal.enable;
          fuseEnabled = host.programs.fuse.enable;
          fuse3WrapperConfigured = builtins.hasAttr "fusermount3" host.security.wrappers;
          fuse3WrapperSource =
            if builtins.hasAttr "fusermount3" host.security.wrappers then
              host.security.wrappers.fusermount3.source
            else
              "";

          quickshellEnabled = home.programs.quickshell.enable;
          quickshellSystemdEnabled = home.programs.quickshell.systemd.enable;
          quickshellUnit = home.systemd.user.services.quickshell;
          inherit expectedNiriProbe;
          quickshellDataDirs = lib.filter (
            value: lib.hasPrefix "XDG_DATA_DIRS=" value
          ) home.systemd.user.services.quickshell.Service.Environment;
          expectedQuickshellDataDirs =
            "XDG_DATA_DIRS=${home.home.profileDirectory}/share:"
            + "${home.home.homeDirectory}/.local/share/flatpak/exports/share:"
            + "/var/lib/flatpak/exports/share:/run/current-system/sw/share";
          idle = home.services.swayidle;
          idleUnit = home.systemd.user.services.swayidle;
          idlePackage = toString home.services.swayidle.package;
          expectedIdlePackage = toString expectedSwayidle;
          idleHasExecStartPre = builtins.hasAttr "ExecStartPre" home.systemd.user.services.swayidle.Service;
          idleExecStopPost = home.systemd.user.services.swayidle.Service.ExecStopPost or "";
          cursorHideAfterInactiveMs = home.programs.niri.settings.cursor.hide-after-inactive-ms;
          wallpaperUnit = home.systemd.user.services.swaybg;
          wallpaperImage = toString home.stylix.image;
          wallpaperInput = toString inputs.wallpaper;
          desktopTheme = {
            polarity = home.stylix.polarity;
            schemeVariant = home.lib.stylix.colors.scheme-variant;
            portalColorScheme = home.dconf.settings."org/gnome/desktop/interface"."color-scheme";
            material = {
              schemeType = home.dendritic.materialYou.schemeType;
              contrast = home.dendritic.materialYou.contrast;
              generatedJson = toString home.dendritic.materialYou.generatedJson;
              installedJson = toString home.xdg.configFile."material-you/palette.json".source;
              colors = home.dendritic.materialYou.colors;
              base16Surface = home.lib.stylix.colors.withHashtag.base00;
            };
            firefox = {
              targetEnabled = home.stylix.targets.firefox.enable;
              colorThemeEnabled = home.stylix.targets.firefox.colorTheme.enable;
              profileNames = home.stylix.targets.firefox.profileNames;
              websiteAppearance =
                home.programs.firefox.profiles.default.settings."layout.css.prefers-color-scheme.content-override";
              expectedTitle = "Stylix ${home.lib.stylix.colors.description}";
              extensionIds = map (
                extension: extension.addonId or ""
              ) home.programs.firefox.profiles.default.extensions.packages;
              expectedBackground = {
                r = home.lib.stylix.colors.base00-rgb-r;
                g = home.lib.stylix.colors.base00-rgb-g;
                b = home.lib.stylix.colors.base00-rgb-b;
              };
              storageForce =
                home.programs.firefox.profiles.default.extensions.settings."FirefoxColor@mozilla.com".force;
            };
            zed = {
              targetEnabled = home.stylix.targets.zed.enable;
              selectedTheme = home.programs.zed-editor.userSettings.theme;
              expectedTheme = "Base16 ${home.lib.stylix.colors.scheme-name}";
            };
            qt = {
              stylixTargetEnabled = home.stylix.targets.qt.enable;
              platformTheme = home.qt.platformTheme.name;
              styleName = home.qt.style.name;
              qt5ctStyle = home.qt.qt5ctSettings.Appearance.style;
              qt6ctStyle = home.qt.qt6ctSettings.Appearance.style;
              qt5ctPalettePath = home.qt.qt5ctSettings.Appearance.color_scheme_path;
              qt6ctPalettePath = home.qt.qt6ctSettings.Appearance.color_scheme_path;
              expectedQt5ctPalettePath = "${home.xdg.configHome}/qt5ct/colors/MaterialYou.conf";
              expectedQt6ctPalettePath = "${home.xdg.configHome}/qt6ct/colors/MaterialYou.conf";
              customQt5ctPalette = home.qt.qt5ctSettings.Appearance.custom_palette;
              customQt6ctPalette = home.qt.qt6ctSettings.Appearance.custom_palette;
              kvantumEnabled = home.qt.kvantum.enable;
              kvantumTheme = home.qt.kvantum.settings.General.theme;
              kdeGeneralScheme = home.qt.kde.settings.kdeglobals.General.ColorScheme;
              kdeUiScheme = home.qt.kde.settings.kdeglobals.UiSettings.ColorScheme;
              homeHasStyleOverride = builtins.hasAttr "QT_STYLE_OVERRIDE" home.home.sessionVariables;
              systemdHasStyleOverride = builtins.hasAttr "QT_STYLE_OVERRIDE" home.systemd.user.sessionVariables;
            };
          };
          forcedXdgTargets = lib.attrNames (lib.filterAttrs (_: file: file.force) home.xdg.configFile);
          nestedForcedXdgTargets = lib.attrNames (
            lib.filterAttrs (_: file: file.force) host.home-manager.users.${userName}.xdg.configFile
          );
          quickshellConfigName = shellConfigName;
          expectedLauncherCommand = [
            (lib.getExe' home.programs.quickshell.package "qs")
            "-c"
            shellConfigName
            "ipc"
            "call"
            "launcher"
            "toggle"
          ];
          launcherBind = home.programs.niri.settings.binds."Mod+Space";
          inherit niriHasLayoutSwitch;
          trayClientUnits = map (name: home.systemd.user.services.${name}) [
            "discord"
            "telegram"
            "1password"
            "steam"
          ];

          keyboard = home.programs.niri.settings.input.keyboard;
          niriEnvironment = home.programs.niri.settings.environment;
          pointerWarpEnabled = home.programs.niri.settings.input.warp-mouse-to-focus.enable;
          inputMethod = {
            enable = home.i18n.inputMethod.enable;
            type = home.i18n.inputMethod.type;
            package = toString home.i18n.inputMethod.package;
            addons = map lib.getName home.i18n.inputMethod.fcitx5.addons;
            waylandFrontend = home.i18n.inputMethod.fcitx5.waylandFrontend;
            globalOptions = home.i18n.inputMethod.fcitx5.settings.globalOptions;
            profile = home.i18n.inputMethod.fcitx5.settings.inputMethod;
            addonSettings = home.i18n.inputMethod.fcitx5.settings.addons;
            unit = home.systemd.user.services.fcitx5-daemon;
            sessionVariables = {
              inherit (home.home.sessionVariables)
                QT_IM_MODULE
                QT_IM_MODULES
                XMODIFIERS
                ;
            };
          };
          outputRoleNames = lib.attrNames outputRoles;
          primaryOutput = {
            inherit (primaryOutput) connector identifier;
            settings = home.programs.niri.settings.outputs.${primaryOutput.identifier};
          };
          secondaryOutput = {
            inherit (secondaryOutput) connector identifier;
            settings = home.programs.niri.settings.outputs.${secondaryOutput.identifier};
          };
          portraitOutput = {
            inherit (portraitOutput) connector identifier;
            settings = home.programs.niri.settings.outputs.${portraitOutput.identifier};
          };
          workspaceOutputs = lib.mapAttrs (
            _: workspace: workspace.open-on-output
          ) home.programs.niri.settings.workspaces;
          niriSpawn = home.programs.niri.settings.spawn-at-startup;
          niriDirectConfig = home.xdg.configFile.niri-config.enable;
          niriHasDms = lib.hasInfix "dms" lowerNiriConfig || lib.hasInfix "dank" lowerNiriConfig;
          niriHasInclude = lib.hasInfix "include" lowerNiriConfig;
          niriHasRecentWindows = lib.hasInfix "recent-windows" niriConfig;
          niriPackage = toString home.programs.niri.package;
          nestedNiriPackage = toString host.home-manager.users.${userName}.programs.niri.package;
          systemNiriPackage = toString host.programs.niri.package;

          hasDmsInput = builtins.hasAttr "dms" inputs;
          hasDmsNixosOption = builtins.hasAttr "dank-material-shell" host.programs;
          hasDmsHomeOption = builtins.hasAttr "dank-material-shell" home.programs;
          hasDmsEnvironment = builtins.hasAttr "DMS_DEFAULT_LAUNCH_PREFIX" home.home.sessionVariables;

          mako = home.services.mako.enable;
          swaync = home.services.swaync.enable;
          polkitSelection = host.dendritic.polkit.agent;
          kdePolkit = host.systemd.user.services.niri-flake-polkit.enable;
          nativePolkit = home.dendritic.polkit.agent == "quickshell";
          runtimeValidator = {
            executable = runtimeValidatorExecutable;
            expected = toString runtimeValidationExpected;
            expectedQuickshellExecutable = evaluatedQuickshellExecutable;
          };
        }
      );
    in
    {
      checks.desktop-runtime-contract =
        pkgs.runCommandLocal "funforgiven-desktop-runtime-contract-check"
          {
            nativeBuildInputs = [
              pkgs.bash
              pkgs.coreutils
              pkgs.gnugrep
              pkgs.jq
              pkgs.nodejs
              pkgs.ripgrep
              pkgs.shellcheck
            ];
          }
          ''
            set -euo pipefail

            jq -e '
              . as $contract
              | .greetd == true
              and .defaultSession == "niri"
              and (.greeterCommand | contains("tuigreet") and contains("niri-session"))
              and .portalEnabled == true
              and .fuseEnabled == true
              and .fuse3WrapperConfigured == true
              and (.fuse3WrapperSource | endswith("/bin/fusermount3"))
              and .quickshellEnabled == true
              and .quickshellSystemdEnabled == true
              and (.quickshellUnit.Unit.After | index("graphical-session.target") != null)
              and (.quickshellUnit.Unit.PartOf | index("graphical-session.target") != null)
              and (.quickshellUnit.Unit.Requisite | index("graphical-session.target") != null)
              and (.quickshellUnit.Unit.Wants | index("swayidle.service") != null)
              and (.quickshellUnit.Unit.ConditionEnvironment | sort) == ["NIRI_SOCKET", "WAYLAND_DISPLAY"]
              and (.quickshellUnit.Service.PassEnvironment | sort) == ["NIRI_SOCKET", "WAYLAND_DISPLAY"]
              and .quickshellUnit.Service.ExecCondition == [.expectedNiriProbe]
              and .quickshellUnit.Service.Restart == "on-failure"
              and (.quickshellUnit.Service.Environment | map(select(startswith("PATH="))) | length == 1)
              and (.quickshellUnit.Service.Environment | index("QT_QPA_PLATFORMTHEME=qt6ct") != null)
              and .quickshellDataDirs == [.expectedQuickshellDataDirs]
              and all(
                .trayClientUnits[];
                (.Unit.After | index("quickshell.service") != null)
                and (.Unit.Wants | index("quickshell.service") != null)
                and (.Unit.PartOf | index("graphical-session.target") != null)
                and (.Unit.Requisite | index("graphical-session.target") != null)
              )
              and .idle.enable == true
              and .idlePackage == .expectedIdlePackage
              and .idleHasExecStartPre == false
              and (.idleExecStopPost | endswith("ipc call amoled deactivate"))
              and .idle.extraArgs == ["-w"]
              and (.idle.timeouts | length == 1)
              and .idle.timeouts[0].timeout == 30
              and .cursorHideAfterInactiveMs == 30000
              and (.idle.timeouts[0].command | endswith("ipc call amoled activate"))
              and (.idle.timeouts[0].resumeCommand | endswith("ipc call amoled deactivate"))
              and (.idle.timeouts[0].command | contains("-c " + $contract.quickshellConfigName + " ipc call amoled activate"))
              and (.idle.timeouts[0].resumeCommand | contains("-c " + $contract.quickshellConfigName + " ipc call amoled deactivate"))
              and .launcherBind.repeat == false
              and .launcherBind.action.spawn == .expectedLauncherCommand
              and .niriHasLayoutSwitch == false
              and ([.idle.events[] | select(. != null)] | length == 0)
              and (([.idle.timeouts[].command, .idle.timeouts[].resumeCommand] | join(" ") | ascii_downcase)
                | test("swaylock|gtklock|hyprlock|suspend|dpms|power-off-monitors|lock[[:space:]]") | not)
              and (.idleUnit.Unit.After | index("quickshell.service") != null)
              and (.idleUnit.Unit.PartOf | index("quickshell.service") != null)
              and (.idleUnit.Unit.Requires | index("quickshell.service") != null)
              and .idleUnit.Service.ExecCondition == [.expectedNiriProbe]
              and .idleUnit.Service.Restart == "on-failure"
              and .wallpaperUnit.Unit.ConditionEnvironment == "WAYLAND_DISPLAY"
              and (.wallpaperUnit.Unit.After | index("graphical-session.target") != null)
              and (.wallpaperUnit.Unit.PartOf | index("graphical-session.target") != null)
              and (.wallpaperUnit.Unit.Requisite | index("graphical-session.target") != null)
              and (.wallpaperUnit.Unit."X-Restart-Triggers" | index($contract.wallpaperImage) != null)
              and (.wallpaperUnit.Install.WantedBy | index("graphical-session.target") != null)
              and (.wallpaperUnit.Service.ExecStart[0] | contains(" --image " + $contract.wallpaperImage + " --mode fill"))
              and .wallpaperUnit.Service.Restart == "on-failure"
              and .wallpaperImage == .wallpaperInput
              and .desktopTheme.polarity == "dark"
              and .desktopTheme.schemeVariant == "dark"
              and .desktopTheme.portalColorScheme == "prefer-dark"
              and .desktopTheme.material.schemeType == "scheme-tonal-spot"
              and .desktopTheme.material.contrast == 0
              and .desktopTheme.material.generatedJson == .desktopTheme.material.installedJson
              and .desktopTheme.material.colors.surface == .desktopTheme.material.base16Surface
              and (.desktopTheme.material.colors.surface | test("^#[0-9a-fA-F]{6}$"))
              and (.desktopTheme.material.colors.on_surface | test("^#[0-9a-fA-F]{6}$"))
              and (.desktopTheme.material.colors.primary | test("^#[0-9a-fA-F]{6}$"))
              and (.desktopTheme.material.colors.on_primary | test("^#[0-9a-fA-F]{6}$"))
              and .desktopTheme.firefox.targetEnabled == true
              and .desktopTheme.firefox.colorThemeEnabled == true
              and .desktopTheme.firefox.profileNames == ["default"]
              and .desktopTheme.firefox.websiteAppearance == 0
              and (.desktopTheme.firefox.extensionIds | index("FirefoxColor@mozilla.com") != null)
              and .desktopTheme.firefox.storageForce == true
              and .desktopTheme.zed.targetEnabled == true
              and .desktopTheme.zed.selectedTheme == .desktopTheme.zed.expectedTheme
              and .desktopTheme.qt.stylixTargetEnabled == false
              and .desktopTheme.qt.platformTheme == "qtct"
              and .desktopTheme.qt.styleName == null
              and .desktopTheme.qt.qt5ctStyle == "kvantum"
              and .desktopTheme.qt.qt6ctStyle == "kvantum"
              and .desktopTheme.qt.qt5ctPalettePath == .desktopTheme.qt.expectedQt5ctPalettePath
              and .desktopTheme.qt.qt6ctPalettePath == .desktopTheme.qt.expectedQt6ctPalettePath
              and .desktopTheme.qt.customQt5ctPalette == true
              and .desktopTheme.qt.customQt6ctPalette == true
              and .desktopTheme.qt.kvantumEnabled == true
              and .desktopTheme.qt.kvantumTheme == "MaterialYou"
              and .desktopTheme.qt.kdeGeneralScheme == "MaterialYou"
              and .desktopTheme.qt.kdeUiScheme == "MaterialYou"
              and .desktopTheme.qt.homeHasStyleOverride == false
              and .desktopTheme.qt.systemdHasStyleOverride == false
              and .forcedXdgTargets == ["gtk-3.0/gtk.css"]
              and .nestedForcedXdgTargets == ["gtk-3.0/gtk.css"]
              and .keyboard.xkb.layout == "tr"
              and .pointerWarpEnabled == false
              and .inputMethod.enable == true
              and .inputMethod.type == "fcitx5"
              and (.inputMethod.package | contains("fcitx5-with-addons"))
              and .inputMethod.addons == ["fcitx5-mozc"]
              and .inputMethod.waylandFrontend == true
              and .inputMethod.globalOptions."Hotkey/TriggerKeys"."0" == "Control+space"
              and .inputMethod.globalOptions.Hotkey.EnumerateWithTriggerKeys == false
              and .inputMethod.globalOptions.Hotkey.EnumerateSkipFirst == true
              and .inputMethod.globalOptions.Behavior.ActiveByDefault == false
              and .inputMethod.globalOptions.Behavior.ShareInputState == "All"
              and .inputMethod.profile == {
                GroupOrder: {"0": "Turkish or Japanese"},
                "Groups/0": {
                  Name: "Turkish or Japanese",
                  "Default Layout": "tr",
                  DefaultIM: "mozc"
                },
                "Groups/0/Items/0": {Name: "keyboard-tr"},
                "Groups/0/Items/1": {Name: "mozc", Layout: "us"}
              }
              and .inputMethod.addonSettings.mozc.globalSection.InitialMode == "Hiragana"
              and .inputMethod.addonSettings.mozc.globalSection.InputState == "All"
              and (.inputMethod.unit.Unit.After | index("graphical-session.target") != null)
              and (.inputMethod.unit.Unit.PartOf | index("graphical-session.target") != null)
              and (.inputMethod.unit.Unit.Requisite | index("graphical-session.target") != null)
              and .inputMethod.unit.Unit.ConditionEnvironment == "WAYLAND_DISPLAY"
              and (.inputMethod.unit.Install.WantedBy | index("graphical-session.target") != null)
              and (.inputMethod.unit.Service.ExecStart[0] | endswith("/bin/fcitx5"))
              and .inputMethod.unit.Service.Restart == "on-failure"
              and .inputMethod.sessionVariables.QT_IM_MODULE == "fcitx"
              and .inputMethod.sessionVariables.QT_IM_MODULES == "wayland;fcitx"
              and .inputMethod.sessionVariables.XMODIFIERS == "@im=fcitx"
              and .niriEnvironment.QT_IM_MODULE == "fcitx"
              and .niriEnvironment.QT_IM_MODULES == "wayland;fcitx"
              and .niriEnvironment.XMODIFIERS == "@im=fcitx"
              and .outputRoleNames == ["portrait", "primary", "secondary"]
              and .primaryOutput.connector == "DP-1"
              and (.primaryOutput.identifier | contains("PG27UCDM"))
              and .primaryOutput.settings.mode.width == 3840
              and .primaryOutput.settings.mode.height == 2160
              and .primaryOutput.settings.mode.refresh == 240
              and .primaryOutput.settings.scale == 1.5
              and .primaryOutput.settings.position == {x: 2560, y: 560}
              and .primaryOutput.settings."focus-at-startup" == true
              and .secondaryOutput.connector == "HDMI-A-2"
              and (.secondaryOutput.identifier | contains("XG27UCS"))
              and .secondaryOutput.settings.mode.refresh == 160.001
              and .secondaryOutput.settings.position == {x: 0, y: 100}
              and (.secondaryOutput.settings."focus-at-startup" // false) == false
              and .portraitOutput.connector == "HDMI-A-1"
              and .workspaceOutputs."01-discord" == .secondaryOutput.identifier
              and .workspaceOutputs."02-telegram" == .portraitOutput.identifier
              and .workspaceOutputs."03-steam" == .primaryOutput.identifier
              and .workspaceOutputs."04-passwords" == .secondaryOutput.identifier
              and .niriSpawn == []
              and .niriDirectConfig == true
              and .niriHasDms == false
              and .niriHasInclude == false
              and .niriHasRecentWindows == true
              and .niriPackage == .nestedNiriPackage
              and .niriPackage == .systemNiriPackage
              and .hasDmsInput == false
              and .hasDmsNixosOption == false
              and .hasDmsHomeOption == false
              and .hasDmsEnvironment == false
              and .mako == false
              and .swaync == false
              and ([.kdePolkit, .nativePolkit] | map(select(. == true)) | length == 1)
              and ((.polkitSelection == "kde") == .kdePolkit)
              and ((.polkitSelection == "quickshell") == .nativePolkit)
              and (.runtimeValidator.executable | endswith("/bin/funforgiven-runtime-check"))
            ' ${contract} >/dev/null

            shellcheck --shell=bash ${runtimeValidationScript}
            ! rg --fixed-strings --quiet -- '--args "$@"' ${runtimeValidationScript}
            rg --fixed-strings --quiet -- '-- "$@" \' ${runtimeValidationScript}
            test "$(${lib.getExe pkgs.jq} -nr --args '$ARGS.positional | join("|")' -- command --option)" = 'command|--option'
            node --test ${audioGraphTests}/graph-contract.test.mjs
            test -x ${runtimeValidatorExecutable}
            test -x ${evaluatedQuickshellExecutable}
            jq -e --arg executable ${lib.escapeShellArg evaluatedQuickshellExecutable} \
              '.quickshellExecutable == $executable' \
              ${runtimeValidationExpected} >/dev/null
            grep -Fq 'RUNTIME_VALIDATION_EXPECTED=' ${runtimeValidatorExecutable}
            grep -Fq 'RUNTIME_VALIDATION_GRAPH_CHECK=' ${runtimeValidatorExecutable}
            grep -Fq 'graph-contract.mjs' ${runtimeValidatorExecutable}

            grep -Fq 'readonly property string dockOutput: "DP-1"' \
              ${shellConfig}/generated/ShellConfig.qml
            ! rg --fixed-strings --quiet 'outputs.center' \
              ${../funforgiven/window-manager}
            grep -Fq 'niri-focus-window-no-pointer-warp.patch' \
              ${niriCoreModule}
            grep -Fq 'FocusWindow(id) is an IPC-only exact-window action' \
              ${niriFocusPatch}
            grep -Fq -- '-                    self.focus_window(&window);' \
              ${niriFocusPatch}
            grep -Fq -- '+                    self.niri.layout.activate_window(&window);' \
              ${niriFocusPatch}
            grep -Fq -- '+                    self.niri.layer_shell_on_demand_focus = None;' \
              ${niriFocusPatch}
            grep -Fq -- '+                    let pointer_location = pointer.current_location();' \
              ${niriFocusPatch}
            grep -Fq -- '+                    pointer.set_location(pointer_location);' \
              ${niriFocusPatch}
            grep -Fq 'FocusMonitor(output) is the IPC-only exact-output action' \
              ${niriFocusPatch}
            grep -Fq -- '-                    if !self.maybe_warp_cursor_to_focus_centered() {' \
              ${niriFocusPatch}
            grep -Fq -- '-                        self.move_cursor_to_output(&output);' \
              ${niriFocusPatch}
            ! grep -Eq '^\+.*move_cursor' ${niriFocusPatch}
            ! test -e ${shellConfig}/bar/KeyboardLayout.qml
            ! grep -Fq 'KeyboardLayout' ${shellConfig}/bar/Bar.qml
            ! grep -Fq 'KeyboardLayout' ${shellConfig}/bar/qmldir
            ! grep -Fq 'keyboardLabels' ${shellConfig}/generated/ShellConfig.qml
            grep -Fq 'function activate(): void' ${shellConfig}/idle/AmoledOverlay.qml
            grep -Fq 'function deactivate(): void' ${shellConfig}/idle/AmoledOverlay.qml
            ! grep -Fq 'function show(): void' ${shellConfig}/idle/AmoledOverlay.qml
            ! grep -Fq 'function hide(): void' ${shellConfig}/idle/AmoledOverlay.qml
            grep -Fq 'exclusionMode: ExclusionMode.Ignore' ${shellConfig}/idle/AmoledOverlay.qml
            ! grep -Fq 'exclusiveZone:' ${shellConfig}/idle/AmoledOverlay.qml
            grep -Fq 'WlrLayershell.layer: WlrLayer.Overlay' ${shellConfig}/idle/AmoledOverlay.qml
            grep -Fq 'WlrLayershell.keyboardFocus: WlrKeyboardFocus.None' ${shellConfig}/idle/AmoledOverlay.qml
            grep -Fq 'mask: Region {}' ${shellConfig}/idle/AmoledOverlay.qml
            grep -Fq 'trayDelegate.trayItem.activate();' ${shellConfig}/bar/Tray.qml
            grep -Fq 'trayDelegate.showMenu();' ${shellConfig}/bar/Tray.qml
            grep -Fqx '0=Control+space' ${fcitxConfig}/config
            grep -Fqx 'EnumerateSkipFirst=True' ${fcitxConfig}/config
            grep -Fqx 'EnumerateWithTriggerKeys=False' ${fcitxConfig}/config
            grep -Fqx '0=Turkish or Japanese' ${fcitxConfig}/profile
            grep -Fqx 'Name=Turkish or Japanese' ${fcitxConfig}/profile
            grep -Fqx 'DefaultIM=mozc' ${fcitxConfig}/profile
            grep -Fqx 'Name=keyboard-tr' ${fcitxConfig}/profile
            grep -Fqx 'Name=mozc' ${fcitxConfig}/profile
            grep -Fqx 'Layout=us' ${fcitxConfig}/profile
            test "$(grep -Ec '^\[Groups/0/Items/[0-9]+\]$' ${fcitxConfig}/profile)" -eq 2
            grep -Fqx 'InitialMode=Hiragana' ${fcitxConfig}/conf/mozc.conf
            test -f ${fcitxPackage}/share/fcitx5/inputmethod/mozc.conf
            grep -Fqx 'Hidden=true' ${fcitxAutostartMask}
            jq -e --slurpfile contract ${contract} '
              .firstRunDone == true
              and .theme.title == $contract[0].desktopTheme.firefox.expectedTitle
              and .theme.colors.ntp_background == $contract[0].desktopTheme.firefox.expectedBackground
            ' ${firefoxColorStorage} >/dev/null
            grep -Fqx 'user_pref("layout.css.prefers-color-scheme.content-override", 0);' \
              ${firefoxUserJs}
            jq -e --slurpfile contract ${contract} '
              .name == $contract[0].desktopTheme.zed.expectedTheme
              and (.themes | length == 1)
              and .themes[0].name == $contract[0].desktopTheme.zed.expectedTheme
              and .themes[0].appearance == "dark"
            ' ${zedTheme} >/dev/null
            node ${qtThemeContract} \
              ${home.dendritic.materialYou.generatedJson} \
              ${qt6ctPalette} \
              ${kdeColorScheme} \
              ${kvantumConfig} \
              ${kvantumSvg}
            cmp ${qt5ctPalette} ${qt6ctPalette}

            proc_root="$TMPDIR/proc"
            mkdir -p "$proc_root/4201" "$proc_root/4202" "$proc_root/4203" "$proc_root/4204" "$proc_root/4205" "$proc_root/4301"
            printf '%s\0%s\0' \
              '/nix/store/fallback/bin/polkit-kde-authentication-agent-1' \
              '--fallback-argv' \
              >"$proc_root/4201/cmdline"
            ln -s \
              '/nix/store/readlink/bin/.hyprpolkitagent-wrapped' \
              "$proc_root/4202/exe"
            printf '%s\0' '/nix/store/ignored/bin/not-an-agent' \
              >"$proc_root/4202/cmdline"
            printf '%s\0' '/nix/store/ignored/bin/not-an-agent' \
              >"$proc_root/4203/cmdline"
            printf '%s\n' 'polkit-gnome-au' >"$proc_root/4204/comm"
            printf '%s\n' 'lxqt-policykit-' >"$proc_root/4205/comm"
            ln -s '/nix/store/evaluated-niri/bin/niri' "$proc_root/4301/exe"

            RUNTIME_VALIDATION_PROC_ROOT="$proc_root" \
              RUNTIME_VALIDATION_POLKIT_SCAN_ONLY=true \
              ${pkgs.bash}/bin/bash ${runtimeValidationScript} \
              >"$TMPDIR/polkit-processes.tsv"

            test "$(wc -l <"$TMPDIR/polkit-processes.tsv")" -eq 4
            grep -Fqx $'4201\tpolkit-kde-authentication-agent-1\t/nix/store/fallback/bin/polkit-kde-authentication-agent-1' \
              "$TMPDIR/polkit-processes.tsv"
            grep -Fqx $'4202\thyprpolkitagent\t/nix/store/readlink/bin/.hyprpolkitagent-wrapped' \
              "$TMPDIR/polkit-processes.tsv"
            grep -Fqx $'4204\tunreadable:polkit-gnome-au\tunreadable' \
              "$TMPDIR/polkit-processes.tsv"
            grep -Fqx $'4205\tunreadable:lxqt-policykit-\tunreadable' \
              "$TMPDIR/polkit-processes.tsv"

            RUNTIME_VALIDATION_PROC_ROOT="$proc_root" \
              RUNTIME_VALIDATION_NIRI_SCAN_ONLY=true \
              RUNTIME_VALIDATION_NIRI_SOCKET='/run/user/1000/niri.wayland-1.4301.sock' \
              ${pkgs.bash}/bin/bash ${runtimeValidationScript} \
              >"$TMPDIR/niri-processes.tsv"

            grep -Fqx $'4301\t/nix/store/evaluated-niri/bin/niri' \
              "$TMPDIR/niri-processes.tsv"
            grep -Fq 'and $polkitProcesses[0].pid == $services.kdePolkitPid' \
              ${runtimeValidationScript}
            grep -Fq 'current session runs the evaluated Niri' \
              ${runtimeValidationScript}
            grep -Fq 'QT_STYLE_OVERRIDE) has_qt_style_override=true' \
              ${runtimeValidationScript}
            grep -Fq 'and $niriProcesses[0].executable == $expected.niriExecutable' \
              ${runtimeValidationScript}
            grep -Fq 'shell playback model matches PipeWire application nodes' \
              ${runtimeValidationScript}
            grep -Fq 'isStream: node.isStream' \
              ${shellConfig}/services/AudioService.qml
            grep -Fq 'select((.info.props["funforgiven.audio.kind"] // "") != "bridge")' \
              ${runtimeValidationScript}
            test "$(grep -Fc 'select((.info.props["stream.monitor"] | property_is_true) | not)' \
              ${runtimeValidationScript})" -eq 2
            test "$(grep -Fc 'select((.info.props["node.monitor"] | property_is_true) | not)' \
              ${runtimeValidationScript})" -eq 2
            test "$(grep -Fc 'test("(^|[._-])monitor($|[._-])"; "i")' \
              ${runtimeValidationScript})" -eq 2
            grep -Fq 'journalctl --user --boot=0 "_PID=$pid"' \
              ${runtimeValidationScript}
            grep -Fq 'current Quickshell process has no QML runtime errors' \
              ${runtimeValidationScript}
            grep -Fq 'single Fcitx Turkish/Japanese state' \
              ${runtimeValidationScript}
            grep -Fq 'Failed to load configuration|Invalid property assignment| is not a type|TypeError|ReferenceError|Binding loop detected|Cannot read property [^ ]+ of null|Cannot anchor to an item' \
              ${runtimeValidationScript}

            mkdir -p "$out"
            install -m 0444 ${contract} "$out/contract.json"
          '';
    };
}
