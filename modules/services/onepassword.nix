{ options, config, lib, pkgs, ... }:

with lib;
with lib.my;
let cfg = config.modules.services.onepassword;
in
{
  options.modules.services.onepassword = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    programs = {
      _1password.enable = true;
      _1password-gui = {
        enable = true;
        polkitPolicyOwners = [ "funforgiven" ];
      };
    };

    home-manager.users.funforgiven = {
      home.sessionVariables.SSH_AUTH_SOCK = config.home-manager.users.funforgiven.home.homeDirectory + "/.1password/agent.sock";
      programs = {
        git = {
          enable = true;
          extraConfig = {
            user.signingkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK0BK7fG4KMymspDdwUu3qx6vRy7t7injE9GkpDFnv7+";
            gpg.format = "ssh";
            commit.gpgsign = true;
          };
        };
        ssh = {
          enable = true;
          extraConfig = "IdentityAgent ~/.1password/agent.sock";
        };
      };
    };
  };
}
