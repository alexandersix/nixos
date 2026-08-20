{pkgs, ...}: {
  home.packages = [pkgs.process-compose];

  xdg.configFile = {
    "process-compose/settings.yaml" = {
      force = true;
      source = ./process-compose/settings.yaml;
    };

    "process-compose/theme.yaml" = {
      force = true;
      source = ./process-compose/theme.yaml;
    };
  };
}
