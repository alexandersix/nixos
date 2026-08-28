{
  lib,
  pkgs,
  ...
}: {
  home.packages = [pkgs.figma-agent];

  # Figma does not ship its browser font helper for Linux. This compatible
  # local agent exposes fonts discovered through fontconfig to figma.com.
  systemd.user.services.figma-agent = {
    Unit = {
      Description = "Expose locally installed fonts to Figma";
      After = ["graphical-session.target"];
      PartOf = ["graphical-session.target"];
    };
    Service = {
      ExecStart = lib.getExe pkgs.figma-agent;
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = ["graphical-session.target"];
  };
}
