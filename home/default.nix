{
  config,
  inputs,
  lib,
  pkgs,
  pkgsUnstable,
  username,
  ...
}: {
  imports = [
    inputs.noctalia.homeModules.default
  ];

  home = {
    inherit username;
    homeDirectory = "/home/${username}";
    stateVersion = "26.05";

    packages = with pkgs; [
      # Core command-line tools
      curl
      fastfetch
      fd
      jq
      ripgrep
      unzip
      wget

      # Communication, passwords, and backups
      discord
      localsend
      rclone
      restic
      telegram-desktop
      zoom-us

      # Desktop utilities
      nautilus

      # Content creation, media, graphics, and audio
      ardour
      audacity
      blender
      calf
      darktable
      davinci-resolve-studio
      digikam
      easyeffects
      ffmpeg-full
      fontforge-gtk
      gimp-with-plugins
      handbrake
      imagemagick
      inkscape-with-extensions
      kdePackages.kdenlive
      krita
      krita-plugin-gmic
      losslesscut
      lsp-plugins
      mediainfo
      mpv
      mpvpaper
      pandoc
      qpwgraph
      reaper
      scribus
      synfigstudio
      typst
      yt-dlp
      zam-plugins

      # General development
      act
      alejandra
      beekeeper-studio
      bruno
      pkgsUnstable.codex
      dbeaver-bin
      deadnix
      devenv
      docker-buildx
      docker-compose
      gcc
      gh
      godot
      godot-export-templates-bin
      pkgsUnstable.herdr
      lazydocker
      lazygit
      lazysql
      mitmproxy
      mkcert
      nh
      nix-output-monitor
      nixd
      neovim
      nurl
      pi-coding-agent
      statix
      whisper-cpp
      xh

      # Web development convenience tools. Projects should still pin exact
      # PHP and JavaScript versions in their own development shells.
      nodejs
      php
      php.packages.composer
      pnpm
      sqlite

      # Gaming
      bolt-launcher
      gamescope
      mangohud
      protonup-qt

      # Streaming and graphics diagnostics
      libva-utils
      nvtopPackages.amd
      obs-cli
      pavucontrol
      playerctl
      radeontop
      vulkan-tools
    ];

    pointerCursor = {
      gtk.enable = true;
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Classic";
      size = 20;
    };

    sessionPath = ["$HOME/bin"];

    sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
    };
  };

  services.udiskie.enable = true;

  xdg.configFile."mango/autostart.sh" = {
    executable = true;
    force = true;
    text = ''
      #!/bin/sh

      systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE DISPLAY
      systemctl --user restart xdg-desktop-portal-wlr.service

      noctalia &
    '';
  };

  programs = {
    home-manager.enable = true;

    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    foot = {
      enable = true;
      settings.main = {
        font = "JetBrainsMono Nerd Font:size=11";
        pad = "8x8";
      };
    };

    git = {
      enable = true;
      lfs.enable = true;
      settings = {
        user = {
          name = "Alexander Six";
          email = "alexanderhsix@gmail.com";
        };
        init.defaultBranch = "main";
        pull.rebase = true;
        push.autoSetupRemote = true;
        core.editor = "nvim";
      };
    };

    noctalia = {
      enable = true;
      systemd.enable = false;
      settings = let
        defaultWallpaper = "${config.programs.noctalia.package}/share/noctalia/assets/noctalia-wallpaper.png";
      in {
        shell = {
          font_family = "JetBrainsMono Nerd Font";
          polkit_agent = true;
          panel_anchor_bar = "top";
          greeter_sync = {
            auto_sync = true;
            privilege_command = "pkexec";
          };
        };

        plugins = {
          enabled = [
            "noctalia/mpvpaper"
            "noctalia/screen_recorder"
            "noctalia/wallhaven"
          ];
          auto_update = true;
        };

        control_center.calendar.show_week_numbers = true;

        desktop_widgets.enabled = false;

        location.address = "Greenville, SC";

        lockscreen_widgets = {
          enabled = false;
          schema_version = 2;
          widget_order = ["lockscreen-login-box@HDMI-A-1"];

          grid = {
            cell_size = 16;
            major_interval = 4;
            visible = true;
          };

          widget."lockscreen-login-box@HDMI-A-1" = {
            box_height = 70.0;
            box_width = 400.0;
            cx = 1920.0;
            cy = 2041.0;
            output = "HDMI-A-1";
            rotation = 0.0;
            type = "login_box";

            settings = {
              background_color = "surface_variant";
              background_opacity = 0.88;
              background_radius = 12.0;
              center_password_text = false;
              input_opacity = 1.0;
              input_radius = 6.0;
              show_caps_lock = true;
              show_keyboard_layout = true;
              show_login_button = true;
            };
          };
        };

        theme = {
          builtin = "Gruvbox";
          community_palette = "Oxocarbon";
          mode = "dark";
          source = "builtin";
          wallpaper_scheme = "m3-content";

          templates = {
            builtin_ids = [
              "foot"
              "gtk3"
              "gtk4"
              "ghostty"
              "mango"
              "qt"
              "starship"
            ];
            community_ids = [
              "opencode"
              "pi-agent"
              "zen-browser"
              "telegram"
              "blender"
              "gimp"
              "neovim"
              "obsidian"
              "zed"
              "fuzzel"
              "fastfetch"
              "obs"
              "bat"
              "lazygit"
              "yazi"
            ];
          };
        };

        wallpaper = {
          default.path = defaultWallpaper;
          last.path = defaultWallpaper;
        };

        weather.unit = "imperial";

        widget = {
          brightness.enabled = false;
          clipboard.enabled = false;
          control-center.enabled = false;
          launcher.enabled = false;
          network.enabled = false;
          screen-recorder = {
            enabled = false;
            type = "noctalia/screen_recorder:recorder";
          };
          video-wallpaper.type = "noctalia/mpvpaper:mpvpaper";
          wallhaven.type = "noctalia/wallhaven:wallhaven";
        };

        bar = let
          frame = position:
            {
              inherit position;
              thickness = 10;
              background_opacity = 1.0;
              radius = 10;
              concave_edge_corners = true;
              margin_ends = 0;
              margin_edge = 0;
              reserve_space = true;
              shadow = false;
              padding = 0;
              widget_spacing = 0;
              start = [];
              center = [];
              end = [];
            }
            // (
              if position == "bottom"
              then {
                radius_bottom_left = 0;
                radius_bottom_right = 0;
              }
              else if position == "left"
              then {
                radius_top_left = 0;
                radius_bottom_left = 0;
              }
              else {
                radius_top_right = 0;
                radius_bottom_right = 0;
              }
            );
        in {
          order = [
            "left"
            "right"
            "top"
            "bottom"
          ];

          top = {
            position = "top";
            thickness = 34;
            background_opacity = 1.0;
            radius = 10;
            radius_top_left = 0;
            radius_top_right = 0;
            concave_edge_corners = true;
            margin_ends = 0;
            margin_edge = 0;
            reserve_space = true;
            shadow = false;
            start = [
              "workspaces"
              "wallpaper"
              "wallhaven"
              "video-wallpaper"
            ];
            center = ["clock"];
            end = [
              "tray"
              "screen-recorder"
              "media"
              "clipboard"
              "network"
              "bluetooth"
              "volume"
              "brightness"
              "battery"
              "control-center"
              "notifications"
              "session"
            ];
          };

          bottom = frame "bottom";
          left = frame "left";
          right = frame "right";
        };
      };
    };

    zsh = {
      enable = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;
      initContent = ''
        bindkey -M viins '^R' history-incremental-search-backward
      '';
      shellAliases = {
        ll = "ls -la";
        gs = "git status";
        vi = "nvim";
        vim = "nvim";
      };
    };
  };
}
