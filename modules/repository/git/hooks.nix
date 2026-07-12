{ inputs, ... }:
{
  imports = [ "${inputs.git-hooks}/flake-module.nix" ];

  flake-file.inputs.git-hooks = {
    url = "github:cachix/git-hooks.nix";
    flake = false;
  };

  git.ignore = [ "/.pre-commit-config.yaml" ];

  perSystem =
    { config, ... }:
    {
      pre-commit.check.enable = false;
      repository.devShell.shellHook = config.pre-commit.installationScript;
    };
}
