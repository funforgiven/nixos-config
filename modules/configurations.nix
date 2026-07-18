{
  config,
  inputs,
  lib,
  ...
}:
let
  cfg = config;

  primaryUserType = lib.types.submodule {
    options = {
      username = lib.mkOption {
        type = lib.types.singleLineStr;
      };

      homeDirectory = lib.mkOption {
        type = lib.types.strMatching "/.*";
      };
    };
  };

  positiveNumber = lib.types.addCheck lib.types.number (value: value > 0);
  polkitAgentType = lib.types.enum [
    "kde"
    "quickshell"
  ];

  niriOutputType = lib.types.submodule {
    options = {
      connector = lib.mkOption {
        type = lib.types.strMatching "[A-Za-z0-9][A-Za-z0-9-]*";
      };

      identifier = lib.mkOption {
        type = lib.types.addCheck lib.types.singleLineStr (value: value != "");
      };

      mode = lib.mkOption {
        type = lib.types.submodule {
          options = {
            width = lib.mkOption { type = lib.types.ints.positive; };
            height = lib.mkOption { type = lib.types.ints.positive; };
            refresh = lib.mkOption { type = positiveNumber; };
          };
        };
      };

      scale = lib.mkOption { type = positiveNumber; };

      position = lib.mkOption {
        type = lib.types.submodule {
          options = {
            x = lib.mkOption { type = lib.types.int; };
            y = lib.mkOption { type = lib.types.int; };
          };
        };
      };

      transform = lib.mkOption {
        type = lib.types.submodule {
          options.rotation = lib.mkOption {
            type = lib.types.enum [
              0
              90
              180
              270
            ];
          };
        };
      };

      variableRefreshRate = lib.mkOption {
        type = lib.types.oneOf [
          lib.types.bool
          (lib.types.enum [ "on-demand" ])
        ];
      };

      focusAtStartup = lib.mkOption { type = lib.types.bool; };
    };
  };

  niriOutputsType = lib.types.attrsOf niriOutputType;

  hostType = lib.types.submodule (_: {
    options = {
      system = lib.mkOption {
        type = lib.types.singleLineStr;
      };

      stateVersion = lib.mkOption {
        type = lib.types.singleLineStr;
      };

      user = lib.mkOption {
        type = lib.types.singleLineStr;
      };

      features = lib.mkOption {
        type = lib.types.listOf lib.types.singleLineStr;
      };

      homeProfiles = lib.mkOption {
        type = lib.types.listOf lib.types.singleLineStr;
      };

      niri.outputs = lib.mkOption {
        type = lib.types.nullOr niriOutputsType;
        default = null;
      };

      polkit.agent = lib.mkOption {
        type = polkitAgentType;
        default = "kde";
      };
    };
  });

  duplicateNames =
    values:
    lib.unique (builtins.filter (value: lib.count (candidate: candidate == value) values > 1) values);

  validateHostFeatures =
    modules:
    let
      duplicates = duplicateNames modules;
      checks = [
        (lib.throwIfNot (
          duplicates == [ ]
        ) "Duplicate NixOS host features: ${lib.concatStringsSep ", " duplicates}" true)
      ]
      ++ map (
        name:
        lib.throwIfNot (builtins.hasAttr name cfg.nixos.modules)
          "Unknown NixOS host feature '${name}': expected nixos.modules.${name}"
          true
      ) modules;
    in
    builtins.deepSeq checks modules;

  userForHost =
    hostname: host:
    lib.throwIfNot (builtins.hasAttr host.user cfg.users)
      "Unknown user '${host.user}' selected by dendritic host '${hostname}'"
      cfg.users.${host.user};

  nixosModulesFor =
    modules:
    map (name: cfg.nixos.modules.${name}) (
      builtins.filter (name: builtins.hasAttr name cfg.nixos.modules) (validateHostFeatures modules)
    );
  standaloneHomeModulesFor =
    modules:
    map (name: cfg.homeManager.standaloneModules.${name}) (
      builtins.filter (name: builtins.hasAttr name cfg.homeManager.standaloneModules) (
        validateHostFeatures modules
      )
    );

  homeProfilesFor =
    user: profiles:
    let
      duplicates = duplicateNames profiles;
      checks = [
        (lib.throwIfNot (duplicates == [ ])
          "Duplicate home profiles for user '${user.username}': ${lib.concatStringsSep ", " duplicates}"
          true
        )
      ]
      ++ map (
        profile:
        lib.throwIfNot (builtins.hasAttr profile user.home)
          "Unknown home profile '${profile}' for user '${user.username}'"
          true
      ) profiles;
    in
    map (profile: user.home.${profile}) (builtins.deepSeq checks profiles);

  mkHomeBase =
    {
      homeDirectory,
      hostName,
      niriOutputs,
      polkitAgent,
      stateVersion,
      username,
    }:
    {
      options.dendritic = {
        hostName = lib.mkOption {
          type = lib.types.singleLineStr;
          readOnly = true;
          internal = true;
        };

        niri.outputs = lib.mkOption {
          type = lib.types.nullOr niriOutputsType;
          readOnly = true;
          internal = true;
        };

        polkit.agent = lib.mkOption {
          type = polkitAgentType;
          readOnly = true;
          internal = true;
        };
      };

      config = {
        dendritic = {
          inherit hostName;
          niri.outputs = niriOutputs;
          polkit.agent = polkitAgent;
        };

        home = {
          inherit
            homeDirectory
            stateVersion
            username
            ;
        };
      };
    };

  mkNestedHomeBase =
    {
      homeDirectory,
      hostName,
      niriOutputs,
      polkitAgent,
      username,
    }:
    { osConfig, ... }:
    mkHomeBase {
      inherit
        homeDirectory
        hostName
        niriOutputs
        polkitAgent
        username
        ;
      stateVersion = osConfig.system.stateVersion;
    };

  mkHostNixosModules =
    hostname: host:
    let
      user = userForHost hostname host;
    in
    nixosModulesFor host.features
    ++ [
      (
        { config, lib, ... }:
        {
          imports = [ inputs.home-manager.nixosModules.home-manager ];

          options.dendritic.primaryUser = lib.mkOption {
            type = primaryUserType;
            description = "Primary user facts for this evaluated NixOS host.";
          };

          options.dendritic.polkit.agent = lib.mkOption {
            type = polkitAgentType;
            readOnly = true;
            internal = true;
          };

          config = {
            assertions = [
              {
                assertion = builtins.hasAttr user.username config.users.users;
                message = ''
                  Host '${hostname}' selects '${user.username}' as its primary
                  user, but no selected NixOS feature declares that account.
                '';
              }
              {
                assertion =
                  !(builtins.hasAttr user.username config.users.users)
                  || config.users.users.${user.username}.home == user.homeDirectory;
                message = "The primary NixOS account home must match the top-level user fact.";
              }
            ];

            dendritic.primaryUser = {
              inherit (user)
                homeDirectory
                username
                ;
            };
            dendritic.polkit.agent = host.polkit.agent;

            networking.hostName = hostname;
            nixpkgs.hostPlatform = host.system;
            system.stateVersion = host.stateVersion;

            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "hm-bak";
              users.${user.username}.imports = [
                (mkNestedHomeBase {
                  hostName = hostname;
                  niriOutputs = host.niri.outputs;
                  polkitAgent = host.polkit.agent;
                  inherit (user) homeDirectory username;
                })
              ]
              ++ homeProfilesFor user host.homeProfiles;
            };
          };
        }
      )
    ];

  mkNixosConfiguration =
    hostname: host:
    inputs.nixpkgs.lib.nixosSystem {
      inherit (host) system;
      modules = mkHostNixosModules hostname host;
    };

  mkHomeConfiguration =
    hostname: host:
    let
      user = userForHost hostname host;
    in
    inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = cfg.flake.lib.mkPkgs host.system;
      modules = [
        (mkHomeBase {
          hostName = hostname;
          niriOutputs = host.niri.outputs;
          polkitAgent = host.polkit.agent;
          inherit (host) stateVersion;
          inherit (user) homeDirectory username;
        })
      ]
      ++ standaloneHomeModulesFor host.features
      ++ homeProfilesFor user host.homeProfiles;
    };
in
{
  options = {
    nixos.modules = lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.deferredModule;
      default = { };
      description = "Named NixOS modules produced by top-level dendritic modules.";
    };

    homeManager.standaloneModules = lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.deferredModule;
      default = { };
      description = "Named Home Manager modules imported only by standalone Home Manager configurations.";
    };

    home = lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.deferredModule;
      default = { };
      description = "Named Home Manager profiles assembled by user modules.";
    };

    users = lib.mkOption {
      type = lib.types.lazyAttrsOf (
        lib.types.submodule (
          { name, config, ... }:
          {
            options = {
              username = lib.mkOption {
                type = lib.types.singleLineStr;
                default = name;
              };

              name = lib.mkOption {
                type = lib.types.singleLineStr;
                default = name;
              };

              email = lib.mkOption {
                type = lib.types.singleLineStr;
              };

              homeDirectory = lib.mkOption {
                type = lib.types.strMatching "/.*";
                default = "/home/${config.username}";
              };

              home = lib.mkOption {
                type = lib.types.lazyAttrsOf lib.types.deferredModule;
                default = { };
                description = "Home Manager profiles for this user.";
              };

              accounts.github = {
                username = lib.mkOption {
                  type = lib.types.singleLineStr;
                };

                sshPublicKey = lib.mkOption {
                  type = lib.types.addCheck lib.types.singleLineStr (value: lib.hasPrefix "ssh-ed25519 " value);
                  description = "Public SSH key used for GitHub authentication and signing.";
                };
              };
            };
          }
        )
      );
      default = { };
      description = "Top-level user facts and Home Manager profiles.";
    };

    dendritic = {
      builders = {
        mkHomeConfiguration = lib.mkOption {
          type = lib.types.functionTo (lib.types.functionTo lib.types.raw);
          readOnly = true;
          internal = true;
        };

        mkNixosConfiguration = lib.mkOption {
          type = lib.types.functionTo (lib.types.functionTo lib.types.raw);
          readOnly = true;
          internal = true;
        };
      };

      hosts = lib.mkOption {
        type = lib.types.lazyAttrsOf hostType;
        default = { };
        description = "Top-level host facts and lower-level module selections.";
      };
    };
  };

  config = {
    dendritic.builders = {
      inherit mkHomeConfiguration mkNixosConfiguration;
    };

    flake = {
      nixosConfigurations = lib.mapAttrs mkNixosConfiguration cfg.dendritic.hosts;

      homeConfigurations = lib.listToAttrs (
        lib.mapAttrsToList (
          hostname: host:
          let
            user = userForHost hostname host;
          in
          {
            name = "${user.username}@${hostname}";
            value = mkHomeConfiguration hostname host;
          }
        ) cfg.dendritic.hosts
      );
    };
  };
}
