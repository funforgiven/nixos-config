_: {
  perSystem =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.repository.devShell.shellHook = lib.mkOption {
        type = lib.types.lines;
        default = "";
      };

      config = {
        devShells.default = pkgs.mkShellNoCC {
          packages = [
            config.files.writer.drv
            config.treefmt.build.wrapper
            pkgs.gitMinimal
            pkgs.nixd
          ];

          shellHook = config.repository.devShell.shellHook;
        };
      };
    };
}
