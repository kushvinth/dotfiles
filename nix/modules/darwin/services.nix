{
  flake.modules.darwin.services =
    {
      config,
      lib,
      pkgs,
      user,
      ...
    }:
    let
      brewPrefix = "/opt/homebrew/bin";
      logs = "/Users/${user}/Library/Logs";
      cfgToggle = config.services.sketchybar-toggle;
    in
    {
      options.services.sketchybar-toggle = {
        enable = lib.mkEnableOption "sketchybar-toggle, coordinating SketchyBar with the native menu bar";

        triggerZone = lib.mkOption {
          type = lib.types.int;
          default = 10;
          description = "Distance from the top of the screen (px) that triggers SketchyBar to hide.";
        };

        untriggerZone = lib.mkOption {
          type = lib.types.int;
          default = 30;
          description = "Distance from the top (px) a click must clear to restore SketchyBar (pk/fix-untrigger).";
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

      config = {
        services.sketchybar-toggle.enable = lib.mkDefault true;

        launchd.user.agents = {
          skhd = {
            command = "${brewPrefix}/skhd";
            serviceConfig = {
              KeepAlive = true;
              RunAtLoad = true;
              ProcessType = "Interactive";
              EnvironmentVariables = {
                PATH = "${brewPrefix}:/usr/local/bin:/usr/bin:/bin";
              };
              StandardOutPath = "${logs}/skhd.log";
              StandardErrorPath = "${logs}/skhd.err";
            };
          };

          yabai = {
            command = "${brewPrefix}/yabai";
            serviceConfig = {
              KeepAlive = true;
              RunAtLoad = true;
              ProcessType = "Interactive";
              EnvironmentVariables = {
                PATH = "${brewPrefix}:/usr/local/bin:/usr/bin:/bin";
              };
              StandardOutPath = "${logs}/yabai.log";
              StandardErrorPath = "${logs}/yabai.err";
            };
          };

          sketchybar = {
            command = "${brewPrefix}/sketchybar";
            serviceConfig = {
              KeepAlive = true;
              RunAtLoad = true;
              ProcessType = "Interactive";
              EnvironmentVariables = {
                PATH = "${brewPrefix}:/usr/local/bin:/usr/bin:/bin";
              };
              StandardOutPath = "${logs}/sketchybar.log";
              StandardErrorPath = "${logs}/sketchybar.err";
            };
          };
        }
        // lib.optionalAttrs cfgToggle.enable {
          sketchybar-toggle = {
            serviceConfig = {
              ProgramArguments = [
                "${pkgs.sketchybar-toggle}/bin/sketchybar-toggle"
                "--trigger-zone"
                (toString cfgToggle.triggerZone)
                "--untrigger-zone"
                (toString cfgToggle.untriggerZone)
                "--menu-bar-height"
                (toString cfgToggle.menuBarHeight)
                "--debounce"
                (toString cfgToggle.debounce)
              ];
              RunAtLoad = true;
              KeepAlive = true;
              ProcessType = "Interactive";
              StandardOutPath = "/tmp/sketchybar-toggle.log";
              StandardErrorPath = "/tmp/sketchybar-toggle.log";
            };
          };
        };

        environment.systemPackages = lib.optional cfgToggle.enable pkgs.sketchybar-toggle;
      };
    };
}
