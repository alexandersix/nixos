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

  # Compatibility markers for the first NixOS installation. Do not change
  # these merely because the inputs are updated later.
  system.stateVersion = "26.05";
}
