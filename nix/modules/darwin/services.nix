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
  };
}
