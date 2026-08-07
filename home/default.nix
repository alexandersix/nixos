{
  inputs,
  lib,
  pkgs,
  username,
  ...
}: {
  imports = [
    inputs.mangowm.hmModules.mango
    inputs.noctalia.homeModules.default
  ];

  home = {
    inherit username;
    homeDirectory = "/home/${username}";
    stateVersion = "26.05";

    packages = with pkgs; [
      # Core command-line tools
      curl
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
      codex
      dbeaver-bin
      deadnix
      devenv
      docker-buildx
      docker-compose
      gh
      godot
      godot-export-templates-bin
      # Herdr v0.6.4 ships a stale Rust vendor hash. Keep the pinned version
      # from the original configuration while correcting that upstream hash.
      (inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs (old: {
        cargoDeps = pkgs.rustPlatform.fetchCargoVendor {
          inherit (old) src;
          hash = "sha256-yRT31RnfjSQy5bxFXVvM9zRM59WAPrBozu3S2tag6s8=";
        };
      }))
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

    fuzzel.enable = true;

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
      settings = {
        shell.font = "JetBrainsMono Nerd Font";
        theme = {
          mode = "dark";
          source = "builtin";
          builtin = "Catppuccin";
        };
      };
    };

    waybar.enable = true;

    zsh = {
      enable = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;
      shellAliases = {
        ll = "ls -la";
        gs = "git status";
        vi = "nvim";
        vim = "nvim";
      };
    };
  };

  wayland.windowManager.mango = {
    enable = true;

    settings = {
      xkb_rules_layout = "us";

      gappih = 5;
      gappiv = 5;
      gappoh = 10;
      gappov = 10;
      borderpx = 2;
      border_radius = 6;
      animations = 1;

      bind = [
        "SUPER,r,reload_config"
        "SUPER,Return,spawn,foot"
        "SUPER,d,spawn,fuzzel"
        "SUPER,q,killclient,"
        "SUPER+SHIFT,e,quit"
        "SUPER,f,togglefullscreen,"
        "SUPER,1,view,1,0"
        "SUPER,2,view,2,0"
        "SUPER+SHIFT,1,tag,1,0"
        "SUPER+SHIFT,2,tag,2,0"
        "SUPER,space,spawn,noctalia msg panel-toggle launcher"
        "SUPER,s,spawn,noctalia msg panel-toggle control-center"
        "SUPER,comma,spawn,noctalia msg settings-toggle"
        "NONE,XF86AudioRaiseVolume,spawn,noctalia msg volume-up"
        "NONE,XF86AudioLowerVolume,spawn,noctalia msg volume-down"
        "NONE,XF86AudioMute,spawn,noctalia msg volume-mute"
        "NONE,XF86MonBrightnessUp,spawn,noctalia msg brightness-up"
        "NONE,XF86MonBrightnessDown,spawn,noctalia msg brightness-down"
      ];

      tagrule = [
        "id:1,layout_name:tile"
        "id:2,layout_name:tile"
      ];

      blur = 1;
      blur_layer = 0;
      blur_optimized = 1;
      blur_params_num_passes = 2;
      blur_params_radius = 5;
      blur_params_noise = 0.02;
      blur_params_brightness = 0.9;
      blur_params_contrast = 0.9;
      blur_params_saturation = 1.0;
      layer_animations = 0;
      shadows = 1;
      layer_shadows = 0;
      shadow_only_floating = 0;
      shadows_size = 4;
      shadows_blur = 12;
      shadows_position_x = 2;
      shadows_position_y = 2;
      shadowscolor = "0x000000ff";
    };

    autostart_sh = ''
      noctalia &
    '';
  };
}
