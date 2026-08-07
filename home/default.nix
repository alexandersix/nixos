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
