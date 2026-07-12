_:
let
  diskoConfig = {
    disko.devices.disk.main = {
      type = "disk";

      device = "/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_4TB_S7DPNJ0Y100114N";

      content = {
        type = "gpt";
        partitions = {
          ESP = {
            name = "ESP";
            size = "1G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };

          root = {
            name = "nixos";
            size = "100%";
            content = {
              type = "btrfs";
              extraArgs = [ "-f" ];
              subvolumes =
                let
                  baseOptions = [
                    "noatime"
                    "ssd"
                    "compress=zstd:1"
                  ];
                  forceOptions = [
                    "noatime"
                    "ssd"
                    "compress-force=zstd:1"
                  ];
                in
                {
                  "/@" = {
                    mountpoint = "/";
                    mountOptions = baseOptions;
                  };
                  "/@home" = {
                    mountpoint = "/home";
                    mountOptions = baseOptions;
                  };
                  "/@nix" = {
                    mountpoint = "/nix";
                    mountOptions = forceOptions;
                  };
                  "/@log" = {
                    mountpoint = "/var/log";
                    mountOptions = forceOptions;
                  };
                  "/@cache" = {
                    mountpoint = "/var/cache";
                    mountOptions = baseOptions;
                  };
                };
            };
          };
        };
      };
    };
  };
in
{
  flake.diskoConfigurations.parmigiano = diskoConfig;
  nixos.modules.parmigiano-disko = diskoConfig;
}
