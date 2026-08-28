{
  lib,
  pkgs,
  ...
}: let
  fonts = [
    {
      name = "CabinetGrotesk-Variable.ttf";
      hash = "sha256-dBS0WUrXGsPSNqn41KtsRcOVgok7IslOJkdpT+nim14=";
    }
    {
      name = "Chillax-Variable.ttf";
      hash = "sha256-NKT4D/0mlzqn1TE2qb3784/9ObtQezTActUCPYONVsg=";
    }
    {
      name = "ClashDisplay-Variable.ttf";
      hash = "sha256-wcAvJ16IY8+k09Ra7UgDJ3qugZfcykc5aaVzwahO3ZI=";
    }
    {
      name = "ClashGrotesk-Variable.ttf";
      hash = "sha256-WIeh383/KlTNtH7wFlZW5zXmDVDmGCplXxKXjS8N0S0=";
    }
    {
      name = "GeneralSans-Variable.ttf";
      hash = "sha256-SyU52e0zZ+j1X33dNpqxPhe7J5/y63/cpscTrxPU34Q=";
    }
    {
      name = "GeneralSans-VariableItalic.ttf";
      hash = "sha256-SqDCDbtZOtgrQfCQ+7yO+xv+PfhcqJXAgJL3fUZ/6mA=";
    }
    {
      name = "Ranade-Variable.ttf";
      hash = "sha256-05OVsgQUskoQDCPgaIpC2GsNZsc6mSPIOcnPHnG6Fl8=";
    }
    {
      name = "Ranade-VariableItalic.ttf";
      hash = "sha256-qC8qOSV5eB1lgvz77yV8HoUS3wF2Gx42YYuh2ORBQjo=";
    }
    {
      name = "Satoshi-Variable.ttf";
      hash = "sha256-Aq0TGSaqRtKCtq9zrSvK7LDsbvO4MKLwjcq+9E8RQP8=";
    }
    {
      name = "Satoshi-VariableItalic.ttf";
      hash = "sha256-z+j2AKoz3IAHWzGaFq5mPfMMeQG2yzMucOp9+5wItq0=";
    }
  ];

  requireFont = font:
    font
    // {
      source = pkgs.requireFile {
        inherit (font) name hash;
        message = ''
          The licensed font file ${font.name} is not in the local Nix store.

          Restore the private font bundle, then run:

            nix run .#install-private-fonts -- /path/to/fonts
        '';
      };
    };

  requiredFonts = map requireFont fonts;
  fontPackage =
    pkgs.runCommandLocal "fontshare-variable-fonts" {
      meta = {
        description = "Locally supplied Fontshare variable fonts";
        license = lib.licenses.unfree;
      };
    } ''
      install -d "$out/share/fonts/truetype"
      ${lib.concatMapStringsSep "\n" (font: ''
          install -m 0444 ${font.source} "$out/share/fonts/truetype/${font.name}"
        '')
        requiredFonts}
    '';
in {
  fonts.packages = [fontPackage];
}
