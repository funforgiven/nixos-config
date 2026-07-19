{
  config,
  inputs,
  lib,
  ...
}:
let
  user = config.users.funforgiven;
  anwaWorkspace = "${user.homeDirectory}/dev/anwa";
  hostIdentityPath = "/etc/ssh/ssh_host_ed25519_key";
  # Verification-only: existing commits were signed by this public key before
  # the SOPS migration. Keeping it does not invoke or depend on 1Password.
  historicalSigningPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHj9lWCKgMOZg6K1QzZvNH0QYY4m0lA0l6A+E4wVdVMT historical-signing-key";
  apiTokensFile = ../../secrets/api-tokens.yaml;
  githubSshKeyFile = ../../secrets/github-ssh-key.sops;
  passwordHashesFile = ../../secrets/password-hashes.yaml;
  passwordHashSecretName = "${user.username}-password-hash";
  apiTokenKeys = {
    anwa-github-mcp-token = "codex/anwa_github_mcp_token";
    context7-api-key = "codex/context7_api_key";
    github-mcp-token = "codex/github_mcp_token";
  };
  consumerSecretNames = builtins.attrNames apiTokenKeys ++ [ "github-ssh-key" ];

  mkConsumerSopsSecrets =
    permissions:
    lib.mapAttrs (_: key: permissions // { inherit key; }) apiTokenKeys
    // {
      github-ssh-key = permissions // {
        sopsFile = githubSshKeyFile;
        format = "binary";
      };
    };

  mkSecretMcpLauncher =
    {
      name,
      package,
      pkgs,
      secretPath,
      variable,
    }:
    pkgs.writeShellApplication {
      name = "${name}-with-secret";
      text = ''
        readonly secret_file=${lib.escapeShellArg secretPath}

        if [ ! -r "$secret_file" ]; then
          printf '${name}: required secret is not readable: %s\n' "$secret_file" >&2
          exit 1
        fi

        secret_value="$(< "$secret_file")"
        if [ -z "$secret_value" ]; then
          printf '${name}: required secret is empty: %s\n' "$secret_file" >&2
          exit 1
        fi
        export ${variable}="$secret_value"
        unset secret_value

        exec ${lib.getExe package} "$@"
      '';
    };

  mkSecretConsumers =
    secretPaths:
    {
      config,
      pkgs,
      ...
    }:
    let
      allowedSignersFile = "${config.home.homeDirectory}/.ssh/allowed_signers";
      githubPublicKey = user.accounts.github.sshPublicKey;
      context7McpLauncher = mkSecretMcpLauncher {
        name = "context7-mcp";
        package = pkgs.context7-mcp;
        inherit pkgs;
        secretPath = secretPaths.context7-api-key;
        variable = "CONTEXT7_API_KEY";
      };
      githubMcpLauncher = mkSecretMcpLauncher {
        name = "github-mcp-server";
        package = pkgs.github-mcp-server;
        inherit pkgs;
        secretPath = secretPaths.github-mcp-token;
        variable = "GITHUB_PERSONAL_ACCESS_TOKEN";
      };
      anwaGithubMcpLauncher = mkSecretMcpLauncher {
        name = "github-mcp-server-anwa";
        package = pkgs.github-mcp-server;
        inherit pkgs;
        secretPath = secretPaths.anwa-github-mcp-token;
        variable = "GITHUB_PERSONAL_ACCESS_TOKEN";
      };
      scopedGithubMcpLauncher = pkgs.writeShellApplication {
        name = "github-mcp-server-scoped";
        text = ''
          anwa_workspace="$(${lib.getExe' pkgs.coreutils "realpath"} --canonicalize-missing ${lib.escapeShellArg anwaWorkspace})"
          readonly anwa_workspace
          session_directory="$(${lib.getExe' pkgs.coreutils "realpath"} --canonicalize-existing .)"
          readonly session_directory

          if [[ "$session_directory" == "$anwa_workspace" || "$session_directory" == "$anwa_workspace/"* ]]; then
            exec ${lib.getExe anwaGithubMcpLauncher} "$@"
          fi

          exec ${lib.getExe githubMcpLauncher} --read-only "$@"
        '';
      };
    in
    {
      options.dendritic.gitAuthenticationPublicKey = lib.mkOption {
        type = lib.types.singleLineStr;
        readOnly = true;
        internal = true;
        description = "Evaluated public identity for Git authentication and signing evidence.";
      };

      config = {
        dendritic.gitAuthenticationPublicKey = githubPublicKey;

        home.file = {
          ".ssh/allowed_signers".text = ''
            ${config.programs.git.settings.user.email} ${githubPublicKey}
            ${config.programs.git.settings.user.email} ${historicalSigningPublicKey}
          '';
          ".ssh/github_ed25519.pub".text = "${githubPublicKey}\n";
        };

        programs = {
          codex.enableMcpIntegration = true;

          git = {
            signing = {
              format = "ssh";
              key = secretPaths.github-ssh-key;
              signByDefault = true;
            };
            settings.gpg.ssh.allowedSignersFile = allowedSignersFile;
          };

          mcp = {
            enable = true;
            servers = {
              context7 = {
                command = lib.getExe context7McpLauncher;
                startup_timeout_sec = 20;
                tool_timeout_sec = 60;
                default_tools_approval_mode = "auto";
              };
              github = {
                command = lib.getExe scopedGithubMcpLauncher;
                args = [
                  "--toolsets"
                  "repos,issues,pull_requests,users"
                  "stdio"
                ];
                startup_timeout_sec = 20;
                tool_timeout_sec = 120;
                default_tools_approval_mode = "writes";
              };
            };
          };

          ssh = {
            enable = true;
            enableDefaultConfig = false;
            settings = {
              "github.com" = {
                HostName = "github.com";
                User = "git";
                IdentityAgent = "none";
                IdentitiesOnly = true;
                IdentityFile = secretPaths.github-ssh-key;
              };
              "*".IdentityAgent = "none";
            };
          };
        };
      };
    };
in
{
  perSystem =
    { pkgs, ... }:
    {
      packages = {
        inherit (pkgs) age sops ssh-to-age;
      };
    };

  nixos.modules.funforgiven-secrets.imports = [
    inputs.sops-nix.nixosModules.sops
    (
      { config, lib, ... }:
      let
        deployedSecretPaths = lib.genAttrs consumerSecretNames (name: config.sops.secrets.${name}.path);
        passwordHashSecret = config.sops.secrets.${passwordHashSecretName};
        secretPermissions = {
          owner = config.users.users.${user.username}.name;
          group = config.users.users.${user.username}.group;
          mode = "0400";
        };
      in
      {
        assertions = [
          {
            assertion = lib.any (key: key.path == hostIdentityPath) config.services.openssh.hostKeys;
            message = "The sops-nix age identity must be declared as an OpenSSH host key.";
          }
          {
            assertion =
              passwordHashSecret.neededForUsers
              && passwordHashSecret.path == "/run/secrets-for-users/${passwordHashSecretName}"
              && passwordHashSecret.key == "users/${user.username}/password_hash"
              && passwordHashSecret.mode == "0400"
              && passwordHashSecret.uid == 0
              && passwordHashSecret.gid == 0;
            message = "The account password hash must be an early, root-owned sops-nix user secret.";
          }
          {
            assertion = config.users.users.${user.username}.hashedPasswordFile == passwordHashSecret.path;
            message = "The immutable account must consume the sops-nix password-hash secret.";
          }
        ];

        sops = {
          defaultSopsFile = apiTokensFile;
          defaultSopsFormat = "yaml";
          age.sshKeyPaths = [ hostIdentityPath ];
          secrets = mkConsumerSopsSecrets secretPermissions // {
            "${passwordHashSecretName}" = {
              sopsFile = passwordHashesFile;
              key = "users/${user.username}/password_hash";
              neededForUsers = true;
              mode = "0400";
            };
          };
        };

        home-manager.users.${user.username}.imports = [
          (mkSecretConsumers deployedSecretPaths)
        ];

        services.openssh.generateHostKeys = true;
        users.users.${user.username}.hashedPasswordFile =
          config.sops.secrets.${passwordHashSecretName}.path;
      }
    )
  ];

  homeManager.standaloneModules.funforgiven-secrets.imports = [
    inputs.sops-nix.homeManagerModules.sops
    (
      { config, lib, ... }:
      let
        deployedSecretPaths = lib.genAttrs consumerSecretNames (name: config.sops.secrets.${name}.path);
      in
      {
        imports = [ (mkSecretConsumers deployedSecretPaths) ];

        sops = {
          age.keyFile = "${config.xdg.configHome}/sops/age/keys.txt";
          defaultSopsFile = apiTokensFile;
          defaultSopsFormat = "yaml";
          secrets = mkConsumerSopsSecrets { mode = "0400"; };
        };
      }
    )
  ];
}
