{ config, lib, ... }:
{
  users.funforgiven = {
    email = "fahricanelidemir@gmail.com";
    accounts.github = {
      username = "funforgiven";
      sshPublicKey = lib.removeSuffix "\n" (builtins.readFile ../../secrets/github-ssh-key.pub);
    };
    inherit (config) home;
  };
}
