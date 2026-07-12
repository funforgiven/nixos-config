_: {
  home.gui =
    { config, lib, ... }:
    let
      rawOutputs = lib.throwIfNot (
        config.dendritic.niri.outputs != null
      ) "The GUI profile requires host-specific Niri output facts." config.dendritic.niri.outputs;
      requiredRoles = [
        "primary"
        "secondary"
        "portrait"
      ];
      missingRoles = builtins.filter (role: !(builtins.hasAttr role rawOutputs)) requiredRoles;
      outputs =
        lib.throwIfNot (missingRoles == [ ])
          "The GUI profile is missing Niri output roles: ${lib.concatStringsSep ", " missingRoles}."
          rawOutputs;
      outputValues = builtins.attrValues outputs;
    in
    {
      assertions = [
        {
          assertion =
            lib.length (lib.unique (map (output: output.connector) outputValues)) == lib.length outputValues;
          message = "Niri runtime connector names must be unique.";
        }
        {
          assertion =
            lib.length (lib.unique (map (output: output.identifier) outputValues)) == lib.length outputValues;
          message = "Niri stable output identifiers must be unique.";
        }
        {
          assertion =
            outputs.primary.focusAtStartup && lib.count (output: output.focusAtStartup) outputValues == 1;
          message = "Exactly the primary Niri output must receive startup focus.";
        }
      ];

      programs.niri.settings.outputs = lib.mapAttrs' (
        _role: output:
        lib.nameValuePair output.identifier {
          inherit (output)
            mode
            position
            scale
            transform
            ;
          variable-refresh-rate = output.variableRefreshRate;
          focus-at-startup = output.focusAtStartup;
        }
      ) outputs;
    };
}
