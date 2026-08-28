{
  config,
  lib,
  pkgs,
  ...
}: let
  # Keep web app IDs stable: Home Manager uses them for the .desktop filenames,
  # while `name` is only the label shown by the application launcher.
  webApps = {
    figma = {
      name = "Figma";
      url = "https://www.figma.com/";
      icon = ./webapps/icons/figma.svg;
      chromiumArgs = [
        # Figma only attempts to contact its local font helper on officially
        # supported operating systems. The Linux-compatible agent therefore
        # requires the Figma launcher to identify as Windows.
        "--user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/${pkgs.chromium.version} Safari/537.36"

        # Chromium applies --user-agent when starting a browser process. Keep
        # Figma in its own profile so an existing Chromium process cannot cause
        # the Figma-specific flag to be discarded.
        "--user-data-dir=${config.xdg.configHome}/chromium-webapps/figma"
      ];
    };

    x = {
      name = "X";
      url = "https://x.com/";
      icon = ./webapps/icons/x.svg;
    };

    youtube = {
      name = "YouTube";
      url = "https://www.youtube.com/";
      icon = ./webapps/icons/youtube.svg;
    };
  };

  mkWebApp = id: app: let
    launcher = pkgs.writeShellScript "webapp-${id}" ''
      exec ${lib.getExe pkgs.chromium} \
        ${lib.escapeShellArgs (app.chromiumArgs or [])} \
        --app=${lib.escapeShellArg app.url}
    '';
  in
    lib.nameValuePair "webapp-${id}" {
      inherit (app) name icon;
      genericName = "Web Application";
      comment = "Open ${app.name} as a standalone Chromium web app";
      exec = toString launcher;
      terminal = false;
      startupNotify = true;
      categories = [
        "Network"
        "WebBrowser"
      ];
      settings."X-NixOS-WebApp" = "true";
    };
in {
  xdg.desktopEntries = lib.mapAttrs' mkWebApp webApps;
}
