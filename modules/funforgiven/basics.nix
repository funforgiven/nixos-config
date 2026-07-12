{ config, ... }:
{
  users.funforgiven = {
    email = "fahricanelidemir@gmail.com";
    accounts.github.username = "funforgiven";
    inherit (config) home;
  };
}
