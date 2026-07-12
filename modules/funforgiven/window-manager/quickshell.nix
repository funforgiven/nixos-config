{
  config,
  lib,
  ...
}:
let
  shellConfigName = config.dendritic.quickshell.configName;
  quickshellWithPatches =
    pkgs: patches:
    pkgs.quickshell.overrideAttrs (previous: {
      patches = (previous.patches or [ ]) ++ patches;
    });
  globalQuickshellPatches = [
    ./quickshell/patches/quickshell-0.3-runtime-contracts.patch
  ];
  polkitQuickshellPatch = ./quickshell/polkit/quickshell-0.3-polkit-conversation.patch;
  thirdPartyNoticesText = config.repository.thirdPartyNotices;
  audioChannels = map (channel: {
    inherit (channel)
      bridgeName
      id
      initialGain
      isDefault
      label
      sinkName
      ;
  }) config.dendritic.audio.channels;
in
{
  options.dendritic.quickshell.configName = lib.mkOption {
    type = lib.types.strMatching "[A-Za-z0-9][A-Za-z0-9._-]*";
    default = "funforgiven-shell";
    description = "Shared immutable Quickshell configuration and IPC instance name.";
  };

  config.perSystem =
    { pkgs, ... }:
    let
      polkitPatches = globalQuickshellPatches ++ [ polkitQuickshellPatch ];
      polkitQuickshell = quickshellWithPatches pkgs polkitPatches;
      patchedSource = pkgs.applyPatches {
        name = "quickshell-0.3-polkit-contracts-source";
        src = pkgs.quickshell.src;
        patches = polkitPatches;
      };
    in
    {
      checks.quickshell-polkit-contracts =
        pkgs.runCommandLocal "quickshell-polkit-contracts"
          {
            nativeBuildInputs = [ pkgs.ripgrep ];
          }
          ''
            set -euo pipefail

            test -x ${polkitQuickshell}/bin/qs

            agent=${patchedSource}/src/services/polkit/agentimpl.cpp
            flow=${patchedSource}/src/services/polkit/flow.cpp
            listener=${patchedSource}/src/services/polkit/listener.cpp

            rg --fixed-strings --quiet 'if (!this->bActiveFlow.value())' "$agent"
            rg --fixed-strings --quiet 'finishAuthenticationRequest(AuthFlow* flow)' "$agent"
            rg --fixed-strings --quiet 'this->bActiveFlow.value() != flow' "$agent"
            rg --fixed-strings --quiet 'while (!this->queuedRequests.empty())' "$agent"
            rg --fixed-strings --quiet 'obj && !obj->isGroup()' "$agent"
            ! rg --fixed-strings --quiet 'this->queuedRequests.size() == 1' "$agent"

            rg --fixed-strings --quiet 'QObject::disconnect(this->currentSession, nullptr, this, nullptr)' "$flow"
            rg --fixed-strings --quiet 'this->currentSession->respond(value)' "$flow"
            rg --fixed-strings --quiet 'QTimer::singleShot(0, this' "$flow"
            rg --fixed-strings --quiet 'void AuthFlow::retryAuthentication()' "$flow"
            rg --fixed-strings --quiet 'this->sessionGeneration == completedGeneration' "$flow"
            rg --multiline --multiline-dotall --quiet \
              'void AuthFlow::cancelFromAgent\(\).*?this->currentSession->cancel\(\);.*?this->bIsCompleted = true;.*?this->bIsSuccessful = false;' \
              "$flow"
            rg --multiline --multiline-dotall --quiet \
              'void AuthFlow::cancelAuthenticationRequest\(\).*?this->currentSession->cancel\(\);.*?this->bIsCompleted = true;.*?this->bIsSuccessful = false;' \
              "$flow"

            rg --fixed-strings --quiet 'g_cancellable_disconnect(cancellable, handlerId)' "$listener"
            rg --fixed-strings --quiet 'g_idle_add_full(' "$listener"
            rg --fixed-strings --quiet 'new CancellationStatePtr(state)' "$listener"
            rg --fixed-strings --quiet 'state->request = nullptr' "$listener"
            rg --fixed-strings --quiet 'std::exchange(this->task, nullptr)' "$listener"
            rg --fixed-strings --quiet 'g_object_unref(task)' "$listener"
            rg --fixed-strings --quiet 'registration_generation' "$listener"
            rg --fixed-strings --quiet 'qs_polkit_agent_detach' "$listener"

            touch "$out"
          '';
    };

  config.home.gui =
    {
      config,
      pkgs,
      ...
    }:
    let
      configName = shellConfigName;
      outputs = lib.throwIfNot (
        config.dendritic.niri.outputs != null
      ) "Quickshell requires host-specific Niri output facts." config.dendritic.niri.outputs;
      primaryOutput = outputs.primary;
      polkitAgent = config.dendritic.polkit.agent;
      material = config.dendritic.materialYou.colors;
      clampByte = value: lib.max 0 (lib.min 255 value);
      colorChannels =
        color:
        let
          hex = lib.removePrefix "#" color;
        in
        assert builtins.stringLength hex == 6;
        map (offset: lib.fromHexString (builtins.substring offset 2 hex)) [
          0
          2
          4
        ];
      hexadecimalByte =
        value:
        let
          encoded = lib.toHexString (clampByte value);
        in
        if builtins.stringLength encoded == 1 then "0${encoded}" else encoded;
      rgbColor = channels: "#${lib.concatMapStrings hexadecimalByte channels}";
      mixColor =
        from: to: toPercent:
        let
          fromChannels = colorChannels from;
          toChannels = colorChannels to;
        in
        rgbColor (
          lib.imap0 (
            index: channel:
            builtins.div (channel * (100 - toPercent) + builtins.elemAt toChannels index * toPercent + 50) 100
          ) fromChannels
        );
      palette = rec {
        baseSurface = material.surface;
        elevatedSurface = material.surface_container_low;
        raisedSurface = material.surface_container;
        hoverSurface = material.surface_container_high;
        pressedSurface = material.surface_container_highest;
        selectedSurface = material.primary_container;

        primaryText = material.on_surface;
        secondaryText = material.on_surface_variant;
        tertiaryText = material.outline;
        disabledText = material.outline_variant;

        outline = material.outline_variant;
        outlineStrong = material.outline;

        inherit (material) error;
        errorText = material.on_error_container;
        errorSurface = material.error_container;
        warning = material.primary;
        warningText = material.on_primary_container;
        warningSurface = material.primary_container;
        success = mixColor "#54d39b" primaryText 12;
        successText = success;
        successSurface = mixColor baseSurface success 14;

        systemAccent = material.primary;
        accentText = material.on_primary;

        gameAccent = mixColor "#8bd450" primaryText 12;
        voiceAccent = mixColor "#5cadff" primaryText 12;
        musicAccent = mixColor "#f279c6" primaryText 12;
      };
      desktopFontSize = config.stylix.fonts.sizes.desktop;
      applicationFontSize = config.stylix.fonts.sizes.applications;
      audioControllerPackage = config.dendritic.audioControllerPackage;
      qmlString = builtins.toJSON;
      quickshellPackage = quickshellWithPatches pkgs (
        globalQuickshellPatches ++ lib.optional (polkitAgent == "quickshell") polkitQuickshellPatch
      );

      themeQml = pkgs.writeText "Theme.qml" ''
        pragma Singleton
        import QtQuick

        QtObject {
            readonly property color baseSurface: ${qmlString palette.baseSurface}
            readonly property color elevatedSurface: ${qmlString palette.elevatedSurface}
            readonly property color raisedSurface: ${qmlString palette.raisedSurface}
            readonly property color hoverSurface: ${qmlString palette.hoverSurface}
            readonly property color pressedSurface: ${qmlString palette.pressedSurface}
            readonly property color selectedSurface: ${qmlString palette.selectedSurface}

            readonly property color outline: ${qmlString palette.outline}
            readonly property color outlineStrong: ${qmlString palette.outlineStrong}
            readonly property color border: ${qmlString palette.outline}

            readonly property color primaryText: ${qmlString palette.primaryText}
            readonly property color secondaryText: ${qmlString palette.secondaryText}
            readonly property color tertiaryText: ${qmlString palette.tertiaryText}
            readonly property color disabledText: ${qmlString palette.disabledText}

            readonly property color error: ${qmlString palette.error}
            readonly property color errorText: ${qmlString palette.errorText}
            readonly property color errorSurface: ${qmlString palette.errorSurface}
            readonly property color warning: ${qmlString palette.warning}
            readonly property color warningText: ${qmlString palette.warningText}
            readonly property color warningSurface: ${qmlString palette.warningSurface}
            readonly property color success: ${qmlString palette.success}
            readonly property color successText: ${qmlString palette.successText}
            readonly property color successSurface: ${qmlString palette.successSurface}

            readonly property color systemAccent: ${qmlString palette.systemAccent}
            readonly property color gameAccent: ${qmlString palette.gameAccent}
            readonly property color voiceAccent: ${qmlString palette.voiceAccent}
            readonly property color musicAccent: ${qmlString palette.musicAccent}
            readonly property color accentText: ${qmlString palette.accentText}

            readonly property string sansFont: ${qmlString config.stylix.fonts.sansSerif.name}
            readonly property string monoFont: ${qmlString config.stylix.fonts.monospace.name}
            readonly property real desktopFontSize: ${toString desktopFontSize}
            readonly property real applicationFontSize: ${toString applicationFontSize}
            readonly property real captionFontSize: ${toString (lib.max 11 desktopFontSize)}
            readonly property real bodyFontSize: ${toString (lib.max 12 applicationFontSize)}
            readonly property real labelFontSize: ${toString (lib.max 12 desktopFontSize)}
            readonly property real titleFontSize: ${toString (lib.max 18 (applicationFontSize + 6))}
            readonly property real displayFontSize: ${toString (lib.max 24 (applicationFontSize + 12))}
            readonly property real lineHeightTight: 1.15
            readonly property real lineHeightNormal: 1.35

            readonly property int radiusXSmall: 6
            readonly property int radiusSmall: 10
            readonly property int radiusMedium: 16
            readonly property int radiusLarge: 24
            readonly property int radiusPill: 999
            readonly property int spacingXSmall: 4
            readonly property int spacingSmall: 8
            readonly property int spacingMedium: 12
            readonly property int spacingLarge: 16
            readonly property int spacingXLarge: 24
            readonly property int controlCompactSize: 36
            readonly property int controlSize: 40
            readonly property int controlLargeSize: 44
            readonly property int iconSmallSize: 16
            readonly property int iconMediumSize: 20
            readonly property int iconLargeSize: 24
            readonly property int outlineWidth: 1
            readonly property int focusRingWidth: 2

            readonly property int animationFast: 120
            readonly property int animationNormal: 180
            readonly property int animationSlow: 240
            readonly property int easingStandard: Easing.OutCubic
            readonly property int easingEmphasized: Easing.InOutCubic
            readonly property real subtleOverlayOpacity: 0.10
            readonly property real selectedOverlayOpacity: 0.16
            readonly property real pressedOverlayOpacity: 0.22
            readonly property real disabledOpacity: 0.42
            readonly property real pressedScale: 0.96
        }
      '';

      shellConfigQml = pkgs.writeText "ShellConfig.qml" ''
        pragma Singleton
        import QtQuick

        QtObject {
            readonly property string configName: ${qmlString configName}
            readonly property string dockOutput: ${qmlString primaryOutput.connector}
            readonly property string dockMode: "always-visible"
            readonly property string audioController: ${qmlString (lib.getExe' audioControllerPackage "funforgiven-audioctl")}
            readonly property string appLauncher: ${qmlString (lib.getExe pkgs.app2unit)}
            readonly property bool nativePolkitEnabled: ${
              if polkitAgent == "quickshell" then "true" else "false"
            }
            readonly property var audioChannels: ${builtins.toJSON audioChannels}
            readonly property var pinnedDesktopIds: [
                "firefox",
                "org.kde.dolphin",
                "org.telegram.desktop",
                "discord"
            ]
            readonly property var appIdAliases: ({
                "com.discordapp.Discord": "discord",
                "discord": "discord",
                "firefox": "firefox",
                "onepassword": "1password",
                "org.telegram.desktop": "org.telegram.desktop",
                "steam": "steam"
            })
        }
      '';

      thirdPartyNotices = pkgs.writeText "THIRD_PARTY_NOTICES.md" thirdPartyNoticesText;

      shellSource = pkgs.runCommandLocal "${configName}-source" { } ''
        mkdir -p "$out"
        cp --recursive ${./quickshell}/. "$out/"
        chmod --recursive u+w "$out"
        mkdir -p "$out/generated"
        install -m 0444 ${themeQml} "$out/generated/Theme.qml"
        install -m 0444 ${shellConfigQml} "$out/generated/ShellConfig.qml"
        install -m 0444 ${thirdPartyNotices} "$out/THIRD_PARTY_NOTICES.md"
      '';

      sessionPath = "/run/wrappers/bin:${config.home.profileDirectory}/bin:/run/current-system/sw/bin";
      dataDirs = lib.concatStringsSep ":" [
        "${config.home.profileDirectory}/share"
        "${config.home.homeDirectory}/.local/share/flatpak/exports/share"
        "/var/lib/flatpak/exports/share"
        "/run/current-system/sw/share"
      ];
    in
    {
      assertions = [
        {
          assertion = lib.getVersion pkgs.quickshell == "0.3.0";
          message = "The repository-owned shell is validated against Quickshell 0.3.0.";
        }
        {
          assertion = !config.services.mako.enable;
          message = "Mako must remain disabled; this desktop deliberately has no notification daemon.";
        }
        {
          assertion = !config.services.swaync.enable;
          message = "SwayNotificationCenter must remain disabled; this desktop deliberately has no notification daemon.";
        }
        {
          assertion = !(builtins.hasAttr "dank-material-shell" config.programs);
          message = "The DMS Home Manager module must remain absent after the Quickshell cutover.";
        }
        {
          assertion = !(builtins.hasAttr "DMS_DEFAULT_LAUNCH_PREFIX" config.home.sessionVariables);
          message = "DMS_DEFAULT_LAUNCH_PREFIX must remain absent after the Quickshell cutover.";
        }
        {
          assertion =
            !lib.hasInfix "dms" (lib.toLower (builtins.toJSON config.programs.niri.settings.spawn-at-startup));
          message = "Niri must not start DMS after the supervised Quickshell cutover.";
        }
      ];

      programs.quickshell = {
        enable = true;
        package = lib.mkForce quickshellPackage;
        activeConfig = configName;
        configs.${configName} = shellSource;
        systemd = {
          enable = true;
          target = "graphical-session.target";
        };
      };

      systemd.user.services.quickshell = {
        Unit = {
          ConditionEnvironment = [
            "WAYLAND_DISPLAY"
            "NIRI_SOCKET"
          ];
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
          Requisite = [ "graphical-session.target" ];
          Wants = [ "swayidle.service" ];
          X-Restart-Triggers = [ "${shellSource}" ];
        };

        Service = {
          ExecCondition = [ "${lib.getExe config.programs.niri.package} msg --json version" ];
          Environment = [
            "PATH=${sessionPath}"
            "XDG_DATA_DIRS=${dataDirs}"
            "XDG_CURRENT_DESKTOP=niri"
            "QT_QPA_PLATFORMTHEME=qt6ct"
            "XCURSOR_THEME=${config.stylix.cursor.name}"
            "XCURSOR_SIZE=${toString config.stylix.cursor.size}"
          ];
          PassEnvironment = [
            "WAYLAND_DISPLAY"
            "NIRI_SOCKET"
          ];
          Restart = "on-failure";
          RestartSec = 1;
          Slice = "app-graphical.slice";
          TimeoutStopSec = "10s";
        };
      };
    };
}
