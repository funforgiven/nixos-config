_: {
  nixos.modules.storage = {
    services.btrfs.autoScrub.enable = true;
  };
}
