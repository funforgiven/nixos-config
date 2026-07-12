{ config, lib, ... }:
let
  cfg = config.git.ignore;
in
{
  options.git.ignore = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    apply = lib.naturalSort;
  };

  config = {
    git.ignore = [
      "/.codex-doc-cache/"
      "/.direnv/"
      "/.envrc"
      "/hardware-configuration.nix"
      "/result"
      "/result-*"
      "/secrets/*.age"
      "/secrets/*.hash"
      "/secrets/*.key"
      "/secrets/*.pem"
    ];

    perSystem.files.file.".gitignore".text = lib.concatLines cfg;
  };
}
