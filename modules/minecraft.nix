{ inputs, ... }:
{
  home.gui =
    { lib, pkgs, ... }:
    let
      system = pkgs.stdenv.hostPlatform.system;
      prismLauncher = inputs.nixpkgs-prism.legacyPackages.${system}.prismlauncher;
    in
    {
      assertions = [
        {
          assertion = lib.versionAtLeast prismLauncher.version "11.0.3";
          message = "Prism Launcher 11.0.3 or newer is required for current CurseForge imports.";
        }
      ];

      home.packages = [ prismLauncher ];
    };

  nixos.modules.minecraft =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      serviceName = "minecraft-exosphere-2-create";
      serviceUser = "minecraft-exosphere";
      stateDirectoryName = serviceName;
      stateDirectory = "/var/lib/${stateDirectoryName}";
      serverDirectory = "${stateDirectory}/server";
      consoleFifo = "/run/${serviceName}.stdin";
      serverPort = 25565;
      serverMemory = "10G";
      serverJavaArgs = "-Xms${serverMemory} -Xmx${serverMemory}";
      fmlMaxThreads = 1;

      # The modpack remains an external All Rights Reserved runtime download;
      # neither its archive nor its extracted contents are part of this
      # repository's MIT-licensed source.
      pack = {
        version = "2.8.1";
        downloadUrl = "https://www.curseforge.com/api/v1/mods/1530020/files/8446077/download";
        sha256 = "c46ef7d7e5fd4d319e912578de8d5c175330f29e74d24118c3c9ef442b769a42";
        archiveRoot = "Exo2+create-2.8.1-server";
        eulaAccepted = true;
      };

      java = pkgs.jdk21_headless;
      prepareServer = pkgs.writeShellApplication {
        name = "${serviceName}-prepare";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.curl
          pkgs.unzip
        ];
        text = builtins.readFile ./minecraft/server-prepare.sh;
      };
      stopServer = pkgs.writeShellApplication {
        name = "${serviceName}-stop";
        runtimeInputs = [ pkgs.coreutils ];
        text = builtins.readFile ./minecraft/server-stop.sh;
      };

      prepareCommand = lib.escapeShellArgs [
        (lib.getExe prepareServer)
        stateDirectory
        pack.downloadUrl
        pack.sha256
        pack.version
        pack.archiveRoot
        (lib.boolToString pack.eulaAccepted)
        (lib.getExe java)
        serverJavaArgs
        (toString serverPort)
        (toString fmlMaxThreads)
      ];
    in
    {
      assertions = [
        {
          assertion = pack.eulaAccepted;
          message = "Enabling the Minecraft server requires explicit acceptance of the Minecraft EULA.";
        }
      ];

      users = {
        groups.${serviceUser} = { };

        users = {
          ${serviceUser} = {
            description = "Exosphere 2 + Create Minecraft server";
            isSystemUser = true;
            group = serviceUser;
            home = stateDirectory;
          };

          ${config.dendritic.primaryUser.username}.extraGroups = [ serviceUser ];
        };
      };

      networking.firewall.allowedTCPPorts = [ serverPort ];
      networking.firewall.allowedUDPPorts = [ serverPort ];

      systemd = {
        sockets.${serviceName} = {
          bindsTo = [ "${serviceName}.service" ];
          socketConfig = {
            ListenFIFO = consoleFifo;
            SocketMode = "0660";
            SocketUser = serviceUser;
            SocketGroup = serviceUser;
            RemoveOnStop = true;
            FlushPending = true;
          };
        };

        services.${serviceName} = {
          description = "Exosphere 2 + Create Minecraft server";
          wantedBy = [ "multi-user.target" ];
          wants = [ "network-online.target" ];
          requires = [ "${serviceName}.socket" ];
          after = [
            "network-online.target"
            "${serviceName}.socket"
          ];
          path = [
            pkgs.coreutils
            pkgs.curl
            pkgs.gawk
            pkgs.gnugrep
            java
          ];
          unitConfig = {
            StartLimitBurst = 3;
            StartLimitIntervalSec = "15min";
          };
          serviceConfig = {
            ExecStartPre = prepareCommand;
            ExecStart = lib.escapeShellArgs [
              (lib.getExe pkgs.bash)
              "${serverDirectory}/start.sh"
            ];
            ExecStop = "${lib.getExe stopServer} ${lib.escapeShellArg consoleFifo} $MAINPID";
            Restart = "always";
            RestartSec = "15s";
            TimeoutStartSec = "30min";
            TimeoutStopSec = "2min";

            User = serviceUser;
            Group = serviceUser;
            StateDirectory = stateDirectoryName;
            StateDirectoryMode = "0750";
            WorkingDirectory = stateDirectory;
            UMask = "0027";

            Environment = [
              "HOME=${stateDirectory}"
              "LC_ALL=C.UTF-8"
            ];
            StandardInput = "socket";
            StandardOutput = "journal";
            StandardError = "journal";

            CapabilityBoundingSet = "";
            LockPersonality = true;
            NoNewPrivileges = true;
            PrivateDevices = true;
            PrivateTmp = true;
            PrivateUsers = true;
            ProtectClock = true;
            ProtectControlGroups = true;
            ProtectHome = true;
            ProtectHostname = true;
            ProtectKernelLogs = true;
            ProtectKernelModules = true;
            ProtectKernelTunables = true;
            ProtectProc = "invisible";
            ProtectSystem = "strict";
            RestrictAddressFamilies = [
              "AF_UNIX"
              "AF_INET"
              "AF_INET6"
            ];
            RestrictNamespaces = true;
            RestrictRealtime = true;
            RestrictSUIDSGID = true;
            SystemCallArchitectures = "native";
          };
        };
      };
    };
}
