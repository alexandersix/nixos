{
  description = "Alexander's NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgsUnstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    mangowm = {
      url = "github:mangowm/mango";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    qylock = {
      url = "github:Darkkal44/qylock";
      inputs.nixpkgs.follows = "nixpkgsUnstable";
    };

    # Noctalia's cached branch intentionally uses its own nixpkgs revision so
    # that packages can be downloaded from the project's binary cache.
    noctalia.url = "github:noctalia-dev/noctalia/cachix";
  };

  outputs = inputs @ {
    home-manager,
    mangowm,
    nixpkgs,
    nixpkgsUnstable,
    noctalia,
    qylock,
    ...
  }: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
    pkgsUnstable = import nixpkgsUnstable {
      inherit system;
      config.allowUnfreePredicate = package:
        builtins.elem (nixpkgs.lib.getName package) [
          "1password"
          "1password-cli"
          "davinci-resolve-studio"
          "discord"
          "reaper"
          "steam"
          "steam-unwrapped"
          "zoom"
        ];
    };
    setup = pkgs.writeShellApplication {
      name = "nixos-setup";
      runtimeInputs = [
        pkgs.coreutils
        pkgs.findutils
        pkgs.gh
        pkgs.git
      ];
      text = builtins.readFile ./scripts/setup.sh;
    };
  in {
    nixosConfigurations.desktop = nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = {inherit inputs pkgsUnstable;};

      modules = [
        ./hosts/desktop
        home-manager.nixosModules.home-manager
        mangowm.nixosModules.mango
        noctalia.nixosModules.default
        qylock.nixosModules.default
      ];
    };

    apps.${system}.setup = {
      type = "app";
      program = "${setup}/bin/nixos-setup";
      meta.description = "Prepare hardware, user, and private configuration repositories";
    };

    formatter.${system} = pkgs.alejandra;
  };
}
