{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.sketchybar-toggle;
in
{
  options.services.sketchybar-toggle = {
    enable = lib.mkEnableOption "sketchybar-toggle, coordinating SketchyBar with the native menu bar";

    triggerZone = lib.mkOption {
      type = lib.types.int;
      default = 10;
      description = "Distance from the top of the screen (px) that triggers SketchyBar to hide.";
    };

    menuBarHeight = lib.mkOption {
      type = lib.types.int;
      default = 50;
      description = "Distance from the top (px) defining the menu bar zone.";
    };

    debounce = lib.mkOption {
      type = lib.types.int;
      default = 150;
      description = "Delay in milliseconds before SketchyBar reappears.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.sketchybar-toggle ];

    launchd.user.agents.sketchybar-toggle = {
      serviceConfig = {
        ProgramArguments = [
          "${pkgs.sketchybar-toggle}/bin/sketchybar-toggle"
          "--trigger-zone"
          (toString cfg.triggerZone)
          "--menu-bar-height"
          (toString cfg.menuBarHeight)
          "--debounce"
          (toString cfg.debounce)
        ];
        RunAtLoad = true;
        KeepAlive = true;
        StandardOutPath = "/tmp/sketchybar-toggle.log";
        StandardErrorPath = "/tmp/sketchybar-toggle.log";
      };
    };
  };
}
