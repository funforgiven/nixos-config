{ config, ... }:
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
      materialPalette = homeConfig.dendritic.materialYou.generatedJson;
      quickshell = homeConfig.programs.quickshell.package;
      qtQmlPaths = [
        "${shellConfig}"
        "${pkgs.qt6.qtdeclarative}/lib/qt-6/qml"
        "${pkgs.qt6.qtwayland}/lib/qt-6/qml"
        "${quickshell}/lib/qt-6/qml"
      ];
      qmlImportArgs = builtins.concatMap (path: [
        "-I"
        path
      ]) qtQmlPaths;
      scannerImportArgs = builtins.concatMap (path: [
        "-importPath"
        path
      ]) qtQmlPaths;
    in
    {
      checks = {
        quickshell-theme-contrast =
          pkgs.runCommandLocal "quickshell-theme-contrast"
            {
              nativeBuildInputs = [ pkgs.nodejs ];
            }
            ''
              set -euo pipefail
              node ${shellConfig}/tests/ThemeContrast.mjs ${shellConfig} ${materialPalette}
              touch "$out"
            '';
        funforgiven-shell-qml =
          pkgs.runCommandLocal "funforgiven-shell-qml-check"
            {
              nativeBuildInputs = [ pkgs.jq ];
            }
            ''
              set -euo pipefail

              shell_config=${shellConfig}
              export LC_ALL=C.UTF-8
              test -f "$shell_config/shell.qml"

              mapfile -d "" -t qml_files < <(
                find "$shell_config" \
                  -type d \( \
                    -name fixtures -o \
                    -name test -o \
                    -name testdata -o \
                    -name tests \
                  \) -prune -o \
                  -type f -name "*.qml" -print0 \
                  | sort -z
              )
              mapfile -d "" -t lint_files < <(
                find "$shell_config" \
                  -type d \( \
                    -name fixtures -o \
                    -name test -o \
                    -name testdata -o \
                    -name tests \
                  \) -prune -o \
                  -type f \( -name "*.js" -o -name "*.qml" \) -print0 \
                  | sort -z
              )

              if (( ''${#qml_files[@]} == 0 )); then
                echo "The generated funforgiven-shell config contains no runtime QML files." >&2
                exit 1
              fi

              while IFS= read -r -d "" qmldir; do
                directory="$(dirname "$qmldir")"
                for qml_file in "$directory"/*.qml; do
                  [[ -e "$qml_file" ]] || continue
                  qml_name="$(basename "$qml_file")"
                  [[ "$qml_name" == shell.qml ]] && continue

                  if ! grep -Eq \
                    "^[[:space:]]*(singleton[[:space:]]+)?[A-Za-z_][A-Za-z0-9_]*[[:space:]]+[0-9]+\\.[0-9]+[[:space:]]+$qml_name[[:space:]]*$" \
                    "$qmldir"; then
                    echo "$qml_file is not exported by $qmldir." >&2
                    exit 1
                  fi
                done
              done < <(find "$shell_config" -type f -name qmldir -print0)

              ${pkgs.qt6.qtdeclarative}/bin/qmllint \
                --ignore-settings \
                --bare \
                --max-warnings 0 \
                ${pkgs.lib.escapeShellArgs qmlImportArgs} \
                "''${lint_files[@]}"

              mkdir -p "$out"
              ${pkgs.qt6.qtdeclarative}/libexec/qmlimportscanner \
                -qmlFiles "''${qml_files[@]}" \
                ${pkgs.lib.escapeShellArgs scannerImportArgs} \
                > "$out/imports.json"

              if ! jq -e '
                [
                  .[]
                  | select(.type == "module" and ((.path // "") == ""))
                ]
                | length == 0
              ' "$out/imports.json" >/dev/null; then
                echo "The generated funforgiven-shell config has unresolved QML imports:" >&2
                jq -r '
                  .[]
                  | select(.type == "module" and ((.path // "") == ""))
                  | "  - \(.name)"
                ' "$out/imports.json" >&2
                exit 1
              fi
            '';
      };
    };
}
