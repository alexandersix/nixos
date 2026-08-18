{
  config,
  inputs,
  lib,
  pkgs,
  pkgsUnstable,
  username,
  ...
}: let
  onePasswordSshAgentSocket = "${config.home.homeDirectory}/.1password/agent.sock";

  chromiumProfilePicker = pkgs.writeShellApplication {
    name = "chromium-profile-picker";
    runtimeInputs = with pkgs; [
      coreutils
      gnused
      jq
      libnotify
      util-linux
      xdg-utils
    ];
    text = builtins.readFile ./scripts/chromium-profile-picker.sh;
  };

  focusUrgent = pkgs.writeShellApplication {
    name = "focus-urgent";
    runtimeInputs = [pkgs.jq];
    text = builtins.readFile ./scripts/focus-urgent.sh;
  };

  mangoLayoutPicker = pkgs.writeShellApplication {
    name = "mango-layout-picker";
    runtimeInputs = [pkgs.libnotify];
    text = builtins.readFile ./scripts/mango-layout-picker.sh;
  };

  syncNoctaliaConfig = pkgs.writeShellApplication {
    name = "sync-noctalia-config";
    runtimeInputs = with pkgs; [
      coreutils
      git
    ];
    text = builtins.readFile ./scripts/sync-noctalia-config.sh;
  };
in {
  imports = [
    inputs.noctalia.homeModules.default
    ./webapps.nix
  ];

  home = {
    inherit username;
    homeDirectory = "/home/${username}";
    stateVersion = "26.05";

    packages = with pkgs; [
      # Personal utility scripts
      chromiumProfilePicker
      focusUrgent
      mangoLayoutPicker
      syncNoctaliaConfig

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
      thunderbird
      zoom-us

      # Desktop utilities
      alacritty
      file-roller
      imv
      nautilus
      kdePackages.okular
      obsidian
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
      libreoffice
      losslesscut
      lsp-plugins
      mediainfo
      mpvpaper
      pandoc
      poppler-utils
      qpwgraph
      reaper
      rmpc
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
      "bin/.keep".text = "";

      ".config/rmpc/config.ron".text = ''
        #![enable(implicit_some)]
        #![enable(unwrap_newtypes)]
        #![enable(unwrap_variant_newtypes)]
        (
          address: "127.0.0.1:6600",
          album_art: (
            method: None,
          ),
          tabs: [
            (
              name: "Queue",
              pane: Split(
                direction: Vertical,
                panes: [
                  (
                    size: "3",
                    borders: "ALL",
                    border_symbols: Rounded,
                    pane: Pane(QueueHeader()),
                  ),
                  (
                    size: "100%",
                    borders: "LEFT | RIGHT",
                    border_symbols: Rounded,
                    pane: Pane(Queue),
                  ),
                  (
                    size: "7",
                    borders: "ALL",
                    border_symbols: Rounded,
                    border_title: [(kind: Text(" Lyrics "))],
                    border_title_alignment: Right,
                    pane: Pane(Lyrics),
                  ),
                ],
              ),
            ),
            (
              name: "Directories",
              borders: "ALL",
              border_symbols: Rounded,
              pane: Pane(Directories),
            ),
            (
              name: "Artists",
              borders: "ALL",
              border_symbols: Rounded,
              pane: Pane(Artists),
            ),
            (
              name: "Album Artists",
              borders: "ALL",
              border_symbols: Rounded,
              pane: Pane(AlbumArtists),
            ),
            (
              name: "Albums",
              borders: "ALL",
              border_symbols: Rounded,
              pane: Pane(Albums),
            ),
            (
              name: "Playlists",
              borders: "ALL",
              border_symbols: Rounded,
              pane: Pane(Playlists),
            ),
            (
              name: "Search",
              borders: "ALL",
              border_symbols: Rounded,
              pane: Pane(Search),
            ),
          ],
        )
      '';

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
      # 1Password creates this socket after its SSH agent is enabled in the
      # desktop app. Declaring it here makes CLI Git and SSH use that agent.
      SSH_AUTH_SOCK = onePasswordSshAgentSocket;
      VISUAL = "nvim";
    };
  };

  gtk = {
    enable = true;

    gtk3.extraConfig.gtk-application-prefer-dark-theme = 1;
    gtk4.extraConfig.gtk-application-prefer-dark-theme = 1;
  };

  qt = {
    enable = true;
    platformTheme = {
      name = "qt6ct";
      package = pkgs.qt6Packages.qt6ct;
    };

    qt5ctSettings.Appearance = {
      color_scheme_path = "${config.xdg.configHome}/qt5ct/colors/noctalia.conf";
      custom_palette = true;
      standard_dialogs = "xdgdesktopportal";
      style = "Fusion";
    };

    qt6ctSettings.Appearance = {
      color_scheme_path = "${config.xdg.configHome}/qt6ct/colors/noctalia.conf";
      custom_palette = true;
      standard_dialogs = "xdgdesktopportal";
      style = "Fusion";
    };

    # Okular otherwise replaces qt6ct's palette with Breeze Light because
    # KColorSchemeManager cannot infer the dark-mode hint from a custom palette.
    kde.settings.okularrc.UiSettings.ColorScheme = "NoctaliaQtPalette";
  };

  xdg = {
    configFile."alacritty/alacritty.toml" = {
      force = true;
      source = ./alacritty/alacritty.toml;
    };

    configFile."herdr/config.toml" = {
      force = true;
      source = ./herdr/config.toml;
    };

    configFile."mango/application-rules.conf" = {
      force = true;
      source = ./mango/application-rules.conf;
    };

    configFile."mango/autostart.sh" = {
      executable = true;
      force = true;
      source = ./mango/autostart.sh;
    };

    configFile."mango/config.conf" = {
      force = true;
      text = ''
        env=QML2_IMPORT_PATH,${config.home.profileDirectory}/${pkgs.qt5.qtbase.qtQmlPrefix}:${config.home.profileDirectory}/${pkgs.qt6.qtbase.qtQmlPrefix}
        env=QT_PLUGIN_PATH,${config.home.profileDirectory}/${pkgs.qt5.qtbase.qtPluginPrefix}:${config.home.profileDirectory}/${pkgs.qt6.qtbase.qtPluginPrefix}
        env=QT_QPA_PLATFORMTHEME,qt6ct
        # Mango does not source Home Manager's shell session variables. Export
        # the agent socket to compositor children and the systemd user import
        # performed by autostart.sh.
        env=SSH_AUTH_SOCK,${onePasswordSshAgentSocket}

        ${builtins.readFile ./mango/config.conf}
      '';
    };

    configFile."mimeapps.list".force = true;

    userDirs = {
      enable = true;
      createDirectories = true;

      desktop = null;
      documents = null;
      projects = "${config.home.homeDirectory}/Code";
      publicShare = null;
      templates = null;
    };

    mimeApps = {
      enable = true;

      defaultApplications = {
        "inode/directory" = ["org.gnome.Nautilus.desktop"];
        "application/pdf" = ["org.kde.okular.desktop"];
        "application/json" = ["nvim.desktop"];
        "text/markdown" = ["nvim.desktop"];

        "image/avif" = ["imv.desktop"];
        "image/bmp" = ["imv.desktop"];
        "image/gif" = ["imv.desktop"];
        "image/heif" = ["imv.desktop"];
        "image/jpeg" = ["imv.desktop"];
        "image/jxl" = ["imv.desktop"];
        "image/png" = ["imv.desktop"];
        "image/tiff" = ["imv.desktop"];
        "image/webp" = ["imv.desktop"];
        "image/svg+xml" = ["org.inkscape.Inkscape.desktop"];

        "audio/aac" = ["mpv.desktop"];
        "audio/flac" = ["mpv.desktop"];
        "audio/mp4" = ["mpv.desktop"];
        "audio/mpeg" = ["mpv.desktop"];
        "audio/ogg" = ["mpv.desktop"];
        "audio/opus" = ["mpv.desktop"];
        "audio/wav" = ["mpv.desktop"];
        "audio/webm" = ["mpv.desktop"];
        "audio/x-wav" = ["mpv.desktop"];

        "video/mp4" = ["mpv.desktop"];
        "video/mpeg" = ["mpv.desktop"];
        "video/ogg" = ["mpv.desktop"];
        "video/quicktime" = ["mpv.desktop"];
        "video/webm" = ["mpv.desktop"];
        "video/x-matroska" = ["mpv.desktop"];
        "video/x-msvideo" = ["mpv.desktop"];

        "x-scheme-handler/discord-409416265891971072" = ["discord-409416265891971072.desktop"];
        "x-scheme-handler/mailto" = ["thunderbird.desktop"];
        "x-scheme-handler/tg" = ["org.telegram.desktop.desktop"];
        "x-scheme-handler/tonsite" = ["org.telegram.desktop.desktop"];
      };

      associations.added = {
        "application/pdf" = ["org.kde.okular.desktop"];
        "application/json" = ["nvim.desktop"];
        "text/markdown" = ["nvim.desktop"];

        "image/avif" = ["imv.desktop"];
        "image/bmp" = ["imv.desktop"];
        "image/gif" = ["imv.desktop"];
        "image/heif" = ["imv.desktop"];
        "image/jpeg" = ["imv.desktop"];
        "image/jxl" = ["imv.desktop"];
        "image/png" = ["imv.desktop"];
        "image/tiff" = ["imv.desktop"];
        "image/webp" = ["imv.desktop"];
        "image/svg+xml" = ["org.inkscape.Inkscape.desktop"];

        "audio/aac" = ["mpv.desktop"];
        "audio/flac" = ["mpv.desktop"];
        "audio/mp4" = ["mpv.desktop"];
        "audio/mpeg" = ["mpv.desktop"];
        "audio/ogg" = ["mpv.desktop"];
        "audio/opus" = ["mpv.desktop"];
        "audio/wav" = ["mpv.desktop"];
        "audio/webm" = ["mpv.desktop"];
        "audio/x-wav" = ["mpv.desktop"];

        "video/mp4" = ["mpv.desktop"];
        "video/mpeg" = ["mpv.desktop"];
        "video/ogg" = ["mpv.desktop"];
        "video/quicktime" = ["mpv.desktop"];
        "video/webm" = ["mpv.desktop"];
        "video/x-matroska" = ["mpv.desktop"];
        "video/x-msvideo" = ["mpv.desktop"];

        "x-scheme-handler/mailto" = ["thunderbird.desktop"];
        "x-scheme-handler/tg" = ["org.telegram.desktop.desktop"];
        "x-scheme-handler/tonsite" = ["org.telegram.desktop.desktop"];
      };
    };
  };

  # Seed checkpointed generated files on a fresh install, then leave them
  # writable so Noctalia can continue updating them when the theme changes.
  home.activation.seedWritableConfigs = lib.hm.dag.entryAfter ["writeBoundary"] ''
    seed_writable_config() {
      source_file="$1"
      target_dir="$2"
      target_file="$3"

      if [[ ! -e "$target_dir/$target_file" ]]; then
        $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p "$target_dir"
        $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -m 0644 \
          "$source_file" "$target_dir/$target_file"
      fi
    }

    seed_writable_config \
      ${./alacritty/themes/noctalia.toml} \
      "${config.xdg.configHome}/alacritty/themes" \
      noctalia.toml

    seed_writable_config \
      ${./mango/noctalia.conf} \
      "${config.xdg.configHome}/mango" \
      noctalia.conf
  '';

  services = {
    mpd = {
      enable = true;
      musicDirectory = "${config.home.homeDirectory}/Music";
      extraConfig = ''
        auto_update "yes"
        restore_paused "yes"
        zeroconf_enabled "no"

        audio_output {
          type "pipewire"
          name "PipeWire"
          mixer_type "software"
        }
      '';
    };

    mpd-mpris.enable = true;

    udiskie.enable = true;
  };

  programs = let
    noctaliaFont = "Iosevka Fixed";
    terminalFont = "JetBrainsMono Nerd Font";
  in {
    home-manager.enable = true;

    bat.enable = true;

    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    eza.enable = true;

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

    mpv = {
      enable = true;
      config.osc = false;
      scripts = [pkgs.mpvScripts.modernz];
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
              font_family = noctaliaFont;
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
          shell.font_family = noctaliaFont;
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
        c = "clear";
        cat = "bat";
        ga = "git add";
        gl = "git pull";
        glog = "git log --oneline --graph";
        gp = "git push";
        ll = "eza -la";
        ls = "eza";
        gs = "git status";
        gst = "git status";
        pa = "php artisan";
        sail = "sh $([ -f sail ] && echo sail || echo vendor/bin/sail)";
        sa = "sail artisan";
        stream = "herdr --session stream";
        vi = "nvim";
        vim = "nvim";
      };
    };

    zoxide = {
      enable = true;
      enableZshIntegration = true;
      options = ["--cmd" "cd"];
    };
  };
}
