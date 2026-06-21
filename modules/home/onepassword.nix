{ config, ... }:
let
  onePasswordAgentSocket = "${config.home.homeDirectory}/.1password/agent.sock";
in
{
  home.sessionVariables.SSH_AUTH_SOCK = onePasswordAgentSocket;

  programs.ssh = {
    enable = true;
    extraConfig = ''
      Host *
          IdentityAgent ${onePasswordAgentSocket}
    '';
  };
}
