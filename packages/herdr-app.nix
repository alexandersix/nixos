{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  copyDesktopItems,
  makeBinaryWrapper,
  makeDesktopItem,
  libxcb,
  libxkbcommon,
  libGL,
  vulkan-loader,
  wayland,
  xdg-utils,
  herdr-core,
  versionCheckHook,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "herdr-app";
  version = "0.1.12";

  src = fetchurl {
    url = "https://releases.herdr.dev/app/${finalAttrs.version}/herdr-app-linux-x86_64.tar.gz";
    hash = "sha256-omXmySXEh0WEBnQf+gnS+g09S9QBo07YwBwzYQjlfB8=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    copyDesktopItems
    makeBinaryWrapper
  ];
  buildInputs = [
    stdenv.cc.cc.lib
    libxcb
    libxkbcommon
  ];
  # GPUI loads these with dlopen. Put them on RUNPATH so LD_LIBRARY_PATH
  # does not leak into the core and every terminal the app starts.
  runtimeDependencies = [
    libGL
    vulkan-loader
    wayland
  ];

  dontBuild = true;

  desktopItems = [
    (makeDesktopItem {
      name = "herdr-app";
      desktopName = "Herdr";
      comment = "Terminals and coding agents that keep running";
      exec = "herdr-app";
      icon = "herdr-app";
      terminal = false;
      categories = ["Development"];
      startupWMClass = "herdr-app";
    })
  ];

  installPhase = ''
    runHook preInstall
    install -Dm755 herdr-app $out/bin/herdr-app
    # Upstream enables self-updates only when this icon is beside the binary.
    # The standard icon location keeps updates under Nix's control instead.
    install -Dm644 herdr-app.svg $out/share/icons/hicolor/scalable/apps/herdr-app.svg
    install -Dm644 LICENSE THIRD-PARTY-NOTICES -t $out/share/licenses/herdr-app
    wrapProgram $out/bin/herdr-app \
      --prefix PATH : ${lib.makeBinPath [herdr-core xdg-utils]}
    runHook postInstall
  '';

  nativeInstallCheckInputs = [versionCheckHook];
  doInstallCheck = true;

  meta = {
    description = "Herdr desktop app for persistent terminals and coding agents";
    homepage = "https://github.com/herdrdev/herdr-app";
    license = lib.licenses.asl20;
    mainProgram = "herdr-app";
    platforms = ["x86_64-linux"];
    sourceProvenance = [lib.sourceTypes.binaryNativeCode];
  };
})
