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
      "reaper"
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
    firewall.enable = true;
  };

  i18n.defaultLocale = "en_US.UTF-8";

  fonts = {
    packages = [
      pkgs.inter
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
    fontconfig.defaultFonts.sansSerif = ["Inter"];
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

    flatpak.enable = true;
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

    udisks2.enable = true;
  };

  security.rtkit.enable = true;

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
