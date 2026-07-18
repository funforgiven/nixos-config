_: {
  dendritic.nixpkgs.allowUnfreePackages = [ "1password" ];

  nixos.modules.onepassword.imports = [
    (
      { config, ... }:
      {
        programs._1password-gui = {
          enable = true;
          polkitPolicyOwners = [ config.dendritic.primaryUser.username ];
        };
      }

    )
  ];
}
