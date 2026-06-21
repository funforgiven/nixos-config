{
  description = "Modular NixOS configuration for parmigiano";

  nixConfig = {
    extra-substituters = [ "https://noctalia.cachix.org" ];
    extra-trusted-public-keys = [
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    mcp-nixos = {
      url = "github:utensils/mcp-nixos";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Noctalia v5 docs recommend not following nixpkgs when using its Cachix.
    noctalia.url = "github:noctalia-dev/noctalia";

    noctalia-greeter = {
      url = "github:noctalia-dev/noctalia-greeter";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      disko,
      home-manager,
      noctalia-greeter,
      ...
    }:
    let
      system = "x86_64-linux";
      hostname = "parmigiano";
      username = "funforgiven";
    in
    {
      nixosConfigurations.${hostname} = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs self hostname username;
        };
        modules = [
          disko.nixosModules.disko
          home-manager.nixosModules.home-manager
          noctalia-greeter.nixosModules.default
          ./hosts/parmigiano
        ];
      };
    };
}
