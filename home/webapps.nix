{
  lib,
  pkgs,
  ...
}: let
  # Keep web app IDs stable: Home Manager uses them for the .desktop filenames,
  # while `name` is only the label shown by the application launcher.
  webApps = {
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
      exec ${lib.getExe pkgs.chromium} --app=${lib.escapeShellArg app.url}
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
