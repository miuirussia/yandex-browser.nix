{ pname, version, hash, url }:

{ stdenv
, lib
, fetchurl
, autoPatchelfHook
, wrapGAppsHook
, flac
, gnome2
, harfbuzzFull
, nss
, snappy
, xdg-utils
, xorg
, alsa-lib
, atk
, cairo
, cups
, curl
, dbus
, squashfsTools
, wayland
, expat
, fontconfig
, freetype
, gdk-pixbuf
, glib
, gst_all_1
, gtk3
, libGL
, libGLU
, libX11
, libxcb
, libXScrnSaver
, libXcomposite
, libXcursor
, libXdamage
, libXext
, libXfixes
, libXi
, libXrandr
, libXrender
, libXtst
, libcap
, libdrm
, libnotify
, libopus
, libpulseaudio
, libuuid
, libva
, libxshmfence
, vulkan-loader
, pciutils
, mesa
, nspr
, pango
, systemd
, at-spi2-atk
, at-spi2-core
, xxd
, makeWrapper
, extensions ? [ ]
}:

let
  desktopName = if pname == "yandex-browser-stable" then "yandex-browser" else pname;
  folderName = if pname == "yandex-browser-stable" then "browser" else "browser-beta";
  binName = desktopName;

  codecsAttrs = builtins.fromJSON
    (builtins.readFile (../meta + "/${pname}-codecs.json"));

  codecs = stdenv.mkDerivation rec {
    pname = "chromium-codecs-ffmpeg-extra";
    version = codecsAttrs.version;

    src = fetchurl {
      url = codecsAttrs.url;
      hash = codecsAttrs.hash;
    };

    phases = [ "unpackPhase" "installPhase" ];

    buildInputs = [ squashfsTools xxd ];

    unpackPhase = ''
      unsquashfs -d . $src
    '';

    installPhase = ''
      install -vD ${codecsAttrs.path} $out/lib/libffmpeg.so
      echo -n $(sha1sum $out/lib/libffmpeg.so | xxd -r -p) > $out/codecs_checksum
    '';

    meta = with lib; {
      description = "Additional support for proprietary codecs for Chromium";
      homepage = "https://ffmpeg.org/";
      license = licenses.lgpl21;
      platforms = [ "x86_64-linux" ];
    };
  };

  extensionJsonScript = id:
    let
      split = lib.splitString ";" id;
      id' = lib.elemAt split 0;
      updateUrl =
        if lib.length split > 1
        then lib.elemAt split 1
        else "https://clients2.google.com/service/update2/crx";
    in
    ''
      cat > $out/opt/yandex/${folderName}/Extensions/${id'}.json <<EOF
      {
        "external_update_url": "${updateUrl}"
      }
      EOF
    '';

in
stdenv.mkDerivation rec {
  inherit pname version;

  src = fetchurl {
    inherit url hash;
  };

  nativeBuildInputs = [
    autoPatchelfHook
    wrapGAppsHook
    makeWrapper
  ];

  buildInputs = [
    flac
    harfbuzzFull
    nss
    snappy
    xdg-utils
    xorg.libxkbfile
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    curl
    dbus
    expat
    fontconfig.lib
    freetype
    gdk-pixbuf
    glib
    gtk3
    libGL
    libGLU
    libX11
    libXScrnSaver
    libXcomposite
    libXcursor
    libXdamage
    libXext
    libXfixes
    libXi
    libXrandr
    libXrender
    libXtst
    libcap
    libdrm
    libnotify
    libopus
    libuuid
    libva
    libxcb
    libxshmfence
    pciutils
    mesa
    nspr
    nss
    pango
    wayland
    stdenv.cc.cc.lib
  ];

  unpackPhase = ''
    mkdir $TMP/ya/ $out/bin/ -p
    ar vx $src
    tar --no-overwrite-dir -xvf data.tar.xz -C $TMP/ya/
  '';

  installPhase = ''
    set +xe
    cp $TMP/ya/{usr/share,opt} $out/ -R
    substituteInPlace $out/share/applications/${desktopName}.desktop \
       --replace /usr/ $out/
    substituteInPlace $out/share/applications/${desktopName}.desktop \
       --replace "Exec=$out/bin/${pname}" "Exec=$out/bin/${pname} %U"
    yaBinary=$out/opt/yandex/${folderName}/${binName}
    chmod +x $yaBinary
    patchelf --set-rpath "${lib.makeLibraryPath [ libGL vulkan-loader pciutils ]}:$(patchelf --print-rpath "$yaBinary")" "$yaBinary"
    makeWrapper $out/opt/yandex/${folderName}/${binName} "$out/bin/${pname}" \
      --add-flags ${lib.escapeShellArg "--gl=egl-angle --angle=opengl --use-angle=vulkan --enable-features=Vulkan,VulkanFromANGLE,DefaultANGLEVulkan,VaapiVideoDecoder,VaapiVideoEncoder,UseMultiPlaneFormatForHardwareVideo"} \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations}}"
    ln -s ${codecs}/lib/libffmpeg.so $out/opt/yandex/${folderName}/libffmpeg.so
    ln -s ${codecs}/codecs_checksum $out/opt/yandex/${folderName}/codecs_checksum
    sed -e '90iexport FOUND_FFMPEG=1' -i $out/opt/yandex/${folderName}/${binName}
    sed -e '91iexport THE_BEST_FFMPEG_LIBRARY=''$HERE/libffmpeg.so' -i $out/opt/yandex/${folderName}/${binName}

    # install extensions
    mkdir -p $out/opt/yandex/${folderName}/Extensions
    ${lib.concatMapStringsSep "\n" extensionJsonScript extensions}
  '';

  postFixup = ''
    # Make sure that libGLESv2 and libvulkan are found by dlopen in both chromium binary and ANGLE libGLESv2.so.
    # libpci (from pciutils) is needed by dlopen in angle/src/gpu_info_util/SystemInfo_libpci.cpp
      
    for binary in "$out/opt/yandex/${folderName}/yandex_browser" "$out/opt/yandex/${folderName}/libGLESv2.so"; do
      patchelf --set-rpath "${
        lib.makeLibraryPath [
          libGL
          vulkan-loader
          pciutils
        ]
      }:$(patchelf --print-rpath "$binary")" "$binary"
    done

    # replace bundled vulkan-loader
    rm "$out/opt/yandex/${folderName}/libvulkan.so.1"
    ln -s -t "$out/opt/yandex/${folderName}" "${lib.getLib vulkan-loader}/lib/libvulkan.so.1"
  '';

  runtimeDependencies = map lib.getLib [
    libpulseaudio
    curl
    systemd
    codecs
  ] ++ buildInputs;

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
