{ inputs, ... }:
{
  home.gui =
    { config, lib, ... }:
    let
      inherit (inputs.niri.lib.kdl) leaf plain;
      cornerRadius = 16.0;
      settingsForRender = config.programs.niri.settings // {
        animations = removeAttrs config.programs.niri.settings.animations [ "shaders" ];
        cursor = removeAttrs config.programs.niri.settings.cursor [ "hide-on-key-press" ];
      };
      renderedSettings =
        (lib.evalModules {
          modules = [
            inputs.niri.lib.internal.settings-module
            { programs.niri.settings = settingsForRender; }
          ];
        }).config.programs.niri.config;
    in
    {
      programs.niri = {
        settings = {
          layout = {
            gaps = 4;
            focus-ring.enable = false;
            border = {
              enable = true;
              width = 2;
            };
          };

          window-rules = [
            {
              geometry-corner-radius = {
                top-left = cornerRadius;
                top-right = cornerRadius;
                bottom-right = cornerRadius;
                bottom-left = cornerRadius;
              };
              clip-to-geometry = true;
              tiled-state = true;
              draw-border-with-background = false;
            }
          ];
        };
        config = renderedSettings ++ [
          (plain "recent-windows" [
            (plain "highlight" [
              (leaf "corner-radius" cornerRadius)
            ])
          ])
        ];
      };
    };
}
