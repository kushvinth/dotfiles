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
    skhd = {
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

    yabai = {
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

    sketchybar = {
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
