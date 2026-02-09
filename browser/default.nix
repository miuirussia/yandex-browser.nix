{
  pname,
  version,
  hash,
  url,
  stdenv,
  lib,
  fetchurl,
  autoPatchelfHook,
  wrapGAppsHook3,
  makeWrapper,
  addDriverRunpath,
  patchelf,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  cairo,
  cups,
  curl,
  dbus,
  expat,
  fontconfig,
  freetype,
  gdk-pixbuf,
  glib,
  gtk3,
  libX11,
  libxcb,
  libXcomposite,
  libXcursor,
  libXdamage,
  libXext,
  libXfixes,
  libXi,
  libxkbcommon,
  libXrandr,
  libXrender,
  libXScrnSaver,
  libxshmfence,
  libXtst,
  libgbm,
  nspr,
  nss,
  pango,
  systemd,
  libcap,
  libva,
  pciutils,
  xdg-utils,
  flac,
  libopus,
  snappy,
  squashfsTools,
  wayland,
  xxd,
  vulkan-loader,
  mesa,
  libglvnd,
  libpulseaudio,
  extensions ? [ ],
}:

let
  folderName = if pname == "yandex-browser-stable" then "browser" else "browser-beta";

  codecsAttrs = builtins.fromJSON (builtins.readFile (../meta + "/${pname}-codecs.json"));
  codecs = stdenv.mkDerivation {
    pname = "yandex-codecs";
    inherit (codecsAttrs) version;
    src = fetchurl { inherit (codecsAttrs) url hash; };
    nativeBuildInputs = [
      squashfsTools
      xxd
    ];
    unpackPhase = "unsquashfs -d . $src";
    installPhase = "install -vD ${codecsAttrs.path} $out/lib/libffmpeg.so";
  };

  deps = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    curl
    dbus
    expat
    fontconfig
    freetype
    gdk-pixbuf
    glib
    gtk3
    libX11
    libxcb
    libXcomposite
    libXcursor
    libXdamage
    libXext
    libXfixes
    libXi
    libxkbcommon
    libXrandr
    libXrender
    libXScrnSaver
    libxshmfence
    libXtst
    libgbm
    nspr
    nss
    pango
    systemd
    libcap
    libva
    pciutils
    xdg-utils
    flac
    libopus
    snappy
    vulkan-loader
    mesa
    libglvnd
    wayland
    libpulseaudio
    stdenv.cc.cc.lib
  ];

  rpath = lib.makeLibraryPath deps;

in
stdenv.mkDerivation {
  inherit pname version;

  src = fetchurl { inherit url hash; };

  nativeBuildInputs = [
    autoPatchelfHook
    wrapGAppsHook3
    makeWrapper
    addDriverRunpath
    patchelf
  ];

  buildInputs = deps;

  autoPatchelfIgnoreMissingDeps = [
    "libQt5Core.so.5"
    "libQt5Gui.so.5"
    "libQt5Widgets.so.5"
    "libQt6Core.so.6"
    "libQt6Gui.so.6"
    "libQt6Widgets.so.6"
  ];

  unpackPhase = ''
    ar x $src
    tar xf data.tar.xz
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/opt/yandex/${folderName} $out/bin $out/share
    cp -r opt/yandex/${folderName}/* $out/opt/yandex/${folderName}/
    cp -r usr/share/* $out/share/

    substituteInPlace $out/share/applications/*.desktop \
      --replace /usr/bin/ $out/bin/

    ln -sf ${codecs}/lib/libffmpeg.so $out/opt/yandex/${folderName}/libffmpeg.so

    exe=$out/opt/yandex/${folderName}/yandex_browser
    patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" "$exe"
    addDriverRunpath "$exe"

    makeWrapper "$exe" "$out/bin/${pname}" \
      --prefix PATH : "${lib.makeBinPath [ xdg-utils ]}" \
      --prefix XDG_DATA_DIRS : "$XDG_ICON_DIRS:$GSETTINGS_SCHEMAS_PATH" \
      --set FOUND_FFMPEG 1 \
      --set THE_BEST_FFMPEG_LIBRARY "$out/opt/yandex/${folderName}/libffmpeg.so" \
      --run '
        export LD_PRELOAD="${
          lib.makeLibraryPath [ libpulseaudio ]
        }/libpulse.so.0''${LD_PRELOAD:+:''$LD_PRELOAD}"

        export LD_LIBRARY_PATH="${rpath}:${addDriverRunpath.driverLink}/lib''${LD_LIBRARY_PATH:+:''$LD_LIBRARY_PATH}"

        FLAGS=""
        if [ -n "$WAYLAND_DISPLAY" ] || [ "$XDG_SESSION_TYPE" = "wayland" ]; then
          export NIXOS_OZONE_WL=1
          FLAGS="$FLAGS --ozone-platform=wayland"

          if command -v nvidia-smi >/dev/null 2>/dev/null || lsmod | grep -q nvidia; then
            FLAGS="$FLAGS --use-gl=angle --use-angle=gl"
          fi
        else
          FLAGS="$FLAGS --ozone-platform=x11"
        fi

        export YANDEX_FLAGS="$FLAGS"
      ' \
      --add-flags "--ignore-gpu-blocklist" \
      --add-flags "--enable-features=VaapiVideoDecoder,WebRTCPipeWireCapturer,CanvasOopRasterization,WaylandWindowDecorations,WebGPU" \
      --add-flags "\''${YANDEX_FLAGS:-}"

    runHook postInstall
  '';

  postFixup = ''
    find $out/opt/yandex/${folderName} -type f -name "*.so*" -exec patchelf --set-rpath "${rpath}:${addDriverRunpath.driverLink}/lib" {} \;
  '';

  meta = with lib; {
    description = "Yandex Web Browser";
    homepage = "https://browser.yandex.ru/";
    license = licenses.unfree;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" ];

    knownVulnerabilities = [
      ''
        Trusts a Russian government issued CA certificate for some websites.
        See https://habr.com/en/company/yandex/blog/655185/ for details.
      ''
    ];
  };
}
