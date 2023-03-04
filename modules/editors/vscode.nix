{ options, config, pkgs, lib, inputs, ... }:

with lib;
with lib.my;
let
  cfg = config.modules.editors.vscode;
in
{
  options.modules.editors.vscode = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      nixpkgs-fmt
      nil
    ];

    home-manager.users.funforgiven.programs.vscode = {
      enable = true;
      extensions = with pkgs.vscode-extensions; [
        pkief.material-icon-theme
      ];

      userSettings = {
        "terminal.integrated.fontFamily" = "JetBrains Mono Nerd Font";
        "terminal.integrated.defaultProfile.linux" = "zsh";
        "terminal.integrated.persistentSessionReviveProcess" = "never";

        "workbench.iconTheme" = "material-icon-theme";

        "editor.fontSize" = 14;
        "editor.fontFamily" = "JetBrains Mono Nerd Font";
        "editor.fontLigatures" = true;

        "editor.guides.bracketPairs" = true;
        "editor.bracketPairColorization.enabled" = true;

        "editor.suggestSelection" = "first";
        "editor.inlineSuggest.enabled" = true;
        "editor.suggest.preview" = true;
        "editor.quickSuggestions" = {
          "strings" = true;
        };

        "explorer.confirmDelete" = false;
        "explorer.sortOrder" = "type";

        "files.autoSave" = "afterDelay";
        "files.autoSaveDelay" = 200;
        "files.trimTrailingWhitespace" = true;

        "nix.enableLanguageServer" = true;
        "nix.serverPath" = "nil";
        "nix.serverSettings".nil.formatting.command = [ "nixpkgs-fmt" ];
        "[nix]" = {
          "editor.tabSize" = 2;
          "editor.formatOnSave" = true;
        };

        "git.autofetch" = true;
        "git.enableSmartCommit" = true;
        "git.enableCommitSigning" = true;

        "diffEditor.ignoreTrimWhitespace" = false;
      };
    };
  };
}
