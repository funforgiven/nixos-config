{
  pkgs,
  username,
  ...
}:
{
  users.mutableUsers = false;

  users.users.${username} = {
    isNormalUser = true;
    description = username;
    shell = pkgs.zsh;
    hashedPasswordFile = "/var/lib/nixos-secrets/${username}-password.hash";
    extraGroups = [
      "wheel"
      "networkmanager"
      "audio"
      "video"
      "input"
      "render"
    ];
  };

  security.sudo.wheelNeedsPassword = true;
}
