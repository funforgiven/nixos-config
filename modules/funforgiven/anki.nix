_: {
  home.gui =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.anki ];
    };
}
