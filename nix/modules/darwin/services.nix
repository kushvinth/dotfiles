{
  config,
  lib,
  pkgs,
  ...
}:
let
  brewPrefix = "/opt/homebrew/bin";
in
{
  launchd.user.agents = {
    "org.nixos.skhd" = {
      command = "${brewPrefix}/skhd";
      serviceConfig = {
        KeepAlive = true;
        RunAtLoad = true;
        ProcessType = "Interactive";
        EnvironmentVariables = {
          PATH = "${brewPrefix}:/usr/local/bin:/usr/bin:/bin";
        };
        StandardOutPath = "/tmp/skhd.log";
        StandardErrorPath = "/tmp/skhd.err";
      };
    };

    "org.nixos.yabai" = {
      command = "${brewPrefix}/yabai";
      serviceConfig = {
        KeepAlive = true;
        RunAtLoad = true;
        ProcessType = "Interactive";
        EnvironmentVariables = {
          PATH = "${brewPrefix}:/usr/local/bin:/usr/bin:/bin";
        };
        StandardOutPath = "/tmp/yabai.log";
        StandardErrorPath = "/tmp/yabai.err";
      };
    };

    "org.nixos.sketchybar" = {
      command = "${brewPrefix}/sketchybar";
      serviceConfig = {
        KeepAlive = true;
        RunAtLoad = true;
        ProcessType = "Interactive";
        EnvironmentVariables = {
          PATH = "${brewPrefix}:/usr/local/bin:/usr/bin:/bin";
        };
        StandardOutPath = "/tmp/sketchybar.log";
        StandardErrorPath = "/tmp/sketchybar.err";
      };
    };
  };
}
