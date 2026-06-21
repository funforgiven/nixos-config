{ pkgs, ... }:
{
  programs.firefox.enable = true;
  programs.git.enable = true;
  programs.zsh.enable = true;

  fonts = {
    fontconfig.enable = true;
    packages = with pkgs; [
      dejavu_fonts
      jetbrains-mono
      liberation_ttf
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-emoji
    ];
  };

  environment.systemPackages = with pkgs; [
    btrfs-progs
    compsize
    curl
    discord
    file
    htop
    jq
    lshw
    ncdu
    pciutils
    usbutils
    vim
    wget
    yq
  ];
}
