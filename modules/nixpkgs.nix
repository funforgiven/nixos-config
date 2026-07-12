{
  config,
  inputs,
  lib,
  ...
}:
let
  cfg = config.dendritic.nixpkgs;

  mkPkgs =
    system:
    import inputs.nixpkgs {
      inherit system;
      config = cfg.effectiveConfig;
      overlays = [ config.flake.overlays.default ];
    };
in
{
  options.dendritic.nixpkgs = {
    config = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "nixpkgs config shared by generated package sets and lower-level configurations.";
    };

    allowUnfreePackages = lib.mkOption {
      type = lib.types.listOf lib.types.singleLineStr;
      default = [ ];
      description = "Unfree package names explicitly allowed by dendritic feature modules.";
    };

    effectiveConfig = lib.mkOption {
      type = lib.types.attrs;
      readOnly = true;
      description = "nixpkgs config after dendritic allowlist policy has been applied.";
    };

    overlays = lib.mkOption {
      type = lib.types.listOf lib.types.unspecified;
      default = [ ];
      description = "Overlays contributed by dendritic feature modules.";
    };
  };

  config = {
    dendritic.nixpkgs.effectiveConfig = cfg.config // {
      allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) cfg.allowUnfreePackages;
    };

    flake = {
      lib.mkPkgs = mkPkgs;
      overlays.default = lib.composeManyExtensions cfg.overlays;
    };

    perSystem =
      { system, ... }:
      let
        pkgs = mkPkgs system;
      in
      {
        _module.args.pkgs = pkgs;
        legacyPackages = pkgs;
      };
  };
}
