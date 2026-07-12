{ inputs, lib, ... }:
{
  imports = [ "${inputs.files}/flake-module.nix" ];

  perSystem = psArgs: {
    options.text = lib.mkOption {
      default = { };
      type = lib.types.lazyAttrsOf (
        lib.types.oneOf [
          lib.types.lines
          (lib.types.submodule {
            options = {
              parts = lib.mkOption {
                type = lib.types.lazyAttrsOf lib.types.lines;
                default = { };
              };

              order = lib.mkOption {
                type = lib.types.listOf lib.types.singleLineStr;
                default = [ ];
              };
            };
          })
        ]
      );
      apply = lib.mapAttrs (
        name: text:
        if lib.isAttrs text then
          let
            partNames = builtins.attrNames text.parts;
            duplicateParts = lib.unique (
              builtins.filter (part: lib.count (candidate: candidate == part) text.order > 1) text.order
            );
            missingParts = builtins.filter (part: !(builtins.elem part text.order)) partNames;
            unknownParts = lib.unique (builtins.filter (part: !(builtins.hasAttr part text.parts)) text.order);
            renderParts = parts: if parts == [ ] then "<none>" else lib.concatStringsSep ", " parts;
            validOrder = duplicateParts == [ ] && missingParts == [ ] && unknownParts == [ ];
          in
          lib.throwIfNot validOrder ''
            Generated text '${name}' has an invalid part order.
            Duplicate parts: ${renderParts duplicateParts}
            Missing parts: ${renderParts missingParts}
            Unknown parts: ${renderParts unknownParts}
          '' (lib.concatMapStrings (part: text.parts.${part}) text.order)
        else
          text
      );
    };

    config = {
      treefmt.settings.excludes = lib.attrNames psArgs.config.files.file;
      files.writer.app = true;
    };
  };
}
