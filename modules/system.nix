{
  lib,
  pkgs,
  ...
}: {
  nixpkgs.config.allowUnfreePredicate = package:
    builtins.elem (lib.getName package) [
      "1password"
      "1password-cli"
      "davinci-resolve-studio"
      "discord"
      "obsidian"
      "steam"
      "steam-unwrapped"
      "zoom"
    ];

  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true;
      extra-substituters = ["https://noctalia.cachix.org"];
      extra-trusted-public-keys = [
        "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
      ];
    };

    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  networking = {
    networkmanager.enable = true;
    firewall = {
      enable = true;
      allowedTCPPorts = [53317];
      allowedUDPPorts = [53317];
    };
  };

  i18n.defaultLocale = "en_US.UTF-8";

  fonts = {
    # Keep the workstation's document and Unicode baseline explicit rather than
    # inheriting a nixpkgs default package list that may change between releases.
    enableDefaultPackages = false;
    packages = [
      # General UI and document families.
      pkgs.caladea
      pkgs.carlito
      pkgs.dejavu_fonts
      pkgs.freefont_ttf
      pkgs.gyre-fonts
      pkgs.inter
      pkgs.liberation_ttf
      pkgs.noto-fonts
      pkgs.noto-fonts-cjk-sans
      pkgs.noto-fonts-cjk-serif
      pkgs.noto-fonts-color-emoji
      pkgs.unifont

      # Developer and terminal families.
      (pkgs.iosevka-bin.override {variant = "SGr-IosevkaFixed";})
      pkgs.nerd-fonts.blex-mono
      pkgs.nerd-fonts.gohufont
      pkgs.nerd-fonts.hurmit
      pkgs.nerd-fonts.iosevka
      pkgs.nerd-fonts.jetbrains-mono
      # Alacritty family: "Terminess Nerd Font Mono"
      pkgs.nerd-fonts.terminess-ttf
      pkgs.nerd-fonts.zed-mono
    ];
    fontconfig.defaultFonts = {
      sansSerif = ["Inter" "Noto Sans" "Carlito" "Liberation Sans"];
      serif = ["Noto Serif" "Caladea" "Liberation Serif"];
      monospace = ["Iosevka Fixed" "Noto Sans Mono" "Liberation Mono"];
      emoji = ["Noto Color Emoji"];
    };
  };

  xdg.portal.wlr.settings.screencast = {
    chooser_type = "simple";
    chooser_cmd = "${pkgs.slurp}/bin/slurp -f 'Monitor: %o' -or";
  };

  programs.zsh.enable = true;

  environment = {
    sessionVariables.NIXOS_OZONE_WL = "1";
    systemPackages = [
      pkgs.bash
      pkgs.bibata-cursors
      pkgs.chromium
      # Interpret capabilities advertised by Ghostty clients over SSH without
      # installing Ghostty itself on this workstation.
      pkgs.ghostty.terminfo
      pkgs.nvme-cli
    ];
  };

  programs.chromium = {
    enable = true;
    homepageLocation = "https://google.com";
    extensions = [
      "aeblfdkhhhdcdjpifhhbdiojplfjncoa" # 1Password
      "cjpalhdlnbpafiamejdnhcphjbkeiagm" # uBlock Origin
    ];
  };

  # Keep a second rendering engine available for compatibility and recovery.
  # Chromium remains the primary browser used by Mango and the web-app module.
  programs.firefox.enable = true;

  programs = {
    _1password.enable = true;
    _1password-gui = {
      enable = true;
    };

    dconf.enable = true;
    gamemode.enable = true;
    gpu-screen-recorder.enable = true;
    # Mason installs upstream Linux binaries, including tree-sitter-cli.
    # Provide the standard dynamic loader they expect on NixOS.
    nix-ld.enable = true;
    mango = {
      enable = true;
      addLoginEntry = true;
    };
    noctalia = {
      enable = true;
      recommendedServices.enable = true;
      systemd.enable = false;
    };
    noctalia-greeter = {
      enable = true;
      settings = {
        cursor = {
          theme = "Bibata-Modern-Classic";
          size = 20;
          path = "${pkgs.bibata-cursors}/share/icons";
        };
        idle.timeout = 300;
        keyboard.layout = "us";
      };
    };
    obs-studio = {
      enable = true;
      enableVirtualCamera = true;
      plugins = with pkgs.obs-studio-plugins; [
        advanced-scene-switcher
        obs-aitum-multistream
        obs-move-transition
        obs-pipewire-audio-capture
        obs-source-record
        obs-vaapi
        obs-vertical-canvas
        obs-vkcapture
        waveform
      ];
    };
    steam.enable = true;
    streamcontroller.enable = true;
    system-config-printer.enable = true;
    virt-manager.enable = true;
    wireshark.enable = true;
  };

  services = {
    avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };

    btrfs.autoScrub = {
      enable = true;
      interval = "monthly";
    };

    flatpak.enable = true;
    fstrim = {
      enable = true;
      interval = "weekly";
    };
    gnome = {
      gnome-keyring.enable = true;
      sushi.enable = true;
    };
    gvfs.enable = true;

    pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
      jack.enable = true;
    };

    printing = {
      enable = true;
      browsed.enable = true;
    };

    smartd = {
      enable = true;
      notifications = {
        # This is a single-user workstation. Forward smartd warnings from the
        # system bus to the active graphical session instead of relying on an
        # unread root mailbox or an open terminal.
        systembus-notify.enable = true;
        wall.enable = false;
      };
    };

    # The daemon and CLI are installed here; joining the tailnet remains an
    # intentional one-time interactive step because no auth key is committed.
    tailscale = {
      enable = true;
      openFirewall = true;
    };

    udisks2.enable = true;
  };

  security.rtkit.enable = true;

  # BlueZ is a system capability; Noctalia provides the pairing interface.
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  # Mouseless uses uinput to provide global mouse control on Wayland.
  hardware.uinput.enable = true;

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = [pkgs.rocmPackages.clr.icd];
  };

  hardware.logitech.wireless = {
    enable = true;
    enableGraphical = true;
  };

  virtualisation = {
    docker = {
      enable = true;
      autoPrune = {
        enable = true;
        dates = "weekly";
      };
    };
    libvirtd.enable = true;
  };
}
