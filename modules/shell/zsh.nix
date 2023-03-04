{ options, config, pkgs, lib, inputs, ... }:

with lib;
with lib.my;
let cfg = config.modules.shell.zsh;
in
{
  options.modules.shell.zsh = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    programs.zsh = {
      enable = true;
    };

    home-manager.users.funforgiven.programs.zsh = {
      enable = true;
      enableAutosuggestions = true;
      enableCompletion = true;

      oh-my-zsh = {
        enable = true;
        theme = "robbyrussell";
        plugins = [ "git" ];
      };
    };
  };
}
