_: {
  home.gui =
    { config, lib, ... }:
    let
      outputs = lib.throwIfNot (
        config.dendritic.niri.outputs != null
      ) "The GUI profile requires host-specific Niri output facts." config.dendritic.niri.outputs;
    in
    {
      programs.niri.settings.workspaces = {
        "01-discord" = {
          name = "discord";
          open-on-output = outputs.secondary.identifier;
        };
        "02-telegram" = {
          name = "telegram";
          open-on-output = outputs.portrait.identifier;
        };
        "03-steam" = {
          name = "steam";
          open-on-output = outputs.primary.identifier;
        };
        "04-passwords" = {
          name = "passwords";
          open-on-output = outputs.secondary.identifier;
        };
      };
    };
}
