{
  config,
  lib,
  pkgs,
  ...
}: let
  cliamp = pkgs.stdenvNoCC.mkDerivation {
    pname = "cliamp";
    version = "1.63.2";

    src = pkgs.fetchurl {
      url = "https://github.com/bjarneo/cliamp/releases/download/v1.63.2/cliamp-linux-amd64";
      hash = "sha256-sGaDLITLnf/LEmJS3ttVoOvNE8uslbv/EDsRG4jOF8k=";
    };

    dontUnpack = true;
    nativeBuildInputs = [
      pkgs.autoPatchelfHook
      pkgs.makeWrapper
    ];
    buildInputs = [pkgs.alsa-lib];

    installPhase = ''
      runHook preInstall

      install -Dm755 "$src" "$out/bin/cliamp"
      wrapProgram "$out/bin/cliamp" \
        --prefix PATH : ${lib.makeBinPath [
        pkgs.ffmpeg-full
        pkgs.yt-dlp
      ]}

      runHook postInstall
    '';

    meta = {
      description = "Terminal music player inspired by Winamp";
      homepage = "https://github.com/bjarneo/cliamp";
      license = lib.licenses.mit;
      mainProgram = "cliamp";
      platforms = ["x86_64-linux"];
    };
  };
in {
  home.packages = [cliamp];

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
