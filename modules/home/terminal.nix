{
  programs.foot = {
    enable = true;
    settings = {
      main = {
        term = "xterm-256color";
        font = "JetBrains Mono:size=11";
        pad = "8x8";
      };
      scrollback.lines = 10000;
      colors.alpha = 0.96;
    };
  };
}
