{ inputs, ... }:
{
  imports = [ inputs.treefmt-nix.flakeModule ];

  perSystem.treefmt = {
    settings.excludes = [ "flake.lock" ];

    programs = {
      deadnix.enable = true;
      nixfmt.enable = true;
      qmlformat.enable = true;
      statix.enable = true;
    };
  };

  perSystem.pre-commit.settings.hooks.treefmt.enable = true;
}
