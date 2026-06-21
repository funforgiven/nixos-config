{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  mcpNixos = inputs.mcp-nixos.packages.${system}.mcp-nixos;
in
{
  home.packages = with pkgs; [
    fd
    gh
    nodejs
    ripgrep
    uv
    mcpNixos
  ];

  programs.codex = {
    enable = true;
    package = pkgs.codex;

    settings = {
      model = "gpt-5.5";
      model_provider = "openai";
      personality = "pragmatic";

      approval_policy = "on-request";
      sandbox_mode = "workspace-write";

      model_reasoning_effort = "high";
      model_verbosity = "medium";

      mcp_servers.nixos = {
        command = lib.getExe mcpNixos;
        enabled = true;
        startup_timeout_sec = 20;
        tool_timeout_sec = 60;
        default_tools_approval_mode = "auto";
      };
    };
  };
}
