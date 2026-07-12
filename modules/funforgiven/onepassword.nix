_: {
  dendritic.nixpkgs.allowUnfreePackages = [
    "1password"
    "1password-cli"
    "1password-gui"
  ];

  nixos.modules.onepassword.imports = [
    (
      { config, ... }:
      {
        programs._1password.enable = true;

        programs._1password-gui = {
          enable = true;
          polkitPolicyOwners = [ config.dendritic.primaryUser.username ];
        };
      }

    )
  ];
  home.gui.imports = [
    (
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        onePasswordAgentSocket = "${config.home.homeDirectory}/.1password/agent.sock";
        signingKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHj9lWCKgMOZg6K1QzZvNH0QYY4m0lA0l6A+E4wVdVMT";
      in
      {
        home.file.".ssh/allowed_signers".text = ''
          ${config.programs.git.settings.user.email} ${signingKey}
        '';

        home.sessionVariables.SSH_AUTH_SOCK = onePasswordAgentSocket;

        programs.git = {
          signing = {
            format = "ssh";
            key = "key::${signingKey}";
            signByDefault = true;
            signer = lib.getExe' pkgs._1password-gui "op-ssh-sign";
          };
          settings.gpg.ssh.allowedSignersFile = "${config.home.homeDirectory}/.ssh/allowed_signers";
        };

        programs.ssh = {
          enable = true;
          enableDefaultConfig = false;
          settings."*" = {
            IdentityAgent = onePasswordAgentSocket;
          };
        };
      }

    )
  ];
}
