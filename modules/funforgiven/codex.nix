{ inputs, ... }:
{
  dendritic.nixpkgs.allowUnfreePackages = [ "terraform" ];

  home.base.imports = [
    (
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        awsRegion = "eu-central-1";
        python = pkgs.python312;
        system = pkgs.stdenv.hostPlatform.system;
        codexPackage = inputs.nixpkgs-codex.legacyPackages.${system}.codex;
        mcpNixos = inputs.mcp-nixos.packages.${system}.mcp-nixos;
        terraformMcpServer = pkgs.terraform-mcp-server;
        uvx = lib.getExe' pkgs.uv "uvx";
        onePassword = "/run/wrappers/bin/op";
        mkOnePasswordMcpServer =
          {
            name,
            package,
            secrets,
          }:
          pkgs.writeShellApplication {
            inherit name;
            text = ''
              if [ ! -x ${onePassword} ]; then
                echo "Expected /run/wrappers/bin/op from programs._1password.enable." >&2
                exit 1
              fi

              export OP_BIOMETRIC_UNLOCK_ENABLED=true

              ${lib.concatStringsSep "\n" (
                lib.mapAttrsToList (variable: reference: ''
                  ${variable}="$(${onePassword} read ${lib.escapeShellArg reference})"
                  export ${variable}
                '') secrets
              )}

              exec ${lib.getExe package} "$@"
            '';
          };
        context7McpServer = mkOnePasswordMcpServer {
          name = "context7-mcp";
          package = pkgs.context7-mcp;
          secrets.CONTEXT7_API_KEY = "op://Private/nixos-config/context7_api_key";
        };
        githubMcpServer = mkOnePasswordMcpServer {
          name = "github-mcp-server";
          package = pkgs.github-mcp-server;
          secrets.GITHUB_PERSONAL_ACCESS_TOKEN = "op://Private/nixos-config/github_token";
        };
        uvEnvironment = {
          UV_NO_MANAGED_PYTHON = "true";
          UV_PYTHON = "${python}/bin/python3";
          UV_PYTHON_DOWNLOADS = "never";
        };
      in
      {
        assertions = [
          {
            assertion = lib.versionAtLeast codexPackage.version "0.144.1";
            message = "The official nixpkgs Codex package pin must provide Codex 0.144.1 or newer.";
          }
        ];

        home.packages = [
          pkgs.awscli2
          pkgs.fd
          pkgs.nodejs
          python
          pkgs.ripgrep
          pkgs.terraform
          pkgs.uv
        ];

        programs.codex = {
          enable = true;
          package = codexPackage;

          settings = {
            model = "gpt-5.6-sol";
            personality = "pragmatic";

            approval_policy = "on-request";
            approvals_reviewer = "auto_review";
            sandbox_mode = "workspace-write";

            model_reasoning_effort = "ultra";
            model_verbosity = "medium";

            projects."${config.home.homeDirectory}/dev/nixos-config" = {
              trust_level = "trusted";
            };

            projects."${config.home.homeDirectory}/dev/anwa" = {
              trust_level = "trusted";
            };

            projects."${config.home.homeDirectory}/dev/infra" = {
              trust_level = "trusted";
            };

            projects."${config.home.homeDirectory}/dev/tegami" = {
              trust_level = "trusted";
            };

            projects."${config.home.homeDirectory}/dev/muketsu" = {
              trust_level = "trusted";
            };

            projects."${config.home.homeDirectory}/dev/heliopause-dominion" = {
              trust_level = "trusted";
            };

            mcp_servers.nixos = {
              command = lib.getExe mcpNixos;
              startup_timeout_sec = 20;
              tool_timeout_sec = 60;
              default_tools_approval_mode = "auto";
            };

            mcp_servers.context7 = {
              command = lib.getExe context7McpServer;
              startup_timeout_sec = 20;
              tool_timeout_sec = 60;
              default_tools_approval_mode = "auto";
            };

            mcp_servers.openaiDeveloperDocs = {
              url = "https://developers.openai.com/mcp";
              startup_timeout_sec = 20;
              tool_timeout_sec = 60;
              default_tools_approval_mode = "auto";
            };

            mcp_servers.github = {
              command = lib.getExe githubMcpServer;
              args = [
                "--read-only"
                "--toolsets"
                "repos,issues,pull_requests,users"
                "stdio"
              ];
              startup_timeout_sec = 20;
              tool_timeout_sec = 120;
              default_tools_approval_mode = "auto";
            };

            mcp_servers.aws = {
              command = uvx;
              args = [ "awslabs.aws-api-mcp-server==1.3.46" ];
              startup_timeout_sec = 60;
              tool_timeout_sec = 120;
              default_tools_approval_mode = "prompt";
              env = uvEnvironment // {
                AWS_DEFAULT_REGION = awsRegion;
                AWS_REGION = awsRegion;
                FASTMCP_LOG_LEVEL = "ERROR";
                READ_OPERATIONS_ONLY = "true";
              };
            };

            mcp_servers.terraform = {
              command = lib.getExe terraformMcpServer;
              args = [ "stdio" ];
              startup_timeout_sec = 20;
              tool_timeout_sec = 120;
              default_tools_approval_mode = "prompt";
            };
          };
        };
      }

    )
  ];
}
