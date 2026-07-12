_: {
  nixos.modules.zed =
    { lib, pkgs, ... }:
    {
      environment = {
        systemPackages = [ pkgs.zed-editor ];

        variables = {
          EDITOR = "${lib.getExe pkgs.zed-editor} --wait";
          VISUAL = "${lib.getExe pkgs.zed-editor} --wait";
        };
      };

      programs.nano.enable = false;
    };

  home.gui = {
    programs.zed-editor = {
      enable = true;
      package = null;
      mutableUserSettings = false;
    };
  };
}
