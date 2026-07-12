{ inputs, ... }:
let
  qtEnvironment = {
    QT_AUTO_SCREEN_SCALE_FACTOR = "1";
    QT_QPA_PLATFORM = "wayland;xcb";
    QT_QPA_PLATFORMTHEME = "qt5ct";
    QT_QPA_PLATFORMTHEME_QT6 = "qt6ct";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
  };
in
{
  nixos.modules.qt = {
    environment.sessionVariables = qtEnvironment;
  };

  home.gui =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      colors = config.dendritic.materialYou.colors;
      schemeId = "MaterialYou";
      schemeFileName = "${schemeId}.colors";
      qtctFileName = "${schemeId}.conf";
      role = name: colors.${name};
      rgb =
        name:
        let
          hex = lib.removePrefix "#" (role name);
        in
        lib.concatMapStringsSep "," (offset: toString (lib.fromHexString (builtins.substring offset 2 hex)))
          [
            0
            2
            4
          ];

      activeQtPalette = map role [
        "on_surface"
        "surface_container"
        "surface_container_highest"
        "surface_container_high"
        "surface_container_lowest"
        "outline_variant"
        "on_surface"
        "on_primary"
        "on_surface"
        "surface"
        "surface"
        "shadow"
        "primary"
        "on_primary"
        "tertiary"
        "secondary"
        "surface_container_low"
        "surface"
        "surface_container_high"
        "on_surface"
        "on_surface_variant"
        "primary"
      ];
      inactiveQtPalette = map role [
        "on_surface_variant"
        "surface_container"
        "surface_container_highest"
        "surface_container_high"
        "surface_container_lowest"
        "outline_variant"
        "on_surface_variant"
        "on_primary"
        "on_surface_variant"
        "surface"
        "surface"
        "shadow"
        "secondary"
        "on_secondary"
        "tertiary"
        "secondary"
        "surface_container_low"
        "surface"
        "surface_container_high"
        "on_surface_variant"
        "on_surface_variant"
        "secondary"
      ];
      disabledQtPalette = map role [
        "on_surface_variant"
        "surface_container_low"
        "surface_container_high"
        "surface_container"
        "surface_container_lowest"
        "outline_variant"
        "on_surface_variant"
        "on_surface_variant"
        "on_surface_variant"
        "surface"
        "surface"
        "shadow"
        "surface_container_highest"
        "on_surface_variant"
        "on_surface_variant"
        "on_surface_variant"
        "surface_container_low"
        "surface"
        "surface_container_high"
        "on_surface_variant"
        "on_surface_variant"
        "outline"
      ];
      qtctPalette = pkgs.writeText "material-you-qtct.conf" ''
        [ColorScheme]
        active_colors=${lib.concatStringsSep ", " activeQtPalette}
        disabled_colors=${lib.concatStringsSep ", " disabledQtPalette}
        inactive_colors=${lib.concatStringsSep ", " inactiveQtPalette}
      '';

      commonForeground = {
        DecorationFocus = rgb "primary";
        DecorationHover = rgb "primary";
        ForegroundActive = rgb "primary";
        ForegroundInactive = rgb "on_surface_variant";
        ForegroundLink = rgb "tertiary";
        ForegroundNegative = rgb "error";
        ForegroundNeutral = rgb "secondary";
        ForegroundNormal = rgb "on_surface";
        ForegroundPositive = rgb "tertiary";
        ForegroundVisited = rgb "secondary";
      };
      colorGroup =
        {
          backgroundAlternate,
          backgroundNormal,
        }:
        commonForeground
        // {
          BackgroundAlternate = rgb backgroundAlternate;
          BackgroundNormal = rgb backgroundNormal;
        };
      selectedForeground = lib.mapAttrs (_: _: rgb "on_primary") commonForeground;
      inactiveHeader = colorGroup {
        backgroundAlternate = "surface_container_low";
        backgroundNormal = "surface";
      };
      kdeColorSchemeSettings = {
        KDE.contrast = 4;
        General = {
          ColorScheme = schemeId;
          Name = "Material You";
        };
        "ColorEffects:Disabled" = {
          Color = rgb "on_surface_variant";
          ColorAmount = 0;
          ColorEffect = 0;
          ContrastAmount = 0.65;
          ContrastEffect = 1;
          IntensityAmount = 0.1;
          IntensityEffect = 2;
        };
        "ColorEffects:Inactive" = {
          ChangeSelectionColor = true;
          Color = rgb "outline";
          ColorAmount = 0.025;
          ColorEffect = 2;
          ContrastAmount = 0.1;
          ContrastEffect = 2;
          Enable = false;
          IntensityAmount = 0;
          IntensityEffect = 0;
        };
        "Colors:Button" = colorGroup {
          backgroundAlternate = "surface_container";
          backgroundNormal = "surface_container_high";
        };
        "Colors:Complementary" = colorGroup {
          backgroundAlternate = "surface_container_low";
          backgroundNormal = "surface";
        };
        "Colors:Header" = colorGroup {
          backgroundAlternate = "surface_container_low";
          backgroundNormal = "surface_container";
        };
        "Colors:Selection" = selectedForeground // {
          BackgroundAlternate = rgb "primary_container";
          BackgroundNormal = rgb "primary";
          DecorationFocus = rgb "primary";
          DecorationHover = rgb "primary";
        };
        "Colors:Tooltip" = colorGroup {
          backgroundAlternate = "surface_container";
          backgroundNormal = "surface_container_high";
        };
        "Colors:View" = colorGroup {
          backgroundAlternate = "surface_container_low";
          backgroundNormal = "surface";
        };
        "Colors:Window" = colorGroup {
          backgroundAlternate = "surface_container_low";
          backgroundNormal = "surface";
        };
        WM = {
          activeBackground = rgb "surface_container";
          activeBlend = rgb "on_surface";
          activeForeground = rgb "on_surface";
          inactiveBackground = rgb "surface";
          inactiveBlend = rgb "on_surface_variant";
          inactiveForeground = rgb "on_surface_variant";
        };
      };
      kdeGlobalsSettings = kdeColorSchemeSettings // {
        "Colors:Header" = kdeColorSchemeSettings."Colors:Header" // {
          Inactive = inactiveHeader;
        };
        UiSettings.ColorScheme = schemeId;
      };
      kdeColorScheme = pkgs.writeText schemeFileName ''
        ${lib.generators.toINI { } kdeColorSchemeSettings}
        [Colors:Header][Inactive]
        ${lib.generators.toKeyValue { } inactiveHeader}
      '';

      upstreamKvantumTemplate = builtins.readFile (inputs.stylix + "/modules/qt/kvconfig.mustache");
      upstreamItemView = ''
        [ItemView]
        inherits=PanelButtonCommand
        frame.element=itemview
        interior.element=itemview
        frame=true
        interior=true
        text.iconspacing=3
        text.press.color=#{{base05-hex}}
        text.toggle.color=#{{base05-hex}}
      '';
      materialItemView = ''
        [ItemView]
        inherits=PanelButtonCommand
        frame.element=itemview
        interior.element=itemview
        frame=true
        interior=true
        text.iconspacing=3
        text.press.color=#{{base00-hex}}
        text.toggle.color=#{{base00-hex}}
      '';
      kvantumTemplate = pkgs.writeText "material-you-kvantum.kvconfig.mustache" (
        assert lib.assertMsg (lib.hasInfix upstreamItemView upstreamKvantumTemplate)
          "The pinned Stylix Kvantum ItemView template changed; review the Material contrast override.";
        builtins.replaceStrings [ upstreamItemView ] [ materialItemView ] upstreamKvantumTemplate
      );
      kvantumConfig = config.lib.stylix.colors {
        template = kvantumTemplate;
        extension = ".kvconfig";
      };
      kvantumSvgTemplate = pkgs.writeText "material-you-kvantum.svg.mustache" (
        builtins.readFile (inputs.stylix + "/modules/qt/kvantum.svg.mustache")
      );
      kvantumSvg = config.lib.stylix.colors {
        template = kvantumSvgTemplate;
        extension = ".svg";
      };
      kvantumTheme = pkgs.runCommandLocal "material-you-kvantum" { } ''
        directory="$out/share/Kvantum/${schemeId}"
        mkdir --parents "$directory"
        cp ${kvantumConfig} "$directory/${schemeId}.kvconfig"
        cp ${kvantumSvg} "$directory/${schemeId}.svg"
      '';
      qtctSettings = palettePath: {
        Appearance = {
          color_scheme_path = palettePath;
          custom_palette = true;
          icon_theme = config.stylix.icons.dark;
          standard_dialogs = "xdgdesktopportal";
          style = "kvantum";
        };
        Fonts = {
          fixed = ''"${config.stylix.fonts.monospace.name},${toString config.stylix.fonts.sizes.applications}"'';
          general = ''"${config.stylix.fonts.sansSerif.name},${toString config.stylix.fonts.sizes.applications}"'';
        };
      };
      qt5ctPalettePath = "${config.xdg.configHome}/qt5ct/colors/${qtctFileName}";
      qt6ctPalettePath = "${config.xdg.configHome}/qt6ct/colors/${qtctFileName}";
    in
    {
      programs.niri.settings.environment = qtEnvironment;

      systemd.user.sessionVariables = removeAttrs qtEnvironment [
        "QT_QPA_PLATFORMTHEME"
      ];

      qt = {
        enable = true;
        platformTheme.name = "qtct";
        style = {
          name = null;
          package = [
            pkgs.libsForQt5.qtstyleplugin-kvantum
            pkgs.qt6Packages.qtstyleplugin-kvantum
          ];
        };
        qt5ctSettings = qtctSettings qt5ctPalettePath;
        qt6ctSettings = qtctSettings qt6ctPalettePath;
        kvantum = {
          enable = true;
          settings.General.theme = schemeId;
          themes = [ kvantumTheme ];
        };
        kde.settings.kdeglobals = kdeGlobalsSettings;
      };

      xdg.configFile = {
        "qt5ct/colors/${qtctFileName}".source = qtctPalette;
        "qt6ct/colors/${qtctFileName}".source = qtctPalette;
      };
      xdg.dataFile."color-schemes/${schemeFileName}".source = kdeColorScheme;

      assertions = [
        {
          assertion = !config.stylix.targets.qt.enable;
          message = "The focused Material Qt module must remain the sole Qt theme owner.";
        }
        {
          assertion = config.qt.style.name == null;
          message = "Qt style selection must stay in qtct; QT_STYLE_OVERRIDE is forbidden.";
        }
        {
          assertion = !(builtins.hasAttr "QT_STYLE_OVERRIDE" config.home.sessionVariables);
          message = "Home Manager must not export QT_STYLE_OVERRIDE.";
        }
        {
          assertion = !(builtins.hasAttr "QT_STYLE_OVERRIDE" config.systemd.user.sessionVariables);
          message = "The systemd user environment must not export QT_STYLE_OVERRIDE.";
        }
        {
          assertion =
            config.qt.qt5ctSettings.Appearance.color_scheme_path == qt5ctPalettePath
            && config.qt.qt6ctSettings.Appearance.color_scheme_path == qt6ctPalettePath;
          message = "Both qtct generations must consume their managed Material You palette.";
        }
        {
          assertion = config.qt.kde.settings.kdeglobals.UiSettings.ColorScheme == schemeId;
          message = "Dolphin and other KDE applications must select the managed Material You KColorScheme.";
        }
      ];
    };
}
