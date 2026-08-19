{
  inputs,
  pkgs,
  pkgsUnstable,
  ...
}: let
  username = import ./username.nix;
in {
  imports = [
    ./hardware-configuration.nix
    ../../modules/system.nix
  ];

  boot.kernelPackages = pkgs.linuxPackages_7_1;

  networking.hostName = "desktop";
  time.timeZone = "America/New_York";

  users.users.${username} = {
    isNormalUser = true;
    description = "Alexander Six";
    shell = pkgs.zsh;
    extraGroups = [
      "docker"
      # Mouseless needs raw keyboard input and virtual input device access.
      "input"
      "uinput"
      "kvm"
      "libvirtd"
      "networkmanager"
      "wheel"
      "wireshark"
    ];
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    extraSpecialArgs = {inherit inputs pkgsUnstable username;};
    users.${username} = import ../../home;
  };

  programs._1password-gui.polkitPolicyOwners = [username];

  # This job remains inert until the future external SSD is mounted at the
  # expected path and its Restic password has been provisioned separately.
  # Requiring a real mount prevents an absent drive from turning this directory
  # into an accidental backup repository on the primary filesystem.
  services.restic.backups.workstation-external = {
    repository = "/mnt/workstation-backup/restic-repository";
    passwordFile = "/var/lib/restic/workstation-backup-password";
    initialize = true;
    inhibitsSleep = true;
    paths = ["/home/${username}"];
    exclude = [
      "/home/${username}/.cache"
      "/home/${username}/.local/share/Trash"
      "/home/${username}/.local/share/flatpak"
      "/home/${username}/.local/state/nix"
      "/home/${username}/.nix-defexpr"
      "/home/${username}/.nix-profile"
      "/home/${username}/.npm/_cacache"
      "/home/${username}/.local/share/Steam/steamapps/common"
      "/home/${username}/.local/share/Steam/steamapps/downloading"
      "/home/${username}/.local/share/Steam/steamapps/shadercache"
      "/home/${username}/.local/share/Steam/steamapps/workshop"
      "/home/${username}/go/pkg"
      "**/.direnv"
      "**/node_modules"
    ];
    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 5"
      "--keep-monthly 12"
      "--keep-yearly 3"
    ];
    # Keep the prepared job manual-only until the external SSD exists.
    timerConfig = null;
  };

  systemd.services.restic-backups-workstation-external.unitConfig = {
    ConditionPathExists = "/var/lib/restic/workstation-backup-password";
    ConditionPathIsMountPoint = "/mnt/workstation-backup";
  };

  systemd.tmpfiles.rules = [
    "d /mnt/workstation-backup 0755 root root -"
    "d /var/lib/restic 0700 root root -"
  ];

  # Compatibility markers for the first NixOS installation. Do not change
  # these merely because the inputs are updated later.
  system.stateVersion = "26.05";
}
