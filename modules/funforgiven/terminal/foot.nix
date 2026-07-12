_: {
  home.gui = {
    home.sessionVariables.TERMINAL = "foot";

    programs.foot = {
      enable = true;
      settings = {
        main = {
          term = "xterm-256color";
          pad = "8x8";
        };
        scrollback.lines = 10000;
      };
    };

    xdg.terminal-exec = {
      enable = true;
      settings.default = [ "foot.desktop" ];
    };
  };
}
