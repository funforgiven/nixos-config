{ lib, ... }:
{
  home.base = {
    programs = {
      git.settings = {
        merge.conflictStyle = lib.mkForce "zdiff3";
        rerere.enabled = true;
      };

      mergiraf = {
        enable = true;
        enableGitIntegration = true;
      };
    };
  };
}
