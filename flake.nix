{
  description = "Funforgiven's NixOS config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs @ { self, nixpkgs, ... }:
    let
      inherit (lib.my) mapModulesRec mapHosts;

      system = "x86_64-linux";

      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [ self.overlay ];
      };

      lib = nixpkgs.lib.extend (self: super: {
        my = import ./lib { inherit pkgs inputs; lib = self; };
      });
    in
    {
      lib = lib.my;

      overlay = final: prev: {
        my = self.packages."${system}";
      };

      nixosModules = mapModulesRec ./modules import;

      nixosConfigurations = (mapHosts ./hosts { });

      packages."${system}" = import ./packages { inherit pkgs; };
    };
}
