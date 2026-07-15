_: {
  perSystem =
    { pkgs, ... }:
    {
      packages = {
        inherit (pkgs) falcond;
      };
    };

  dendritic.nixpkgs.overlays = [
    (final: _prev: {
      falcond = final.callPackage (
        {
          lib,
          stdenv,
          fetchFromGitHub,
          zig_0_16,
        }:

        stdenv.mkDerivation (finalAttrs: {
          pname = "falcond";
          version = "2.0.12";

          src = fetchFromGitHub {
            owner = "PikaOS-Linux";
            repo = "falcond";
            rev = "504c8cda6c670c74d76893230559176a12d6e7c8";
            hash = "sha256-BMIJJusOjSe5WuHfVq+YM9Hz8RY2pEfwCfesfkEFI/E=";
          };

          sourceRoot = "${finalAttrs.src.name}/falcond";

          zigDeps = zig_0_16.fetchDeps {
            inherit (finalAttrs) pname version;
            src = "${finalAttrs.src}/falcond";
            hash = "sha256-ghj+f4AOB8YEhBXkXmCq2JnIjEKT91Cr5Qar7qeIU5Q=";
          };

          nativeBuildInputs = [ zig_0_16.hook ];

          postConfigure = ''
            ln -s ${finalAttrs.zigDeps} "$ZIG_GLOBAL_CACHE_DIR/p"
          '';

          zigBuildFlags = [
            "-Dconfig-path=/etc/falcond/config.conf"
            "-Dprofiles-dir=/etc/falcond/profiles"
            "-Duser-profiles-dir=/var/empty/falcond"
            "-Dsystem-conf-path=/var/empty/falcond-system.conf"
          ];

          zigCheckFlags = finalAttrs.zigBuildFlags;

          doCheck = true;

          meta = {
            description = "Automatic Linux gaming performance daemon";
            homepage = "https://github.com/PikaOS-Linux/falcond";
            license = lib.licenses.mit;
            mainProgram = "falcond";
            platforms = lib.platforms.linux;
          };
        })
      ) { };
    })
  ];
}
