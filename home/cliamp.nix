{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: {
  home.packages = [
    inputs.cliamp.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  # cliamp persists settings such as volume and theme changes in this file, so
  # seed a normal writable file instead of managing it as a read-only symlink.
  home.activation.seedCliampConfig = lib.hm.dag.entryAfter ["writeBoundary"] ''
    config_dir="${config.xdg.configHome}/cliamp"
    config_file="$config_dir/config.toml"

    if [[ ! -e "$config_file" ]]; then
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p "$config_dir"
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -m 0600 \
        ${./cliamp/config.toml} "$config_file"
    fi
  '';
}
