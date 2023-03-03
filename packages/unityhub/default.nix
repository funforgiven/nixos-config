{ lib, stdenv, fetchurl, dpkg, makeWrapper, buildFHSUserEnv
, extraPkgs ? pkgs: [ ]
, extraLibs ? pkgs: [ ]
}:

stdenv.mkDerivation rec {
  name = "unityhub";
  version = "3.4.1";

  src = fetchurl {
    url = "https://hub-dist.unity3d.com/artifactory/hub-debian-prod-local/pool/main/u/unity/unityhub_amd64/unityhub-amd64-${version}.deb";
    sha256 = "sha256-/P6gPLSRGfwEN801cyNrZTpHyZKO+4tU6cFvLz8ERuo=";
  };

  nativeBuildInputs = [
    dpkg
    makeWrapper
  ];

  fhsEnv = buildFHSUserEnv {
    name = "${name}-fhs-env";
    runScript = "";
    profile = "XDG_DATA_DIRS=\"\$XDG_DATA_DIRS:/usr/share/\"";

    targetPkgs = pkgs: with pkgs; [
      xorg.libXrandr

      # GTK filepicker
      gsettings-desktop-schemas
      hicolor-icon-theme

      # Bug Reporter dependencies
      fontconfig
      freetype
      lsb-release
    ] ++ extraPkgs pkgs;

    multiPkgs = pkgs: with pkgs; [
      # Unity Hub ldd dependencies
      cups
      gtk3
      expat
      libxkbcommon
      lttng-ust_2_12
      krb5
      alsa-lib
      nss_latest
      libdrm
      mesa
      nspr
      atk
      dbus
      at-spi2-core
      pango
      xorg.libXcomposite
      xorg.libXext
      xorg.libXdamage
      xorg.libXfixes
      xorg.libxcb
      xorg.libxshmfence
      xorg.libXScrnSaver
      xorg.libXtst

      # Unity Hub additional dependencies
      libva
      openssl_1_1
      cairo
      xdg-utils
      libnotify
      libuuid
      libsecret
      udev
      libappindicator
      wayland
      cpio
      icu
      libpulseaudio

      # Editor dependencies
      libglvnd # provides ligbl
      xorg.libX11
      xorg.libXcursor
      glib
      gdk-pixbuf
      libxml2
      zlib
      clang
    ] ++ extraLibs pkgs;
  };

  unpackCmd = "dpkg -x $curSrc src";

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    mv opt/ usr/share/ $out

    # `/opt/unityhub/unityhub` is a shell wrapper that runs `/opt/unityhub/unityhub-bin`
    # Which we don't need and replace with our own custom wrapper
    makeWrapper ${fhsEnv}/bin/${name}-fhs-env $out/opt/unityhub/unityhub \
      --add-flags $out/opt/unityhub/unityhub-bin \
      --argv0 unityhub

    # Link binary
    mkdir -p $out/bin
    ln -s $out/opt/unityhub/unityhub $out/bin/unityhub

    # Replace absolute path in desktop file to correctly point to nix store
    substituteInPlace $out/share/applications/unityhub.desktop \
      --replace /opt/unityhub/unityhub $out/opt/unityhub/unityhub

    runHook postInstall
  '';

  meta = with lib; {
    description = "Official Unity3D app to download and manage Unity Projects and installations";
    homepage = "https://unity3d.com/";
    license = licenses.unfree;
    maintainers = with maintainers; [ tesq0 huantian ];
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
  };
}
