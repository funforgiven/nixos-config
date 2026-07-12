_: {
  nixos.modules.fonts =
    { pkgs, ... }:
    {
      fonts.packages = [
        pkgs.dejavu_fonts
        pkgs.jetbrains-mono
        pkgs.liberation_ttf
        pkgs.material-symbols
        pkgs.noto-fonts
        pkgs.noto-fonts-cjk-sans
        pkgs.noto-fonts-color-emoji
        pkgs.rubik
      ];
    };
}
