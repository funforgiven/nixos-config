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
      rnix-lsp
    ];

    home-manager.users.funforgiven.programs.vscode = {
      enable = true;
      extensions = with pkgs.vscode-extensions; [
        mvllow.rose-pine
        pkief.material-icon-theme

        jnoortheen.nix-ide
      ];

      userSettings = {
        "terminal.integrated.fontFamily" = "FiraCode Nerd Font";
        "terminal.integrated.defaultProfile.linux" = "zsh";
        "terminal.integrated.persistentSessionReviveProcess" = "never";

        "workbench.iconTheme" = "material-icon-theme";
        "workbench.colorTheme" = "Rosé Pine";

        "window.titleBarStyle" = "custom";

        "editor.fontSize" = 14;
        "editor.fontFamily" = "JetBrains Mono Nerd Font";
        "editor.fontLigatures" = true;

        "explorer.confirmDelete" = false;
        "explorer.sortOrder" = "type";

        "files.insertFinalNewline" = true;
        "files.trimTrailingWhitespace" = true;

        "nix.enableLanguageServer" = true;
        "nix.serverPath" = "rnix-lsp";
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
