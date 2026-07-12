_: {
  home.base =
    { pkgs, ... }:
    {
      home.packages = [
        pkgs.git-trim
        pkgs.serie
      ];
    };
}
