{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkIf mkOption types;
  cfg = config.alexandersix.calendarWallpaper;
  fallbackInstalledPath = "${config.home.homeDirectory}/.local/share/calendar-wallpaper/fallback.png";

  fallbackPng =
    pkgs.runCommand "calendar-wallpaper-fallback.png" {
      nativeBuildInputs = [pkgs.librsvg];
    } ''
      rsvg-convert --width 3840 --height 2160 --output "$out" ${./calendar-wallpaper/fallback.svg}
    '';

  settings = pkgs.writeText "calendar-wallpaper.json" (builtins.toJSON {
    authoritative = cfg.authoritative;
    stale_output_days = cfg.staleOutputDays;
    texture_opacity = cfg.textureOpacity;
    top_safe_area_ratio = cfg.topSafeAreaRatio;
    week_starts_on = cfg.weekStartsOn;
    palette = cfg.palette;
    months = cfg.monthAccents;
    fonts = {
      primary = cfg.primaryFont;
      calendar = cfg.calendarFont;
    };
    rsvg_convert = "${pkgs.librsvg}/bin/rsvg-convert";
    mmsg = "${osConfig.programs.mango.package}/bin/mmsg";
    noctalia = "${config.programs.noctalia.package}/bin/noctalia";
  });

  package = pkgs.writeShellScriptBin "calendar-wallpaper" ''
    export CALENDAR_WALLPAPER_CONFIG=${settings}
    exec ${pkgs.python3}/bin/python3 ${./calendar-wallpaper/calendar_wallpaper.py} "$@"
  '';
in {
  options.alexandersix.calendarWallpaper = {
    enable = mkEnableOption "the generated Everforest calendar wallpaper";

    package = mkOption {
      type = types.package;
      readOnly = true;
      default = package;
      description = "The configured calendar-wallpaper command.";
    };

    fallbackPath = mkOption {
      type = types.str;
      readOnly = true;
      default = fallbackInstalledPath;
      description = "Stable, date-free fallback wallpaper path.";
    };

    weekStartsOn = mkOption {
      type = types.enum ["monday" "sunday"];
      default = "monday";
      description = "First weekday in the compact month grid.";
    };

    primaryFont = mkOption {
      type = types.str;
      default = "Inter";
      description = "Font family for editorial text and the large date.";
    };

    calendarFont = mkOption {
      type = types.str;
      default = "Iosevka Fixed";
      description = "Font family for the compact calendar.";
    };

    textureOpacity = mkOption {
      type = types.float;
      default = 0.09;
      description = "Opacity of the deterministic paper-grain pattern.";
    };

    topSafeAreaRatio = mkOption {
      type = types.float;
      default = 0.055;
      description = "Fraction of canvas height reserved for shell chrome.";
    };

    periodicCheck = mkOption {
      type = types.str;
      default = "5m";
      description = "Idempotent systemd timer interval for resume and hotplug recovery.";
    };

    staleOutputDays = mkOption {
      type = types.ints.positive;
      default = 30;
      description = "Days to retain two slots for a disconnected output.";
    };

    authoritative = mkOption {
      type = types.bool;
      default = true;
      description = "Restore the generated wallpaper after a manual wallpaper change.";
    };

    palette = mkOption {
      type = types.attrsOf types.str;
      description = "Everforest color roles as six-digit hexadecimal RGB values.";
      default = {
        background_dim = "#232A2E";
        background_0 = "#2D353B";
        background_1 = "#343F44";
        background_2 = "#3D484D";
        background_3 = "#475258";
        foreground = "#D3C6AA";
        red = "#E67E80";
        orange = "#E69875";
        yellow = "#DBBC7F";
        green = "#A7C080";
        aqua = "#83C092";
        blue = "#7FBBB3";
        purple = "#D699B6";
      };
    };

    monthAccents = mkOption {
      type = types.attrsOf (types.attrsOf types.str);
      description = "Palette roles for each month's primary, secondary, and marker accents.";
      default = {
        "1" = {
          primary = "blue";
          secondary = "aqua";
          marker = "purple";
        };
        "2" = {
          primary = "aqua";
          secondary = "blue";
          marker = "purple";
        };
        "3" = {
          primary = "green";
          secondary = "aqua";
          marker = "yellow";
        };
        "4" = {
          primary = "aqua";
          secondary = "green";
          marker = "yellow";
        };
        "5" = {
          primary = "green";
          secondary = "yellow";
          marker = "aqua";
        };
        "6" = {
          primary = "green";
          secondary = "yellow";
          marker = "orange";
        };
        "7" = {
          primary = "yellow";
          secondary = "green";
          marker = "orange";
        };
        "8" = {
          primary = "green";
          secondary = "yellow";
          marker = "red";
        };
        "9" = {
          primary = "yellow";
          secondary = "orange";
          marker = "red";
        };
        "10" = {
          primary = "orange";
          secondary = "yellow";
          marker = "red";
        };
        "11" = {
          primary = "red";
          secondary = "orange";
          marker = "purple";
        };
        "12" = {
          primary = "blue";
          secondary = "aqua";
          marker = "red";
        };
      };
    };
  };

  config = mkIf cfg.enable {
    home.packages = [cfg.package];

    home.file.".local/share/calendar-wallpaper/fallback.png".source = fallbackPng;

    systemd.user.services.calendar-wallpaper = {
      Unit = {
        Description = "Refresh the generated calendar wallpaper";
        After = ["graphical-session.target"];
        PartOf = ["graphical-session.target"];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${cfg.package}/bin/calendar-wallpaper refresh";
      };
    };

    systemd.user.timers.calendar-wallpaper = {
      Unit.Description = "Update the calendar wallpaper at midnight and after missed events";
      Timer = {
        Unit = "calendar-wallpaper.service";
        OnCalendar = "*-*-* 00:00:02";
        OnStartupSec = cfg.periodicCheck;
        OnUnitActiveSec = cfg.periodicCheck;
        Persistent = true;
        AccuracySec = "1s";
      };
      Install.WantedBy = ["timers.target"];
    };
  };
}
