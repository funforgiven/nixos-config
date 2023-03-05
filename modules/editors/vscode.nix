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
        catppuccin.catppuccin-vsc
        pkief.material-icon-theme

        jnoortheen.nix-ide
      ];

      userSettings = {
        "terminal.integrated.fontFamily" = "JetBrains Mono Nerd Font";
        "terminal.integrated.defaultProfile.linux" = "zsh";
        "terminal.integrated.persistentSessionReviveProcess" = "never";

        "workbench.iconTheme" = "material-icon-theme";
        "workbench.colorTheme" = "Catppuccin Mocha";

        "window.titleBarStyle" = "custom";

        "catppuccin.accentColor" = "sky";
        "catppuccin.colorOverrides" = {
          "mocha" = {
            "base" = "#000000";
            "mantle" = "#010101";
            "crust" = "#020202";
          };
        };
        "catppuccin.customUIColors" = {
          "mocha" = {
            "statusBar.foreground" = "accent";
          };
        };

        "editor.fontSize" = 14;
        "editor.fontFamily" = "JetBrains Mono Nerd Font";
        "editor.fontLigatures" = true;

        "explorer.confirmDelete" = false;
        "explorer.sortOrder" = "type";

        "files.autoSave" = "onFocusChange";
        "files.insertFinalNewline" = true;
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
