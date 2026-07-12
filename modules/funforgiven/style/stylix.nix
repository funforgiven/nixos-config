{
  config,
  inputs,
  lib,
  ...
}:
{
  options.dendritic.wallpaper.path = lib.mkOption {
    type = lib.types.strMatching "/.*";
    readOnly = true;
    description = "Absolute path of the personal wallpaper locked by the flake.";
  };

  config = {
    dendritic.wallpaper.path = "${config.users.funforgiven.homeDirectory}/Pictures/Wallpapers/current.png";

    dendritic.stylix.commonModule =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        materialSchemeType = "scheme-tonal-spot";
        materialContrast = 0.0;
        materialColorType = lib.types.strMatching "^#[0-9a-fA-F]{6}$";
        requiredMaterialRoles = [
          "background"
          "error"
          "error_container"
          "on_background"
          "on_error_container"
          "on_primary"
          "on_primary_container"
          "on_secondary"
          "on_surface"
          "on_surface_variant"
          "outline"
          "outline_variant"
          "primary"
          "primary_container"
          "secondary"
          "shadow"
          "surface"
          "surface_container"
          "surface_container_high"
          "surface_container_highest"
          "surface_container_low"
          "surface_container_lowest"
          "tertiary"
        ];
        materialColorsType = lib.types.submodule {
          freeformType = lib.types.attrsOf materialColorType;
          options = lib.genAttrs requiredMaterialRoles (_: lib.mkOption { type = materialColorType; });
        };
        materialPaletteJson =
          pkgs.runCommandLocal "material-you-palette.json"
            {
              image = config.stylix.image;
              nativeBuildInputs = [
                pkgs.jq
                pkgs.matugen
              ];
            }
            ''
              ln -s "$image" wallpaper.png

              matugen image "$PWD/wallpaper.png" \
                --mode dark \
                --type ${materialSchemeType} \
                --contrast ${toString materialContrast} \
                --json hex \
                --dry-run \
                --source-color-index 0 \
                --old-json-output \
                --include-image-in-json=false \
                --quiet \
                > palette.json

              jq -e --argjson required_roles '${builtins.toJSON requiredMaterialRoles}' '
                . as $document
                | .is_dark_mode == true
                and .mode == "dark"
                and all(
                  $required_roles[];
                  . as $role
                  | (($document.colors[$role].dark // "") | test("^#[0-9a-fA-F]{6}$"))
                  and (($document.colors[$role].light // "") | test("^#[0-9a-fA-F]{6}$"))
                )
              ' palette.json >/dev/null

              mv palette.json "$out"
            '';
        materialDocument = lib.importJSON materialPaletteJson;
        materialColors = lib.mapAttrs (_: variants: variants.dark) materialDocument.colors;
        materialLightColors = lib.mapAttrs (_: variants: variants.light) materialDocument.colors;
        withoutHash = lib.removePrefix "#";
        materialBase16 = {
          scheme = "Material You Tonal Spot";
          author = "Matugen, adapted for Stylix";
          variant = "dark";
          x-material-you-json = materialPaletteJson;

          base00 = withoutHash materialColors.surface;
          base01 = withoutHash materialColors.surface_container_low;
          base02 = withoutHash materialColors.surface_container_high;
          base03 = withoutHash materialColors.outline;
          base04 = withoutHash materialColors.on_surface_variant;
          base05 = withoutHash materialColors.on_surface;
          base06 = withoutHash materialColors.on_background;
          base07 = withoutHash materialLightColors.background;

          base08 = withoutHash materialColors.error;
          base09 = withoutHash materialColors.primary;
          base0A = withoutHash materialColors.secondary;
          base0B = withoutHash materialColors.tertiary;
          base0C = withoutHash materialColors.on_surface_variant;
          base0D = withoutHash materialColors.primary;
          base0E = withoutHash materialColors.tertiary;
          base0F = withoutHash materialColors.secondary;
        };
      in
      {
        options.dendritic.materialYou = {
          schemeType = lib.mkOption {
            type = lib.types.enum [ materialSchemeType ];
            readOnly = true;
            description = "Matugen Material You scheme used by the desktop.";
          };
          contrast = lib.mkOption {
            type = lib.types.float;
            readOnly = true;
            description = "Matugen contrast level used by the desktop.";
          };
          generatedJson = lib.mkOption {
            type = lib.types.package;
            readOnly = true;
            internal = true;
            description = "Build-time Matugen Material You role document.";
          };
          colors = lib.mkOption {
            type = materialColorsType;
            readOnly = true;
            description = "Dark Material You semantic color roles.";
          };
        };

        config = {
          dendritic.materialYou = {
            schemeType = materialSchemeType;
            contrast = materialContrast;
            generatedJson = materialPaletteJson;
            colors = materialColors;
          };

          assertions = [
            {
              assertion = toString config.stylix.image == toString inputs.wallpaper;
              message = "Stylix and swaybg must use the locked XDG Pictures wallpaper input.";
            }
            {
              assertion = config.stylix.polarity == "dark";
              message = "The shared Stylix palette must remain dark regardless of wallpaper brightness.";
            }
            {
              assertion = config.dendritic.materialYou.schemeType == "scheme-tonal-spot";
              message = "The desktop must use DMS's readable tonal-spot Material You scheme.";
            }
            {
              assertion =
                config.stylix.base16Scheme.base00 == withoutHash config.dendritic.materialYou.colors.surface;
              message = "Stylix must bridge from the generated Material surface instead of its genetic wallpaper palette.";
            }
          ];

          stylix = {
            enable = true;
            autoEnable = false;
            image = inputs.wallpaper;
            imageScalingMode = "fill";
            base16Scheme = materialBase16;
            polarity = "dark";
            override.variant = "dark";

            cursor = {
              name = "Adwaita";
              package = pkgs.adwaita-icon-theme;
              size = 24;
            };

            fonts = {
              serif = {
                name = "DejaVu Serif";
                package = pkgs.dejavu_fonts;
              };
              sansSerif = {
                name = "Rubik";
                package = pkgs.rubik;
              };
              monospace = {
                name = "JetBrains Mono";
                package = pkgs.jetbrains-mono;
              };
              emoji = {
                name = "Noto Color Emoji";
                package = pkgs.noto-fonts-color-emoji;
              };
              sizes = {
                applications = 11;
                desktop = 11;
                popups = 11;
                terminal = 11;
              };
            };

            icons = {
              enable = true;
              package = pkgs.papirus-icon-theme;
              dark = "Papirus-Dark";
              light = "Papirus";
            };

            opacity = {
              applications = 1.0;
              desktop = 1.0;
              popups = 1.0;
              terminal = 0.96;
            };
          };
        };
      };

    home.gui.stylix.targets = {
      fish.enable = true;
      firefox = {
        enable = true;
        profileNames = [ "default" ];
        colorTheme.enable = true;
      };
      foot.enable = true;
      gtk.enable = true;
      lazygit.enable = true;
      niri.enable = true;
      qt.enable = false;
      starship.enable = true;
      zed.enable = true;
    };

    home.gui.imports = [
      (
        { config, ... }:
        {
          dconf.settings."org/gnome/desktop/interface"."color-scheme" = "prefer-dark";
          xdg.configFile."material-you/palette.json".source = config.stylix.base16Scheme.x-material-you-json;

          assertions = [
            {
              assertion = config.stylix.polarity == "dark" && config.lib.stylix.colors.scheme-variant == "dark";
              message = "The shared Stylix palette must use dark polarity and declare a dark variant for every wallpaper.";
            }
            {
              assertion =
                config.stylix.targets.firefox.enable
                && config.stylix.targets.firefox.colorTheme.enable
                && config.stylix.targets.firefox.profileNames == [ "default" ];
              message = "Firefox must receive the Stylix color theme on its declarative default profile.";
            }
            {
              assertion =
                config.stylix.targets.zed.enable
                &&
                  config.programs.zed-editor.userSettings.theme == "Base16 ${config.lib.stylix.colors.scheme-name}";
              message = "Zed must select the generated Stylix theme.";
            }
            {
              assertion = config.dconf.settings."org/gnome/desktop/interface"."color-scheme" == "prefer-dark";
              message = "The desktop appearance portal must advertise the shared dark theme.";
            }
          ];
        }
      )
    ];

    home.gui.xdg.configFile."gtk-3.0/gtk.css".force = true;
  };
}
