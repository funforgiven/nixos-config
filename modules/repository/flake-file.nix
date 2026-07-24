{
  config,
  inputs,
  ...
}:
let
  hostName = "parmigiano";
  wallpaperPath = config.dendritic.wallpaper.path;
in
{
  imports = [ inputs.flake-file.flakeModules.default ];

  flake-file = {
    description = "Dendritic NixOS configuration for ${hostName}";
    outputs = "inputs: import ./outputs.nix inputs";
    do-not-edit = "";

    nixConfig.warn-dirty = false;

    inputs = {
      nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

      nixpkgs-codex.url = "github:NixOS/nixpkgs/master";

      nixpkgs-prism.url = "github:NixOS/nixpkgs/241313f4e8e508cb9b13278c2b0fa25b9ca27163";

      sops-nix = {
        url = "github:Mic92/sops-nix";
        inputs.nixpkgs.follows = "nixpkgs";
      };

      flake-file.url = "github:denful/flake-file";

      files = {
        url = "github:mightyiam/files";
        flake = false;
      };

      flake-parts = {
        url = "github:hercules-ci/flake-parts";
        inputs.nixpkgs-lib.follows = "nixpkgs";
      };

      import-tree.url = "github:vic/import-tree";

      treefmt-nix = {
        url = "github:numtide/treefmt-nix";
        inputs.nixpkgs.follows = "nixpkgs";
      };

      home-manager = {
        url = "github:nix-community/home-manager";
        inputs.nixpkgs.follows = "nixpkgs";
      };

      niri = {
        url = "github:sodiboo/niri-flake";
        inputs.nixpkgs.follows = "nixpkgs";
      };

      stylix = {
        url = "github:nix-community/stylix";
        inputs.nixpkgs.follows = "nixpkgs";
      };

      wallpaper = {
        url = "path:${wallpaperPath}";
        flake = false;
      };

      disko = {
        url = "github:nix-community/disko";
        inputs.nixpkgs.follows = "nixpkgs";
      };

      mcp-nixos = {
        url = "github:utensils/mcp-nixos";
        inputs.nixpkgs.follows = "nixpkgs";
      };
    };
  };
}
