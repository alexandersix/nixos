{
  config,
  lib,
  pkgs,
  ...
}: let
  sideberyId = "{3c078156-979c-498b-8990-85f7987dd929}";
  sidebery = pkgs.stdenvNoCC.mkDerivation {
    pname = "firefox-addon-sidebery";
    version = "5.6.1";
    src = pkgs.fetchurl {
      url = "https://addons.mozilla.org/firefox/downloads/file/4903712/sidebery-5.6.1.xpi";
      hash = "sha256-6KCktVarfdU2iXwYFq+dCRgDAiMGjqZoOgQ3YQOmyvI=";
    };
    dontUnpack = true;
    installPhase = ''
      install -Dm444 "$src" "$out/share/mozilla/extensions/{ec8030f7-c20a-464f-9b0e-13a3a9e97384}/${sideberyId}.xpi"
    '';
    passthru.addonId = sideberyId;
  };
in {
  programs.firefox = {
    enable = true;
    # The system module already installs Firefox and its native messaging hosts.
    package = null;
    configPath = ".config/mozilla/firefox";
    profiles.default = {
      id = 0;
      isDefault = true;
      # Adopt the existing profile so bookmarks, logins, and history survive.
      path = "p9cdobw7.default";
      settings = builtins.fromJSON (builtins.readFile ./firefox/preferences.json);
      extensions.packages = [sidebery];
      userChrome = builtins.readFile ./firefox/userChrome.css;
      # userContent can style extension pages too. This avoids overwriting
      # Sidebery's mutable tab trees, panels, and settings in extension storage.
      userContent =
        builtins.readFile ./firefox/userContent.css
        + "\n"
        + builtins.readFile ./firefox/sidebery-sidebar.css;
    };
  };

  # Existing customizations (including Firefox's native vertical-tab backup)
  # can omit the new extension button even though the add-on is enabled.
  home.activation.pinFirefoxSidebery = lib.hm.dag.entryAfter ["linkGeneration"] ''
    $DRY_RUN_CMD ${pkgs.python3}/bin/python3 ${./firefox/pin-sidebery.py} \
      "${config.home.homeDirectory}/${config.programs.firefox.profilesPath}/${config.programs.firefox.profiles.default.path}"
  '';
}
