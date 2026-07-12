_: {
  home.base =
    { config, ... }:
    {
      programs.fish.shellAliases = {
        ll = "ls -lah";
        rebuild = "sudo nixos-rebuild switch --flake ${config.home.homeDirectory}/dev/nixos-config";
      };
    };
}
