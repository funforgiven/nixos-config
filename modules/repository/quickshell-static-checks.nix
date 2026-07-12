{ config, lib, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      hostName = "parmigiano";
      hostModel = config.dendritic.hosts.${hostName};
      userName = config.users.${hostModel.user}.username;
      homeConfigurationName = "${userName}@${hostName}";
      shellConfigName = config.dendritic.quickshell.configName;
      homeEvaluation = config.flake.homeConfigurations.${homeConfigurationName};
      homeConfig = homeEvaluation.config;
      shellConfig = homeConfig.programs.quickshell.configs.${shellConfigName};
      app2unitProbeDesktop = pkgs.writeText "firefox.desktop" ''
        [Desktop Entry]
        Type=Application
        Name=Firefox
        GenericName=Web Browser
        Exec=${lib.getExe' pkgs.coreutils "true"} --name "two words"
        Path=/tmp
        Terminal=false
      '';
      uiFeatureContracts =
        pkgs.runCommandLocal "funforgiven-shell-ui-feature-contracts"
          {
            nativeBuildInputs = [ pkgs.ripgrep ];
            shell_config = shellConfig;
          }
          ''
            set -euo pipefail
            ${builtins.readFile ./quickshell-static/ui-feature-contracts.sh}
            touch "$out"
          '';
      serviceActionContracts =
        pkgs.runCommandLocal "funforgiven-shell-service-action-contracts"
          {
            nativeBuildInputs = [
              pkgs.app2unit
              pkgs.ripgrep
              pkgs.systemd
            ];
            shell_config = shellConfig;
            runtime_patch = ../funforgiven/window-manager/quickshell/patches/quickshell-0.3-runtime-contracts.patch;
            app2unit_probe_desktop = app2unitProbeDesktop;
            true_executable = lib.getExe' pkgs.coreutils "true";
          }
          ''
            set -euo pipefail
            ${builtins.readFile ./quickshell-static/service-action-contracts.sh}
            touch "$out"
          '';
      globalPolicyScans =
        pkgs.runCommandLocal "funforgiven-shell-global-policy-scans"
          {
            nativeBuildInputs = [ pkgs.ripgrep ];
            shell_config = shellConfig;
          }
          ''
            set -euo pipefail
            ${builtins.readFile ./quickshell-static/global-policy-scans.sh}
            touch "$out"
          '';
    in
    {
      checks.funforgiven-shell-static = pkgs.runCommandLocal "funforgiven-shell-static-check" { } ''
        set -euo pipefail
        test -e ${uiFeatureContracts}
        test -e ${serviceActionContracts}
        test -e ${globalPolicyScans}
        touch "$out"
      '';
    };
}
