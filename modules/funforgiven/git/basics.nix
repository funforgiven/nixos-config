{ config, ... }:
let
  user = config.users.funforgiven;
in
{
  home.base = {
    programs.git = {
      enable = true;
      settings = {
        user = {
          inherit (user) email name;
        };
        init.defaultBranch = "main";
        push = {
          autoSetupRemote = true;
          default = "current";
        };
        pull.ff = "only";
        commit.verbose = true;
        branch.sort = "-committerdate";
        tag.sort = "taggerdate";
      };
    };
  };
}
