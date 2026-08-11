{
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
      btop
      cava
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
      alacritty
      nautilus
      wl-clipboard

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
      go
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
      python3
      statix
      whisper-cpp
      pkgsUnstable.worktrunk
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

    file = {
      ".local/share/noctalia/plugins/mango-layout/plugin.toml".text = ''
        id = "alexandersix/mango-layout"
        name = "Mango Layout"
        version = "1.0.0"
        min_noctalia = "5.0.0"
        plugin_api = 3
        author = "Alexander Six"
        license = "MIT"
        description = "Shows the active Mango tiling layout in the bar."
        tags = ["bar", "mango", "layout"]

        [[widget]]
        id = "layout"
        entry = "main.luau"
      '';

      ".local/share/noctalia/plugins/mango-layout/main.luau".text = ''
        local layoutNames = {
          T = "Tile",
          S = "Scroller",
          G = "Grid",
          M = "Monocle",
          K = "Deck",
          CT = "Center Tile",
          RT = "Right Tile",
          VS = "Vertical Scroller",
          VT = "Vertical Tile",
          VG = "Vertical Grid",
          VK = "Vertical Deck",
          DW = "Dwindle",
          F = "Fair",
          VF = "Vertical Fair",
        }

        local function showLayout(symbol)
          local name = layoutNames[symbol] or symbol
          barWidget.setText(name)
          barWidget.setTooltip("Mango layout: " .. name)
        end

        barWidget.setText("Layout")
        barWidget.setTooltip("Waiting for Mango layout state")

        local watchCommand =
          "mmsg watch all-monitors | jq --unbuffered -r '.monitors[] | select(.active == true) | .layout_symbol'"

        if not noctalia.runStream(watchCommand, showLayout) then
          barWidget.setText("Layout ?")
          barWidget.setTooltip("Could not watch Mango layout state")
        end

        function onClick()
          noctalia.runAsync("mmsg dispatch switch_layout")
        end
      '';
    };

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

  gtk = {
    enable = true;

    gtk3.extraConfig.gtk-application-prefer-dark-theme = 1;
    gtk4.extraConfig.gtk-application-prefer-dark-theme = 1;
  };

  services.udiskie.enable = true;

  programs = let
    terminalFont = "JetBrainsMono Nerd Font";
  in {
    home-manager.enable = true;

    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    foot = {
      enable = true;
      settings.main = {
        include = "~/.config/foot/themes/noctalia";
        font = "${terminalFont}:size=11";
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
        noctaliaSnapshot = builtins.fromTOML (builtins.readFile ./noctalia/config.toml);
      in
        lib.recursiveUpdate (lib.recursiveUpdate (let
            defaultWallpaper = "/home/alexandersix/Pictures/Wallpapers/wallhaven-4xvdxo.jpg";
          in {
            shell = {
              font_family = terminalFont;
              polkit_agent = true;
              panel_anchor_bar = "top";
              greeter_sync = {
                auto_sync = true;
                privilege_command = "pkexec";
              };
            };

            plugins = {
              enabled = [
                "alexandersix/mango-layout"
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
              monitors."HDMI-A-1".path = defaultWallpaper;
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
              top-bar-gap = {
                type = "spacer";
                length = 16;
              };
              workspace-layout-gap = {
                type = "spacer";
                settings.length = 4;
              };
              video-wallpaper.type = "noctalia/mpvpaper:mpvpaper";
              wallhaven.type = "noctalia/wallhaven:wallhaven";
              mango-layout.type = "alexandersix/mango-layout:layout";
            };

            bar = let
              frameThickness = 12;
              topThickness = 40;
              innerRadius = 16;
              frame = position:
                {
                  inherit position;
                  thickness = frameThickness;
                  background_opacity = 1.0;
                  radius = innerRadius;
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
                thickness = topThickness;
                background_opacity = 1.0;
                radius = innerRadius;
                radius_top_left = 0;
                radius_top_right = 0;
                concave_edge_corners = true;
                margin_ends = 0;
                margin_edge = 0;
                reserve_space = true;
                shadow = false;
                widget_spacing = 6;
                start = [
                  "workspaces"
                  "workspace-layout-gap"
                  "mango-layout"
                ];
                center = ["clock"];
                end = [
                  "tray"
                  "screen-recorder"
                  "top-bar-gap"
                  "media"
                  "clipboard"
                  "network"
                  "top-bar-gap"
                  "bluetooth"
                  "top-bar-gap"
                  "volume"
                  "brightness"
                  "top-bar-gap"
                  "battery"
                  "control-center"
                  "top-bar-gap"
                  "notifications"
                  "top-bar-gap"
                  "session"
                ];
              };

              bottom = frame "bottom";
              left = frame "left";
              right = frame "right";
            };
          })
          noctaliaSnapshot) {
          shell.font_family = terminalFont;
          plugins.enabled = lib.unique ((noctaliaSnapshot.plugins.enabled or []) ++ ["alexandersix/mango-layout"]);
          widget."mango-layout".type = "alexandersix/mango-layout:layout";
          widget."workspace-layout-gap" = {
            type = "spacer";
            settings.length = 4;
          };
          bar.top.start =
            lib.concatMap
            (name:
              if name == "workspaces"
              then [
                name
                "workspace-layout-gap"
                "mango-layout"
              ]
              else if builtins.elem name ["workspace-layout-gap" "mango-layout"]
              then []
              else [name])
            (noctaliaSnapshot.bar.top.start or []);
        };
    };

    zsh = {
      enable = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;
      initContent = ''
        bindkey -M viins '^R' history-incremental-search-backward
        eval "$(${pkgsUnstable.worktrunk}/bin/wt config shell init zsh)"
      '';
      shellAliases = {
        ll = "ls -la";
        gs = "git status";
        sail = "sh $([ -f sail ] && echo sail || echo vendor/bin/sail)";
        vi = "nvim";
        vim = "nvim";
      };
    };
  };
}
